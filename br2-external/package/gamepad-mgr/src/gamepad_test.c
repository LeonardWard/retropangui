/* gamepad_test.c — 라이브러리 동작 확인용 데모/디버깅 도구
 *
 * 사용법:  gamepad-test [gamecontrollerdb.txt] [gamepad_config.json]
 *
 * Ctrl+C로 종료. 컨트롤러 이벤트를 stdout에 출력한다.
 */
#include "gamepad.h"

#include <SDL2/SDL.h>
#include <stdio.h>
#include <signal.h>
#include <stdbool.h>

static volatile bool s_running = true;

static const char *btn_name(GP_Button b) {
    static const char *names[] = {
        "A","B","X","Y","L1","R1","L2","R2",
        "L3","R3","START","SELECT","GUIDE",
        "UP","DOWN","LEFT","RIGHT"
    };
    if (b >= 0 && b < GP_BTN_COUNT) return names[b];
    return "?";
}

static const char *axis_name(GP_Axis a) {
    static const char *names[] = {
        "LX","LY","RX","RY","L2","R2"
    };
    if (a >= 0 && a < GP_AXIS_COUNT) return names[a];
    return "?";
}

static void on_event(const GP_Event *ev, void *ud) {
    (void)ud;
    switch (ev->type) {
    case GP_EV_CONNECTED:
        printf("[P%d] 연결: %s\n", ev->slot + 1, ev->pad_name);
        break;
    case GP_EV_DISCONNECTED:
        printf("[P%d] 해제: %s\n", ev->slot + 1, ev->pad_name);
        break;
    case GP_EV_BUTTON_DOWN:
        printf("[P%d] %-8s 누름\n", ev->slot + 1, btn_name(ev->button));
        break;
    case GP_EV_BUTTON_UP:
        printf("[P%d] %-8s 뗌\n",   ev->slot + 1, btn_name(ev->button));
        break;
    case GP_EV_AXIS:
        printf("[P%d] 축 %-4s = %+.3f\n",
               ev->slot + 1, axis_name(ev->axis), ev->value);
        break;
    }
    fflush(stdout);
}

static void sig_handler(int sig) {
    (void)sig;
    s_running = false;
}

int main(int argc, char *argv[]) {
    const char *db_path  = argc > 1 ? argv[1] : NULL;
    const char *cfg_path = argc > 2 ? argv[2] : "/etc/gamepad/gamepad_config.json";

    signal(SIGINT,  sig_handler);
    signal(SIGTERM, sig_handler);

    printf("gamepad-test 시작 (Ctrl+C로 종료)\n");
    printf("  DB:     %s\n", db_path  ? db_path  : "(SDL 내장)");
    printf("  설정:   %s\n", cfg_path ? cfg_path : "(없음)");
    printf("---\n");

    if (gp_init(db_path, cfg_path) < 0) {
        fprintf(stderr, "gp_init 실패\n");
        return 1;
    }

    gp_add_listener(on_event, NULL);

    while (s_running) {
        gp_update();

        /* 슬롯 상태 주기적 출력 (1초마다) */
        static Uint32 last_print = 0;
        Uint32 now = SDL_GetTicks();
        if (now - last_print > 1000) {
            last_print = now;
            for (int i = 0; i < GP_MAX_SLOTS; i++) {
                const char *state_str[] = {"빈 슬롯", "대기 중", "활성"};
                printf("  P%d: %-6s %s\n",
                       i + 1,
                       state_str[gp_slot_state(i)],
                       gp_slot_name(i));
            }
        }

        SDL_Delay(8); /* ~120Hz 폴링 */
    }

    gp_quit();
    printf("\ngamepad-test 종료\n");
    return 0;
}
