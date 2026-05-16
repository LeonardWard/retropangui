/* gamepad_slot.h — Player 1~4 슬롯 매니저 내부 API
 *
 * gamepad.c 전용. 외부 코드는 gamepad.h만 사용할 것.
 *
 * 슬롯 배정 규칙:
 *   1. 재연결: 과거 히스토리에 GUID가 있으면 동일 슬롯으로 복원
 *   2. 신규:   비어 있는 가장 낮은 슬롯 번호에 배정
 *   3. 슬롯이 모두 찼으면 장치를 닫고 무시
 */
#pragma once

#include <SDL2/SDL.h>
#include "gamepad.h"

typedef struct {
    GP_SlotState        state;
    SDL_JoystickGUID    guid;
    SDL_GameController *gc;          /* GC 매핑 사용 시 non-NULL */
    SDL_Joystick       *js;          /* ACTIVE 상태일 때 항상 유효 */
    SDL_JoystickID      instance_id; /* SDL 이벤트 매칭용 */
    char                name[64];
    GP_State            cached;      /* gp_update()가 매 프레임 갱신 */
} GP_SlotEntry;

void gp_slot_init(void);

/* SDL_JOYDEVICEADDED / SDL_JOYDEVICEREMOVED 핸들러 */
void gp_slot_on_device_added(int sdl_device_idx);
void gp_slot_on_device_removed(SDL_JoystickID instance_id);

/* 슬롯 조회 */
int           gp_slot_find_by_instance(SDL_JoystickID id); /* 0–3, 없으면 -1 */
GP_SlotEntry *gp_slot_get(int slot);
