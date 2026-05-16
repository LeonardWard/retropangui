/* gamepad.h — 공통 가상 패드 인터페이스
 *
 * 레이어: 하드웨어 → udev → SDL2 → 슬롯 매니저 → 이 API
 *
 * 사용 예:
 *   gp_init("/etc/gamepad/gamecontrollerdb.txt", "/etc/gamepad/gamepad_config.json");
 *   gp_add_listener(my_cb, NULL);
 *   while (running) { gp_update(); }
 *   gp_quit();
 */
#pragma once

#include <stdbool.h>
#include <stdint.h>

/* ── 가상 버튼 ─────────────────────────────────────────────── */
typedef enum {
    GP_BTN_A = 0,
    GP_BTN_B,
    GP_BTN_X,
    GP_BTN_Y,
    GP_BTN_L1,
    GP_BTN_R1,
    GP_BTN_L2,        /* 아날로그 트리거 → 디지털 (> 0.5f) */
    GP_BTN_R2,
    GP_BTN_L3,        /* 왼쪽 스틱 클릭 */
    GP_BTN_R3,        /* 오른쪽 스틱 클릭 */
    GP_BTN_START,
    GP_BTN_SELECT,
    GP_BTN_GUIDE,
    GP_BTN_DPAD_UP,
    GP_BTN_DPAD_DOWN,
    GP_BTN_DPAD_LEFT,
    GP_BTN_DPAD_RIGHT,
    GP_BTN_COUNT
} GP_Button;

typedef enum {
    GP_AXIS_LEFT_X = 0,
    GP_AXIS_LEFT_Y,
    GP_AXIS_RIGHT_X,
    GP_AXIS_RIGHT_Y,
    GP_AXIS_L2,       /* 0.0–1.0 */
    GP_AXIS_R2,       /* 0.0–1.0 */
    GP_AXIS_COUNT
} GP_Axis;

/* ── 슬롯 상태 ─────────────────────────────────────────────── */
typedef enum {
    GP_SLOT_EMPTY,    /* 장치 없음 */
    GP_SLOT_WAITING,  /* 수신기 연결, 컨트롤러 미연결 (Xbox 무선 등) */
    GP_SLOT_ACTIVE,   /* 정상 동작 중 */
} GP_SlotState;

#define GP_MAX_SLOTS 4

/* ── 상태 스냅샷 ───────────────────────────────────────────── */
typedef struct {
    bool  buttons[GP_BTN_COUNT];
    float axes[GP_AXIS_COUNT]; /* 스틱: -1.0..1.0 / 트리거: 0.0..1.0 */
} GP_State;

/* ── 이벤트 ────────────────────────────────────────────────── */
typedef enum {
    GP_EV_CONNECTED,
    GP_EV_DISCONNECTED,
    GP_EV_BUTTON_DOWN,
    GP_EV_BUTTON_UP,
    GP_EV_AXIS,
} GP_EventType;

typedef struct {
    GP_EventType  type;
    int           slot;      /* 0–3 */
    GP_Button     button;    /* BUTTON_* 이벤트 시 유효 */
    GP_Axis       axis;      /* AXIS 이벤트 시 유효 */
    float         value;     /* AXIS: 축 값 / BUTTON_DOWN=1.0 / BUTTON_UP=0.0 */
    const char   *pad_name;
} GP_Event;

typedef void (*GP_EventCb)(const GP_Event *ev, void *userdata);

/* ── 초기화 / 종료 ─────────────────────────────────────────── */
/*
 * db_path   : gamecontrollerdb.txt 경로 (NULL = SDL 내장 DB만 사용)
 * cfg_path  : gamepad_config.json 경로 (NULL = 커스텀 매핑 없음)
 */
int  gp_init(const char *db_path, const char *cfg_path);
void gp_quit(void);

/* ── 이벤트 리스너 ─────────────────────────────────────────── */
int  gp_add_listener(GP_EventCb cb, void *userdata); /* 토큰 반환, -1=만석 */
void gp_remove_listener(int token);

/* ── 메인루프 ───────────────────────────────────────────────── */
/* SDL 이벤트 큐를 소진하고, 슬롯 상태를 갱신하며, 콜백을 실행한다. */
void gp_update(void);

/* ── 상태 폴링 ─────────────────────────────────────────────── */
bool  gp_get_state(int slot, GP_State *out); /* ACTIVE 아니면 false */
bool  gp_button_pressed(int slot, GP_Button btn);
float gp_axis_value(int slot, GP_Axis axis);

/* ── 슬롯 조회 ─────────────────────────────────────────────── */
GP_SlotState gp_slot_state(int slot);
const char  *gp_slot_name(int slot);
bool         gp_slot_is_gc_mapped(int slot); /* true = SDL GameController API */
