#include "gamepad.h"
#include "gamepad_slot.h"
#include "gamepad_mapping.h"

#include <stdbool.h>
#include <SDL2/SDL.h>
#include <string.h>
#include <math.h>

/* ── 리스너 테이블 ─────────────────────────────────────────── */
#define MAX_LISTENERS 8

typedef struct {
    GP_EventCb  cb;
    void       *userdata;
    bool        active;
} Listener;

static Listener s_listeners[MAX_LISTENERS];

static void fire(const GP_Event *ev) {
    for (int i = 0; i < MAX_LISTENERS; i++)
        if (s_listeners[i].active)
            s_listeners[i].cb(ev, s_listeners[i].userdata);
}

/* ── 상태 읽기 ─────────────────────────────────────────────── */

#define AXIS_NORM(v)  ((float)(v) / 32768.0f)
#define TRIG_NORM(v)  ((float)(v) / 32767.0f)
#define DEADZONE      0.08f

static float apply_deadzone(float v) {
    return (fabsf(v) < DEADZONE) ? 0.0f : v;
}

static void read_gc_state(SDL_GameController *gc, GP_State *s) {
    /* 버튼 */
    static const struct { GP_Button gp; SDL_GameControllerButton sdl; } btns[] = {
        { GP_BTN_A,          SDL_CONTROLLER_BUTTON_A             },
        { GP_BTN_B,          SDL_CONTROLLER_BUTTON_B             },
        { GP_BTN_X,          SDL_CONTROLLER_BUTTON_X             },
        { GP_BTN_Y,          SDL_CONTROLLER_BUTTON_Y             },
        { GP_BTN_L1,         SDL_CONTROLLER_BUTTON_LEFTSHOULDER  },
        { GP_BTN_R1,         SDL_CONTROLLER_BUTTON_RIGHTSHOULDER },
        { GP_BTN_L3,         SDL_CONTROLLER_BUTTON_LEFTSTICK     },
        { GP_BTN_R3,         SDL_CONTROLLER_BUTTON_RIGHTSTICK    },
        { GP_BTN_START,      SDL_CONTROLLER_BUTTON_START         },
        { GP_BTN_SELECT,     SDL_CONTROLLER_BUTTON_BACK          },
        { GP_BTN_GUIDE,      SDL_CONTROLLER_BUTTON_GUIDE         },
        { GP_BTN_DPAD_UP,    SDL_CONTROLLER_BUTTON_DPAD_UP       },
        { GP_BTN_DPAD_DOWN,  SDL_CONTROLLER_BUTTON_DPAD_DOWN     },
        { GP_BTN_DPAD_LEFT,  SDL_CONTROLLER_BUTTON_DPAD_LEFT     },
        { GP_BTN_DPAD_RIGHT, SDL_CONTROLLER_BUTTON_DPAD_RIGHT    },
    };
    for (int i = 0; i < (int)(sizeof(btns)/sizeof(btns[0])); i++)
        s->buttons[btns[i].gp] = SDL_GameControllerGetButton(gc, btns[i].sdl);

    /* 스틱 */
    s->axes[GP_AXIS_LEFT_X]  = apply_deadzone(AXIS_NORM(SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_LEFTX)));
    s->axes[GP_AXIS_LEFT_Y]  = apply_deadzone(AXIS_NORM(SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_LEFTY)));
    s->axes[GP_AXIS_RIGHT_X] = apply_deadzone(AXIS_NORM(SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_RIGHTX)));
    s->axes[GP_AXIS_RIGHT_Y] = apply_deadzone(AXIS_NORM(SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_RIGHTY)));

    /* 아날로그 트리거 (SDL: 0..32767) */
    s->axes[GP_AXIS_L2] = TRIG_NORM(SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_TRIGGERLEFT));
    s->axes[GP_AXIS_R2] = TRIG_NORM(SDL_GameControllerGetAxis(gc, SDL_CONTROLLER_AXIS_TRIGGERRIGHT));

    /* 트리거 디지털 버튼 투영 */
    s->buttons[GP_BTN_L2] = (s->axes[GP_AXIS_L2] > 0.5f);
    s->buttons[GP_BTN_R2] = (s->axes[GP_AXIS_R2] > 0.5f);
}

/*
 * 미등록 패드 raw 폴백 매핑.
 * 버튼/축 순서는 대부분의 표준 USB 게임패드 배열과 일치.
 * 사용자가 gamepad_config.json에 sdl_mappings를 추가하면
 * SDL이 해당 패드를 GC 장치로 인식해 이 함수는 더 이상 호출되지 않는다.
 */
static void read_raw_state(SDL_Joystick *js, GP_State *s) {
    /* 버튼: 남미(ABXY=0123), L1/R1=4/5, SELECT/START=6/7 (일반적 배열) */
    static const GP_Button btn_map[] = {
        GP_BTN_A, GP_BTN_B, GP_BTN_X, GP_BTN_Y,
        GP_BTN_L1, GP_BTN_R1, GP_BTN_L2, GP_BTN_R2,
        GP_BTN_SELECT, GP_BTN_START, GP_BTN_GUIDE,
        GP_BTN_L3, GP_BTN_R3,
    };
    int nbtns = SDL_JoystickNumButtons(js);
    int map_n = (int)(sizeof(btn_map)/sizeof(btn_map[0]));
    for (int i = 0; i < nbtns && i < map_n; i++)
        s->buttons[btn_map[i]] = SDL_JoystickGetButton(js, i);

    /* 스틱 */
    int naxes = SDL_JoystickNumAxes(js);
    if (naxes > 0) s->axes[GP_AXIS_LEFT_X]  = apply_deadzone(AXIS_NORM(SDL_JoystickGetAxis(js, 0)));
    if (naxes > 1) s->axes[GP_AXIS_LEFT_Y]  = apply_deadzone(AXIS_NORM(SDL_JoystickGetAxis(js, 1)));
    if (naxes > 2) s->axes[GP_AXIS_RIGHT_X] = apply_deadzone(AXIS_NORM(SDL_JoystickGetAxis(js, 2)));
    if (naxes > 3) s->axes[GP_AXIS_RIGHT_Y] = apply_deadzone(AXIS_NORM(SDL_JoystickGetAxis(js, 3)));

    /* 햇(십자키) */
    if (SDL_JoystickNumHats(js) > 0) {
        Uint8 hat = SDL_JoystickGetHat(js, 0);
        s->buttons[GP_BTN_DPAD_UP]    = (hat & SDL_HAT_UP)    != 0;
        s->buttons[GP_BTN_DPAD_DOWN]  = (hat & SDL_HAT_DOWN)  != 0;
        s->buttons[GP_BTN_DPAD_LEFT]  = (hat & SDL_HAT_LEFT)  != 0;
        s->buttons[GP_BTN_DPAD_RIGHT] = (hat & SDL_HAT_RIGHT) != 0;
    }
}

/* ── 상태 diff → 콜백 ──────────────────────────────────────── */
static void fire_state_diff(int slot, const GP_State *prev,
                             const GP_State *next, const char *name) {
    GP_Event ev;
    ev.slot     = slot;
    ev.pad_name = name;

    for (int b = 0; b < GP_BTN_COUNT; b++) {
        if (prev->buttons[b] == next->buttons[b]) continue;
        ev.button = (GP_Button)b;
        ev.axis   = 0;
        if (next->buttons[b]) {
            ev.type  = GP_EV_BUTTON_DOWN;
            ev.value = 1.0f;
        } else {
            ev.type  = GP_EV_BUTTON_UP;
            ev.value = 0.0f;
        }
        fire(&ev);
    }

    for (int a = 0; a < GP_AXIS_COUNT; a++) {
        if (prev->axes[a] == next->axes[a]) continue;
        ev.type   = GP_EV_AXIS;
        ev.button = 0;
        ev.axis   = (GP_Axis)a;
        ev.value  = next->axes[a];
        fire(&ev);
    }
}

/* ── 초기화 / 종료 ─────────────────────────────────────────── */

int gp_init(const char *db_path, const char *cfg_path) {
    if (SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) < 0) {
        SDL_Log("gp_init: SDL_Init 실패: %s\n", SDL_GetError());
        return -1;
    }

    SDL_GameControllerEventState(SDL_IGNORE); /* 이벤트는 조이스틱 레벨에서만 처리 */
    SDL_JoystickEventState(SDL_ENABLE);

    if (db_path)
        SDL_GameControllerAddMappingsFromFile(db_path);

    if (cfg_path)
        gp_map_load(cfg_path);

    gp_slot_init();
    memset(s_listeners, 0, sizeof(s_listeners));

    /* 이미 연결된 장치 초기 등록 */
    int n = SDL_NumJoysticks();
    for (int i = 0; i < n; i++)
        gp_slot_on_device_added(i);

    return 0;
}

void gp_quit(void) {
    const char *path = gp_map_config_path();
    if (path) gp_map_save(path);

    for (int i = 0; i < GP_MAX_SLOTS; i++) {
        GP_SlotEntry *e = gp_slot_get(i);
        if (!e || e->state == GP_SLOT_EMPTY) continue;
        if (e->gc)       SDL_GameControllerClose(e->gc);
        else if (e->js)  SDL_JoystickClose(e->js);
    }

    SDL_QuitSubSystem(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER);
}

/* ── 리스너 ────────────────────────────────────────────────── */

int gp_add_listener(GP_EventCb cb, void *userdata) {
    for (int i = 0; i < MAX_LISTENERS; i++) {
        if (!s_listeners[i].active) {
            s_listeners[i].cb       = cb;
            s_listeners[i].userdata = userdata;
            s_listeners[i].active   = true;
            return i;
        }
    }
    return -1;
}

void gp_remove_listener(int token) {
    if (token >= 0 && token < MAX_LISTENERS)
        s_listeners[token].active = false;
}

/* ── 메인루프 ───────────────────────────────────────────────── */

void gp_update(void) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        switch (e.type) {
        case SDL_JOYDEVICEADDED: {
            gp_slot_on_device_added(e.jdevice.which);
            /* 슬롯 찾아 CONNECTED 이벤트 발송 */
            int slot = gp_slot_find_by_instance(
                SDL_JoystickGetDeviceInstanceID(e.jdevice.which));
            if (slot >= 0) {
                GP_SlotEntry *se = gp_slot_get(slot);
                GP_Event ev = { GP_EV_CONNECTED, slot, 0, 0, 0.0f, se->name };
                fire(&ev);
            }
            break;
        }
        case SDL_JOYDEVICEREMOVED: {
            int slot = gp_slot_find_by_instance(e.jdevice.which);
            const char *name = (slot >= 0) ? gp_slot_get(slot)->name : "unknown";
            GP_Event ev = { GP_EV_DISCONNECTED, slot, 0, 0, 0.0f, name };
            gp_slot_on_device_removed(e.jdevice.which);
            if (slot >= 0) fire(&ev);
            break;
        }
        default:
            break;
        }
    }

    /* 모든 ACTIVE 슬롯 상태 폴링 → diff → 콜백 */
    for (int i = 0; i < GP_MAX_SLOTS; i++) {
        GP_SlotEntry *se = gp_slot_get(i);
        if (!se || se->state != GP_SLOT_ACTIVE) continue;

        GP_State next = {0};
        if (se->gc)
            read_gc_state(se->gc, &next);
        else
            read_raw_state(se->js, &next);

        fire_state_diff(i, &se->cached, &next, se->name);
        se->cached = next;
    }
}

/* ── 상태 폴링 API ─────────────────────────────────────────── */

bool gp_get_state(int slot, GP_State *out) {
    GP_SlotEntry *e = gp_slot_get(slot);
    if (!e || e->state != GP_SLOT_ACTIVE) return false;
    *out = e->cached;
    return true;
}

bool gp_button_pressed(int slot, GP_Button btn) {
    GP_SlotEntry *e = gp_slot_get(slot);
    if (!e || e->state != GP_SLOT_ACTIVE) return false;
    return e->cached.buttons[btn];
}

float gp_axis_value(int slot, GP_Axis axis) {
    GP_SlotEntry *e = gp_slot_get(slot);
    if (!e || e->state != GP_SLOT_ACTIVE) return 0.0f;
    return e->cached.axes[axis];
}

/* ── 슬롯 조회 API ─────────────────────────────────────────── */

GP_SlotState gp_slot_state(int slot) {
    GP_SlotEntry *e = gp_slot_get(slot);
    return e ? e->state : GP_SLOT_EMPTY;
}

const char *gp_slot_name(int slot) {
    GP_SlotEntry *e = gp_slot_get(slot);
    return (e && e->state != GP_SLOT_EMPTY) ? e->name : "";
}

bool gp_slot_is_gc_mapped(int slot) {
    GP_SlotEntry *e = gp_slot_get(slot);
    return e && e->gc != NULL;
}
