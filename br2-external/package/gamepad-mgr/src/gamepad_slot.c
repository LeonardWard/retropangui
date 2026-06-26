#include "gamepad_slot.h"
#include "gamepad_mapping.h"

#include <string.h>
#include <stdio.h>

static GP_SlotEntry s_slots[GP_MAX_SLOTS];

/* ── 내부 헬퍼 ────────────────────────────────────────────── */

static int find_empty_slot(void) {
    for (int i = 0; i < GP_MAX_SLOTS; i++)
        if (s_slots[i].state == GP_SLOT_EMPTY) return i;
    return -1;
}

static int find_slot_by_instance(SDL_JoystickID id) {
    for (int i = 0; i < GP_MAX_SLOTS; i++)
        if (s_slots[i].state != GP_SLOT_EMPTY &&
            s_slots[i].instance_id == id) return i;
    return -1;
}

static void close_slot(int slot) {
    GP_SlotEntry *e = &s_slots[slot];
    /* GC와 js는 SDL_JoystickOpen + SDL_GameControllerOpen으로
     * 각각 독립적으로 열렸으므로 둘 다 닫아야 한다. */
    if (e->gc) { SDL_GameControllerClose(e->gc); e->gc = NULL; }
    if (e->js) { SDL_JoystickClose(e->js);        e->js = NULL; }
    e->state = GP_SLOT_EMPTY;
}

/* Xbox 360 무선 수신기처럼 버튼/축이 0개인 장치 = WAITING 상태 */
static GP_SlotState detect_state(SDL_Joystick *js) {
    if (SDL_JoystickNumButtons(js) == 0 &&
        SDL_JoystickNumAxes(js)   == 0)
        return GP_SLOT_WAITING;
    return GP_SLOT_ACTIVE;
}

/* ── 공개 API ─────────────────────────────────────────────── */

void gp_slot_init(void) {
    memset(s_slots, 0, sizeof(s_slots));
}

void gp_slot_on_device_added(int sdl_device_idx) {
    /* 조이스틱으로 먼저 열어 GUID 확인 */
    SDL_Joystick *js = SDL_JoystickOpen(sdl_device_idx);
    if (!js) {
        SDL_Log("gamepad_slot: JoystickOpen(%d) 실패: %s\n",
                sdl_device_idx, SDL_GetError());
        return;
    }

    /* 이미 같은 instance_id가 등록된 경우 중복 무시
     * (init 루프 + SDL_JOYDEVICEADDED 이벤트가 동일 장치를 두 번 알릴 때) */
    SDL_JoystickID iid = SDL_JoystickInstanceID(js);
    if (find_slot_by_instance(iid) >= 0) {
        SDL_JoystickClose(js);
        return;
    }

    SDL_JoystickGUID guid        = SDL_JoystickGetGUID(js);
    SDL_JoystickID   instance_id = SDL_JoystickInstanceID(js);
    GP_SlotState     state       = detect_state(js);

    /* 우리가 만든 가상 장치(BUS_VIRTUAL=0x0006, VID=0x5052)는 무시 — cascade 방지 */
    {
        unsigned short bus = (unsigned short)(guid.data[0] | (guid.data[1] << 8));
        unsigned short vid = (unsigned short)(guid.data[4] | (guid.data[5] << 8));
        if (bus == 0x0006 || vid == 0x5052) {
            SDL_JoystickClose(js);
            return;
        }
    }

    /* GC 매핑 여부 확인 */
    SDL_GameController *gc = NULL;
    if (state == GP_SLOT_ACTIVE && SDL_IsGameController(sdl_device_idx)) {
        gc = SDL_GameControllerOpen(sdl_device_idx);
        if (!gc)
            SDL_Log("gamepad_slot: GC open 실패 (%s), raw 폴백\n", SDL_GetError());
    }

    /* 슬롯 배정: 히스토리 우선, 없으면 최저 빈 슬롯 */
    int target = gp_map_preferred_slot(guid);
    if (target < 0 || s_slots[target].state != GP_SLOT_EMPTY)
        target = find_empty_slot();

    if (target < 0) {
        SDL_Log("gamepad_slot: 슬롯 만석, 장치 무시\n");
        if (gc) SDL_GameControllerClose(gc);
        else    SDL_JoystickClose(js);
        return;
    }

    GP_SlotEntry *e = &s_slots[target];
    e->state       = state;
    e->guid        = guid;
    e->gc          = gc;
    e->js          = js;
    e->instance_id = instance_id;
    memset(&e->cached, 0, sizeof(e->cached));
    SDL_strlcpy(e->name, SDL_JoystickName(js), sizeof(e->name));

    gp_map_update_history(guid, target);

    SDL_Log("gamepad_slot: [P%d] %s — %s%s\n",
            target + 1, e->name,
            state   == GP_SLOT_WAITING ? "대기 중" : "활성",
            gc      ? " (GC 매핑)" : " (raw 조이스틱)");
}

void gp_slot_on_device_removed(SDL_JoystickID instance_id) {
    int slot = find_slot_by_instance(instance_id);
    if (slot < 0) return;

    SDL_Log("gamepad_slot: [P%d] %s 연결 해제\n",
            slot + 1, s_slots[slot].name);
    close_slot(slot);
}

int gp_slot_find_by_instance(SDL_JoystickID id) {
    return find_slot_by_instance(id);
}

GP_SlotEntry *gp_slot_get(int slot) {
    if (slot < 0 || slot >= GP_MAX_SLOTS) return NULL;
    return &s_slots[slot];
}
