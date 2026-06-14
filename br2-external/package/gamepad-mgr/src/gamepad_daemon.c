/* gamepad_daemon.c — gamepad-mgr 가상 패드 데몬
 * 물리 컨트롤러를 uinput 가상 장치로 정규화해 EmulationStation/RetroArch에 노출한다.
 * C99, 외부 의존: SDL2, Linux input/uinput
 */
#define _POSIX_C_SOURCE 200809L
#define _DEFAULT_SOURCE
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
#include <sys/inotify.h>
#include <time.h>
#include <limits.h>
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

/* ── Passive grab 구조체 및 상태 ─────────────────────────────── */
typedef struct {
    int   fd;
    dev_t rdev;
    char  path[64];
} GP_PassiveGrab;

typedef struct {
    char     path[64];
    uint64_t ready_ms;  /* monotonic ms — grab after this if SDL didn't connect */
} GP_PendingGrab;

static GP_PassiveGrab g_passive[GP_MAX_SLOTS];
static int            g_n_passive = 0;
static GP_PendingGrab g_pending[GP_MAX_SLOTS];
static int            g_n_pending = 0;
static int            g_inotify_fd = -1;
static int            g_inotify_wd = -1;
static int            g_startup_done = 0;

/* ── mono_ms: 단조 시계 (ms) ─────────────────────────────────── */
static uint64_t mono_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000ULL + (uint64_t)ts.tv_nsec / 1000000ULL;
}

/* ── fd_is_deleted ───────────────────────────────────────────── */
/*
 * fd가 이미 삭제된(unplug된) 장치 노드를 가리키면 1.
 * 핫스왑 시 커널이 같은 event 번호를 재사용하면 st_rdev가 동일해
 * fstat만으로는 옛 장치의 스테일 fd와 새 fd를 구분할 수 없다 —
 * /proc/self/fd 링크 타깃의 "(deleted)" 표시로 판별한다.
 * (증상: 스테일 fd에 EVIOCGRAB → ENODEV → 물리 패드가 grab되지 않아
 *  ES/RA에 물리+가상 이중 노출)
 */
static int fd_is_deleted(int fd)
{
    char lnk[32], tgt[PATH_MAX];
    snprintf(lnk, sizeof(lnk), "/proc/self/fd/%d", fd);
    ssize_t n = readlink(lnk, tgt, sizeof(tgt) - 1);
    if (n <= 0) return 0;
    tgt[n] = '\0';
    return strstr(tgt, "(deleted)") != NULL;
}

/* ── is_joystick_by_udev ─────────────────────────────────────── */
/*
 * devpath = "/dev/input/eventX"
 * 1. evname = "eventX"
 * 2. readlink /sys/class/input/eventX/device → 상대 심볼릭 링크 (예: ../../input/inputN)
 * 3. 링크 타깃의 마지막 컴포넌트 = "inputN"
 * 4. /run/udev/data/+input:inputN 에서 E:ID_INPUT_JOYSTICK=1 탐색
 */
static int is_joystick_by_udev(const char *devpath)
{
    /* evname 추출 */
    const char *evname = strrchr(devpath, '/');
    if (!evname) return 0;
    evname++; /* skip '/' */

    /* readlink /sys/class/input/<evname>/device */
    char syslink[128];
    snprintf(syslink, sizeof(syslink), "/sys/class/input/%s/device", evname);

    /* realpath로 완전 해석: "/sys/class/input/event11/device"의
     * device 심볼릭 링크가 ".."(상대 경로)이므로 readlink만으로는 inputN을 얻을 수 없다 */
    char resolved[PATH_MAX];
    if (!realpath(syslink, resolved)) return 0;

    /* 마지막 컴포넌트 (inputN) */
    const char *inputname = strrchr(resolved, '/');
    if (!inputname) return 0;
    inputname++; /* skip '/' */

    /* /run/udev/data/+input:inputN 스캔 */
    char udevpath[128];
    snprintf(udevpath, sizeof(udevpath), "/run/udev/data/+input:%s", inputname);

    FILE *f = fopen(udevpath, "r");
    if (!f) return 0;

    char line[256];
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "E:ID_INPUT_JOYSTICK=1", 21) == 0) {
            found = 1;
            break;
        }
    }
    fclose(f);
    return found;
}

/* ── is_our_vdev ─────────────────────────────────────────────── */
static int is_our_vdev(const char *devpath)
{
    int fd = open(devpath, O_RDONLY | O_NONBLOCK);
    if (fd < 0) return 0;
    char name[64];
    int ret = ioctl(fd, EVIOCGNAME(sizeof(name)), name);
    close(fd);
    if (ret < 0) return 0;
    return strncmp(name, "RetroPangUI", 11) == 0;
}

/* ── is_sdl_managed ──────────────────────────────────────────── */
static int is_sdl_managed(dev_t rdev)
{
    for (int i = 0; i < GP_MAX_SLOTS; i++) {
        if (g_phys_fd[i] >= 0) {
            struct stat st;
            if (fstat(g_phys_fd[i], &st) == 0 && st.st_rdev == rdev)
                return 1;
        }
    }
    return 0;
}

/* ── passive_grab ────────────────────────────────────────────── */
static void passive_grab(const char *devpath)
{
    if (g_n_passive >= GP_MAX_SLOTS) {
        fprintf(stderr, "gamepad_daemon: passive grab list full, skipping %s\n", devpath);
        return;
    }

    int fd = open(devpath, O_RDWR | O_NONBLOCK);
    if (fd < 0) {
        fprintf(stderr, "gamepad_daemon: passive_grab open %s: %s\n", devpath, strerror(errno));
        return;
    }

    struct stat st;
    if (fstat(fd, &st) != 0) {
        close(fd);
        return;
    }

    /* SDL이 이미 관리하는 장치는 건너뜀 */
    if (is_sdl_managed(st.st_rdev)) {
        close(fd);
        return;
    }

    /* 이미 passive grab 중인 장치 중복 방지 */
    for (int i = 0; i < g_n_passive; i++) {
        if (g_passive[i].rdev == st.st_rdev) {
            close(fd);
            return;
        }
    }

    if (ioctl(fd, EVIOCGRAB, 1) < 0) {
        fprintf(stderr, "gamepad_daemon: passive EVIOCGRAB %s: %s\n", devpath, strerror(errno));
        close(fd);
        return;
    }

    g_passive[g_n_passive].fd   = fd;
    g_passive[g_n_passive].rdev = st.st_rdev;
    strncpy(g_passive[g_n_passive].path, devpath, sizeof(g_passive[g_n_passive].path) - 1);
    g_passive[g_n_passive].path[sizeof(g_passive[g_n_passive].path) - 1] = '\0';
    g_n_passive++;

    fprintf(stderr, "gamepad_daemon: passive grab %s OK\n", devpath);
}

/* ── passive_release_by_rdev ─────────────────────────────────── */
static void passive_release_by_rdev(dev_t rdev)
{
    for (int i = 0; i < g_n_passive; i++) {
        if (g_passive[i].rdev == rdev) {
            ioctl(g_passive[i].fd, EVIOCGRAB, 0);
            close(g_passive[i].fd);
            g_passive[i] = g_passive[g_n_passive - 1];
            g_n_passive--;
            fprintf(stderr, "gamepad_daemon: passive release by rdev OK\n");
            return;
        }
    }
}

/* ── passive_release_by_path ─────────────────────────────────── */
static void passive_release_by_path(const char *devpath)
{
    for (int i = 0; i < g_n_passive; i++) {
        if (strcmp(g_passive[i].path, devpath) == 0) {
            ioctl(g_passive[i].fd, EVIOCGRAB, 0);
            close(g_passive[i].fd);
            g_passive[i] = g_passive[g_n_passive - 1];
            g_n_passive--;
            fprintf(stderr, "gamepad_daemon: passive release %s OK\n", devpath);
            return;
        }
    }
}

/* ── startup_scan ────────────────────────────────────────────── */
static void startup_scan(void)
{
    DIR *dir = opendir("/dev/input");
    if (!dir) {
        perror("gamepad_daemon: startup_scan opendir /dev/input");
        return;
    }

    struct dirent *de;
    while ((de = readdir(dir)) != NULL) {
        if (strncmp(de->d_name, "event", 5) != 0) continue;

        char path[64];
        snprintf(path, sizeof(path), "/dev/input/%s", de->d_name);

        if (is_our_vdev(path)) continue;
        if (!is_joystick_by_udev(path)) continue;

        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;
        struct stat st;
        if (fstat(fd, &st) == 0 && is_sdl_managed(st.st_rdev)) {
            close(fd);
            continue;
        }
        close(fd);

        passive_grab(path);
    }
    closedir(dir);
}

/* ── process_inotify ─────────────────────────────────────────── */
static void process_inotify(void)
{
    if (g_inotify_fd < 0) return;

    char buf[sizeof(struct inotify_event) + NAME_MAX + 1];
    ssize_t len = read(g_inotify_fd, buf, sizeof(buf));
    if (len < 0) return; /* EAGAIN = no events */

    char *p = buf;
    while (p < buf + len) {
        struct inotify_event *ev = (struct inotify_event *)p;
        p += sizeof(struct inotify_event) + ev->len;

        if (ev->len == 0) continue;
        if (strncmp(ev->name, "event", 5) != 0) continue;

        char path[64];
        snprintf(path, sizeof(path), "/dev/input/%s", ev->name);

        if (ev->mask & IN_CREATE) {
            if (g_n_pending < GP_MAX_SLOTS) {
                strncpy(g_pending[g_n_pending].path, path,
                        sizeof(g_pending[g_n_pending].path) - 1);
                g_pending[g_n_pending].path[sizeof(g_pending[g_n_pending].path) - 1] = '\0';
                g_pending[g_n_pending].ready_ms = mono_ms() + 200;
                g_n_pending++;
            }
        } else if (ev->mask & IN_DELETE) {
            passive_release_by_path(path);
            /* g_pending에서도 제거 */
            for (int i = 0; i < g_n_pending; i++) {
                if (strcmp(g_pending[i].path, path) == 0) {
                    g_pending[i] = g_pending[g_n_pending - 1];
                    g_n_pending--;
                    break;
                }
            }
        }
    }
}

/* ── process_pending ─────────────────────────────────────────── */
static void process_pending(void)
{
    uint64_t now = mono_ms();
    for (int i = 0; i < g_n_pending; ) {
        if (now < g_pending[i].ready_ms) {
            i++;
            continue;
        }

        char path[64];
        strncpy(path, g_pending[i].path, sizeof(path) - 1);
        path[sizeof(path) - 1] = '\0';

        /* swap-with-last 제거 */
        g_pending[i] = g_pending[g_n_pending - 1];
        g_n_pending--;

        if (is_our_vdev(path)) continue;
        if (!is_joystick_by_udev(path)) continue;

        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) continue;
        struct stat st;
        if (fstat(fd, &st) == 0 && is_sdl_managed(st.st_rdev)) {
            close(fd);
            continue;
        }
        close(fd);

        passive_grab(path);
    }
}

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

    /* 이미 다른 슬롯에 할당된 장치(st_rdev)는 건너뜀 — 같은 vid+pid 다중 장치 지원 */
    dev_t used[GP_MAX_SLOTS];
    int n_used = 0;
    for (int i = 0; i < GP_MAX_SLOTS; i++) {
        if (g_phys_fd[i] >= 0) {
            struct stat st;
            if (fstat(g_phys_fd[i], &st) == 0)
                used[n_used++] = st.st_rdev;
        }
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

        struct stat st;
        int skip = 0;
        if (fstat(fd, &st) == 0) {
            for (int i = 0; i < n_used; i++) {
                if (used[i] == st.st_rdev) { skip = 1; break; }
            }
        }
        if (skip) { close(fd); continue; }

        struct input_id iid;
        if (ioctl(fd, EVIOCGID, &iid) < 0 ||
            iid.vendor  != vid ||
            iid.product != pid) {
            close(fd);
            continue;
        }

        /* VID:PID 일치 — 같은 VID:PID를 가진 장치가 여럿일 때(예: Xbox 무선 수신기 +
         * 컨트롤러 슬롯) SDL이 실제로 연 장치를 우선 선택한다.
         * SDL이 열어둔 fd와 같은 st_rdev인 장치를 찾으면 즉시 반환.
         * 없으면 EV_ABS(축)가 있는 첫 번째 장치를 반환한다(수신기 자체 제외). */
        int is_sdl = 0;
        {
            struct stat cur;
            if (fstat(fd, &cur) == 0) {
                DIR *pd = opendir("/proc/self/fd");
                if (pd) {
                    struct dirent *pe;
                    while ((pe = readdir(pd)) != NULL) {
                        if (pe->d_name[0] == '.') continue;
                        int pfd = atoi(pe->d_name);
                        if (pfd <= 2 || pfd == fd) continue;
                        struct stat ps;
                        if (fstat(pfd, &ps) == 0 &&
                            S_ISCHR(ps.st_mode) &&
                            ps.st_rdev == cur.st_rdev &&
                            !fd_is_deleted(pfd)) {
                            is_sdl = 1;
                            break;
                        }
                    }
                    closedir(pd);
                }
            }
        }
        if (is_sdl) {
            /* SDL이 열어둔 장치 — 완벽한 매칭, 즉시 반환
             * (앞서 보관한 EV_ABS 후보 fd는 누수되지 않게 닫는다) */
            if (found_fd >= 0)
                close(found_fd);
            found_fd = fd;
            break;
        }

        /* SDL이 열지 않은 장치 — EV_ABS가 있으면 후보로 보관, 계속 탐색 */
        unsigned long evbit = 0;
        ioctl(fd, EVIOCGBIT(0, sizeof(evbit)), &evbit);
        if (evbit & (1 << EV_ABS)) {
            if (found_fd < 0)
                found_fd = fd; /* 첫 번째 EV_ABS 후보 */
            else
                close(fd);
        } else {
            close(fd); /* 수신기 같은 비-joystick 장치 스킵 */
        }
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
            st.st_rdev == our_st.st_rdev &&
            !fd_is_deleted(fd)) { /* 같은 rdev여도 옛 장치의 스테일 fd 제외 */
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

        /* SDL이 연결한 장치는 passive grab에서 해제 */
        if (phys_fd >= 0) {
            struct stat st;
            if (fstat(phys_fd, &st) == 0)
                passive_release_by_rdev(st.st_rdev);
        }

        /* SDL이 열어둔 fd에 EVIOCGRAB — SDL은 이벤트 계속 수신, ES/RA는 차단 */
        if (phys_fd >= 0) {
            int sdl_fd = find_sdl_evdev_fd(phys_fd);
            if (sdl_fd >= 0) {
                if (ioctl(sdl_fd, EVIOCGRAB, 1) < 0)
                    fprintf(stderr, "gamepad_daemon: EVIOCGRAB slot %d: %s\n",
                            slot, strerror(errno));
                else
                    fprintf(stderr, "gamepad_daemon: EVIOCGRAB slot %d: OK\n", slot);
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
        /* 무선 컨트롤러는 연결 직후 SDL2 axis가 -32768로 보고될 수 있음.
         * RA가 vdev를 열었을 때 "LS 최대 좌/상 고정" 상태로 인식하는 것을 방지하기 위해
         * center 상태(all axes=0, all buttons=0)를 즉시 emit한다. */
        if (g_vdev[slot]) {
            GP_State center = {0};
            gp_vdev_write_state(g_vdev[slot], &center, NULL);
        }
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

    /* inotify 초기화 — vdev 생성 전에, 생성 중 도착하는 이벤트도 놓치지 않도록 */
    g_inotify_fd = inotify_init1(IN_NONBLOCK);
    if (g_inotify_fd >= 0)
        g_inotify_wd = inotify_add_watch(g_inotify_fd, "/dev/input",
                                         IN_CREATE | IN_DELETE);

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
    int hygiene_tick = 0;
    while (g_running) {
        gp_update();

        /* 1초마다 슬롯 phys_fd 위생 점검 — unplug 시 SDL REMOVED 이벤트가
         * 유실된 슬롯(다중 인터페이스 패드 등)의 스테일 fd를 정리한다 */
        if (++hygiene_tick >= 125) {
            hygiene_tick = 0;
            for (int slot = 0; slot < GP_MAX_SLOTS; slot++) {
                if (g_phys_fd[slot] >= 0 && fd_is_deleted(g_phys_fd[slot])) {
                    fprintf(stderr, "gamepad_daemon: slot %d stale phys fd 정리\n", slot);
                    close(g_phys_fd[slot]);
                    g_phys_fd[slot] = -1;
                    if (g_vdev[slot])
                        gp_vdev_rebind_phys(g_vdev[slot], -1);
                }
            }
        }

        /* 첫 루프에서 startup_scan 실행 (SDL init 완료 후) */
        if (!g_startup_done) {
            startup_scan();
            g_startup_done = 1;
        }
        process_inotify();
        process_pending();

        for (int slot = 0; slot < GP_MAX_SLOTS; slot++) {
            if (!g_vdev[slot]) continue;
            if (g_phys_fd[slot] < 0) continue; /* 물리 패드 없는 슬롯 무시 */
            if (!gp_get_state(slot, &cur)) continue;
            gp_vdev_write_state(g_vdev[slot], &cur, &g_prev[slot]);
            gp_vdev_poll_ff(g_vdev[slot]);
            g_prev[slot] = cur;
        }

        usleep(8000); /* 8ms ≈ 125Hz */
    }

    /* 정리 */
    for (int i = 0; i < g_n_passive; i++) {
        ioctl(g_passive[i].fd, EVIOCGRAB, 0);
        close(g_passive[i].fd);
    }
    g_n_passive = 0;
    if (g_inotify_fd >= 0) {
        close(g_inotify_fd);
        g_inotify_fd = -1;
    }

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
