/* gamepad_daemon.c — gamepad-mgr 가상 패드 데몬
 * 물리 컨트롤러를 uinput 가상 장치로 정규화해 EmulationStation/RetroArch에 노출한다.
 * C99, 외부 의존: SDL2, Linux input/uinput
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <linux/input.h>
#include <SDL2/SDL.h>
#include "gamepad.h"
#include "gamepad_slot.h"
#include "gamepad_vdev.h"

/* ── 전역 상태 (파일 스코프) ──────────────────────────────────── */
static GP_VDev         *g_vdev[GP_MAX_SLOTS];
static GP_State         g_prev[GP_MAX_SLOTS];
static int              g_phys_fd[GP_MAX_SLOTS]; /* daemon 소유 evdev fd */
static volatile int     g_running = 1;

/* ── 물리 evdev fd 탐색 ───────────────────────────────────────── */
/*
 * SDL_JoystickGUID 바이트 레이아웃 (SDL2 소스 기준):
 *   [0~1]  버스타입 (LE)
 *   [2~3]  CRC / 0
 *   [4~5]  VID (LE)
 *   [6~7]  0
 *   [8~9]  PID (LE)
 *   [10~11] 0
 *   [12~15] 드라이버 특정
 */
static int find_phys_evdev(SDL_Joystick *js)
{
    SDL_JoystickGUID guid = SDL_JoystickGetGUID(js);

    unsigned short vid = (unsigned short)(guid.data[4] | (guid.data[5] << 8));
    unsigned short pid = (unsigned short)(guid.data[8] | (guid.data[9] << 8));

    if (vid == 0 && pid == 0) {
        /* 가상/키보드 장치 등 — evdev 매칭 불가 */
        return -1;
    }

    DIR *dir = opendir("/dev/input");
    if (!dir) {
        perror("gamepad_daemon: opendir /dev/input");
        return -1;
    }

    int found_fd = -1;
    struct dirent *de;
    while ((de = readdir(dir)) != NULL) {
        if (strncmp(de->d_name, "event", 5) != 0) continue;

        char path[64];
        snprintf(path, sizeof(path), "/dev/input/%s", de->d_name);

        int fd = open(path, O_RDWR | O_NONBLOCK); /* FF ioctl(EVIOCSFF)은 쓰기 권한 필요 */
        if (fd < 0) continue;

        struct input_id iid;
        if (ioctl(fd, EVIOCGID, &iid) >= 0 &&
            iid.vendor  == vid &&
            iid.product == pid) {
            found_fd = fd;
            break;
        }
        close(fd);
    }
    closedir(dir);
    return found_fd;
}

/* ── sysfs 파일에 문자열 쓰기 헬퍼 ───────────────────────────── */
static void sysfs_write(const char *path, const char *val)
{
    FILE *f = fopen(path, "w");
    if (!f) return;
    fputs(val, f);
    fclose(f);
}

/* ── 플레이어 LED 설정 ────────────────────────────────────────── */
static void set_player_led(int phys_fd, int slot)
{
    if (phys_fd < 0) return;

    struct input_id iid;
    if (ioctl(phys_fd, EVIOCGID, &iid) < 0) return;

    unsigned short vid = iid.vendor;
    unsigned short pid = iid.product;

    DIR *leds = opendir("/sys/class/leds");
    if (!leds) return;

    /* Xbox 360 (VID 0x045e) — xpad LED 링: 6=P1 solid, 7=P2, 8=P3, 9=P4 */
    if (vid == 0x045e) {
        char val[4];
        snprintf(val, sizeof(val), "%d", slot + 6);
        struct dirent *de;
        while ((de = readdir(leds)) != NULL) {
            if (strncmp(de->d_name, "xpad", 4) != 0) continue;
            char path[128];
            snprintf(path, sizeof(path), "/sys/class/leds/%s/brightness", de->d_name);
            sysfs_write(path, val);
            break;
        }
    }
    /* Sony DS3 (VID 0x054c, PID 0x0268) — 4개 LED, slot N = ledN+1 ON, 나머지 OFF */
    else if (vid == 0x054c && pid == 0x0268) {
        struct dirent *de;
        /* sony LED 이름 예: "0005:054C:0268.0001:sony1" */
        while ((de = readdir(leds)) != NULL) {
            if (strstr(de->d_name, "sony") == NULL) continue;
            /* 마지막 문자로 LED 번호 판별 (sony1~sony4) */
            const char *p = strstr(de->d_name, "sony");
            int led_num = (int)(p[4] - '0'); /* 1~4 */
            if (led_num < 1 || led_num > 4) continue;
            char path[128];
            snprintf(path, sizeof(path), "/sys/class/leds/%s/brightness", de->d_name);
            sysfs_write(path, (led_num == slot + 1) ? "1" : "0");
        }
    }
    /* Sony DS4 (VID 0x054c, PID 0x05c4 / 0x09cc) — 라이트바 색상 */
    else if (vid == 0x054c && (pid == 0x05c4 || pid == 0x09cc)) {
        /* P1=파랑, P2=빨강, P3=초록, P4=노랑 */
        static const int colors[4][3] = {
            {0, 0, 255}, {255, 0, 0}, {0, 255, 0}, {255, 255, 0}
        };
        const int *c = colors[slot];
        struct dirent *de;
        while ((de = readdir(leds)) != NULL) {
            if (strstr(de->d_name, "sony") == NULL) continue;
            char path[128]; char val[8];
            if (strstr(de->d_name, ":red")) {
                snprintf(path, sizeof(path), "/sys/class/leds/%s/brightness", de->d_name);
                snprintf(val,  sizeof(val),  "%d", c[0]);
                sysfs_write(path, val);
            } else if (strstr(de->d_name, ":green")) {
                snprintf(path, sizeof(path), "/sys/class/leds/%s/brightness", de->d_name);
                snprintf(val,  sizeof(val),  "%d", c[1]);
                sysfs_write(path, val);
            } else if (strstr(de->d_name, ":blue")) {
                snprintf(path, sizeof(path), "/sys/class/leds/%s/brightness", de->d_name);
                snprintf(val,  sizeof(val),  "%d", c[2]);
                sysfs_write(path, val);
            }
        }
    }

    closedir(leds);
}

/* ── SDL이 열어둔 evdev fd 탐색 (EVIOCGRAB용) ────────────────── */
/*
 * our_phys_fd와 동일한 장치(같은 st_rdev)를 가진 fd를 /proc/self/fd에서 찾는다.
 * EVIOCGRAB는 호출한 fd만 이벤트를 독점하므로, SDL의 fd에 걸어야
 * SDL은 이벤트를 계속 받고 ES/외부 프로세스만 차단된다.
 */
static int find_sdl_evdev_fd(int our_phys_fd)
{
    if (our_phys_fd < 0) return -1;

    struct stat our_st;
    if (fstat(our_phys_fd, &our_st) < 0) return -1;

    DIR *dir = opendir("/proc/self/fd");
    if (!dir) return -1;

    int found = -1;
    struct dirent *de;
    while ((de = readdir(dir)) != NULL) {
        if (de->d_name[0] == '.') continue;
        int fd = atoi(de->d_name);
        if (fd <= 2 || fd == our_phys_fd) continue; /* stdin/out/err 및 자신 제외 */

        struct stat st;
        if (fstat(fd, &st) == 0 &&
            S_ISCHR(st.st_mode) &&
            st.st_rdev == our_st.st_rdev) {
            found = fd;
            break;
        }
    }
    closedir(dir);
    return found;
}

/* ── SIGTERM/SIGINT 핸들러 ────────────────────────────────────── */
static void handle_signal(int sig)
{
    (void)sig;
    g_running = 0;
}

/* ── 이벤트 콜백 ──────────────────────────────────────────────── */
static void on_gamepad_event(const GP_Event *ev, void *userdata)
{
    (void)userdata;
    int slot = ev->slot;
    if (slot < 0 || slot >= GP_MAX_SLOTS) return;

    switch (ev->type) {
    case GP_EV_CONNECTED: {
        /* 이전 물리 fd 정리 */
        if (g_phys_fd[slot] >= 0) {
            close(g_phys_fd[slot]);
            g_phys_fd[slot] = -1;
        }

        int phys_fd = -1;
        GP_SlotEntry *entry = gp_slot_get(slot);
        if (entry && entry->js) {
            phys_fd = find_phys_evdev(entry->js);
        }

        /* SDL이 열어둔 fd에 EVIOCGRAB — SDL은 이벤트 계속 수신, ES/RA는 차단 */
        if (phys_fd >= 0) {
            int sdl_fd = find_sdl_evdev_fd(phys_fd);
            if (sdl_fd >= 0) {
                if (ioctl(sdl_fd, EVIOCGRAB, 1) < 0)
                    fprintf(stderr, "gamepad_daemon: EVIOCGRAB slot %d: %s\n",
                            slot, strerror(errno));
            } else {
                fprintf(stderr, "gamepad_daemon: SDL evdev fd not found for slot %d\n", slot);
            }
        }

        /* vdev는 미리 생성된 것을 재사용 — phys_fd만 교체 */
        if (g_vdev[slot]) {
            gp_vdev_rebind_phys(g_vdev[slot], phys_fd);
            g_phys_fd[slot] = phys_fd;
            set_player_led(phys_fd, slot);
        } else {
            /* 만약 pre-create가 실패했다면 여기서 새로 생성 */
            g_vdev[slot] = gp_vdev_create(slot, phys_fd);
            if (g_vdev[slot]) {
                g_phys_fd[slot] = phys_fd;
                set_player_led(phys_fd, slot);
            } else if (phys_fd >= 0) {
                close(phys_fd);
            }
        }
        memset(&g_prev[slot], 0, sizeof(GP_State));
        fprintf(stderr, "gamepad_daemon: slot %d connected: %s\n",
                slot, ev->pad_name ? ev->pad_name : "(unknown)");
        break;
    }

    case GP_EV_DISCONNECTED: {
        /* vdev는 유지 — RetroArch가 계속 가상 장치를 볼 수 있도록 */
        if (g_phys_fd[slot] >= 0) {
            close(g_phys_fd[slot]);
            g_phys_fd[slot] = -1;
        }
        if (g_vdev[slot]) {
            gp_vdev_rebind_phys(g_vdev[slot], -1);
        }
        fprintf(stderr, "gamepad_daemon: slot %d disconnected\n", slot);
        break;
    }

    default:
        break;
    }
}

/* ── main ─────────────────────────────────────────────────────── */
int main(void)
{
    /* 초기화 */
    for (int i = 0; i < GP_MAX_SLOTS; i++) {
        g_vdev[i]    = NULL;
        g_phys_fd[i] = -1;
        memset(&g_prev[i], 0, sizeof(GP_State));
    }

    signal(SIGTERM, handle_signal);
    signal(SIGINT,  handle_signal);

    /* 가상 장치를 물리 컨트롤러 탐색 전에 미리 생성한다.
     * RetroArch가 열거할 때 RetroPangUI P1-P4가 index 0-3을 차지하게 되어
     * retroarch.cfg의 input_player1-4_joypad_index = "0"-"3" 고정 설정이 동작한다. */
    for (int i = 0; i < GP_MAX_SLOTS; i++) {
        g_vdev[i] = gp_vdev_create(i, -1);
        if (!g_vdev[i])
            fprintf(stderr, "gamepad_daemon: pre-create vdev slot %d failed\n", i);
    }

    if (gp_init("/etc/gamepad/gamecontrollerdb.txt",
                "/etc/gamepad/gamepad_config.json") < 0) {
        fprintf(stderr, "gamepad_daemon: gp_init failed\n");
        return 1;
    }

    gp_add_listener(on_gamepad_event, NULL);

    /* 메인루프 (~125 Hz) */
    GP_State cur;
    while (g_running) {
        gp_update();

        for (int slot = 0; slot < GP_MAX_SLOTS; slot++) {
            if (!g_vdev[slot]) continue;
            if (!gp_get_state(slot, &cur)) continue;
            gp_vdev_write_state(g_vdev[slot], &cur, &g_prev[slot]);
            gp_vdev_poll_ff(g_vdev[slot]);
            g_prev[slot] = cur;
        }

        usleep(8000); /* 8ms ≈ 125Hz */
    }

    /* 정리 */
    for (int i = 0; i < GP_MAX_SLOTS; i++) {
        if (g_vdev[i]) {
            gp_vdev_destroy(g_vdev[i]);
            g_vdev[i] = NULL;
        }
        if (g_phys_fd[i] >= 0) {
            close(g_phys_fd[i]);
            g_phys_fd[i] = -1;
        }
    }
    gp_quit();
    return 0;
}
