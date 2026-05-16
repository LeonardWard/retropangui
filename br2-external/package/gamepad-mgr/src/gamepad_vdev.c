/* gamepad_vdev.c — uinput 가상 패드 구현
 * C99, 외부 의존: SDL2 헤더(gamepad.h 경유), Linux input/uinput
 */
#include "gamepad_vdev.h"
#include <linux/uinput.h>
#include <linux/input.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <dirent.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#define FF_MAX_EFFECTS 16

/* ── 내부 구조체 ──────────────────────────────────────────────── */
struct GP_VDev {
    int uinput_fd;  /* /dev/uinput fd */
    int phys_fd;    /* 물리 evdev fd, -1이면 FF 없음 (외부 소유 — 닫지 않음) */
    int slot;       /* 0~3 */
    int has_ff;     /* 1이면 FF_RUMBLE 지원 */
    int prev_hat_x; /* 이전 HAT X (-1/0/1), 초기값=999(강제 갱신용) */
    int prev_hat_y; /* 이전 HAT Y */
    int ff_id_map[FF_MAX_EFFECTS]; /* virt_id → phys_id 매핑; -1=미등록 */
};

/* ── 버튼/축 매핑 테이블 ──────────────────────────────────────── */
/* GP_BTN_DPAD_* 은 HAT으로 처리하므로 여기서 제외 (13개 버튼) */
static const int k_btn_gp[13] = {
    GP_BTN_A, GP_BTN_B, GP_BTN_X, GP_BTN_Y,
    GP_BTN_L1, GP_BTN_R1, GP_BTN_L2, GP_BTN_R2,
    GP_BTN_L3, GP_BTN_R3, GP_BTN_START, GP_BTN_SELECT, GP_BTN_GUIDE
};
static const int k_btn_linux[13] = {
    BTN_SOUTH, BTN_EAST, BTN_NORTH, BTN_WEST,
    BTN_TL, BTN_TR, BTN_TL2, BTN_TR2,
    BTN_THUMBL, BTN_THUMBR, BTN_START, BTN_SELECT, BTN_MODE
};
#define BTN_MAP_LEN 13

static const int k_axis_gp[GP_AXIS_COUNT] = {
    GP_AXIS_LEFT_X, GP_AXIS_LEFT_Y,
    GP_AXIS_RIGHT_X, GP_AXIS_RIGHT_Y,
    GP_AXIS_L2, GP_AXIS_R2
};
static const int k_axis_linux[GP_AXIS_COUNT] = {
    ABS_X, ABS_Y, ABS_RX, ABS_RY, ABS_Z, ABS_RZ
};

/* ── 내부 헬퍼 ────────────────────────────────────────────────── */
static void emit(int fd, unsigned short type, unsigned short code, int value)
{
    struct input_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.type  = type;
    ev.code  = code;
    ev.value = value;
    /* ev.time 은 0으로 두면 커널이 채워준다 */
    if (write(fd, &ev, sizeof(ev)) < 0) {
        fprintf(stderr, "gamepad_vdev: emit write failed: %s\n", strerror(errno));
    }
}

static int setup_abs(int fd, int abscode, int min, int max, int flat, int fuzz)
{
    struct uinput_abs_setup abs;
    memset(&abs, 0, sizeof(abs));
    abs.code            = (unsigned short)abscode;
    abs.absinfo.minimum = min;
    abs.absinfo.maximum = max;
    abs.absinfo.flat    = flat;
    abs.absinfo.fuzz    = fuzz;
    if (ioctl(fd, UI_SET_ABSBIT, abscode) < 0) return -1;
    if (ioctl(fd, UI_ABS_SETUP,  &abs)    < 0) return -1;
    return 0;
}

/* ── 공개 API ─────────────────────────────────────────────────── */

GP_VDev *gp_vdev_create(int slot, int phys_evdev_fd)
{
    if (slot < 0 || slot > 3) {
        fprintf(stderr, "gamepad_vdev: invalid slot %d\n", slot);
        return NULL;
    }

    GP_VDev *vdev = calloc(1, sizeof(GP_VDev));
    if (!vdev) {
        fprintf(stderr, "gamepad_vdev: calloc failed\n");
        return NULL;
    }
    vdev->phys_fd    = phys_evdev_fd;
    vdev->slot       = slot;
    vdev->has_ff     = 0;
    vdev->prev_hat_x = 999;
    vdev->prev_hat_y = 999;
    for (int i = 0; i < FF_MAX_EFFECTS; i++)
        vdev->ff_id_map[i] = -1;

    /* 1. /dev/uinput 열기 */
    vdev->uinput_fd = open("/dev/uinput", O_RDWR | O_NONBLOCK);
    if (vdev->uinput_fd < 0) {
        fprintf(stderr, "gamepad_vdev: cannot open /dev/uinput: %s\n", strerror(errno));
        free(vdev);
        return NULL;
    }

    /* 2. 버튼 */
    if (ioctl(vdev->uinput_fd, UI_SET_EVBIT, EV_KEY) < 0) {
        perror("gamepad_vdev: UI_SET_EVBIT EV_KEY");
        goto err;
    }
    for (int i = 0; i < BTN_MAP_LEN; i++) {
        if (ioctl(vdev->uinput_fd, UI_SET_KEYBIT, k_btn_linux[i]) < 0) {
            fprintf(stderr, "gamepad_vdev: UI_SET_KEYBIT %d failed: %s\n",
                    k_btn_linux[i], strerror(errno));
            goto err;
        }
    }

    /* 3. 절대축 */
    if (ioctl(vdev->uinput_fd, UI_SET_EVBIT, EV_ABS) < 0) {
        perror("gamepad_vdev: UI_SET_EVBIT EV_ABS");
        goto err;
    }
    /* 스틱 4축 */
    for (int i = 0; i < 4; i++) {
        if (setup_abs(vdev->uinput_fd, k_axis_linux[i], -32767, 32767, 128, 16) < 0) {
            fprintf(stderr, "gamepad_vdev: setup_abs %d failed\n", k_axis_linux[i]);
            goto err;
        }
    }
    /* 트리거 2축 */
    for (int i = 4; i < 6; i++) {
        if (setup_abs(vdev->uinput_fd, k_axis_linux[i], 0, 32767, 0, 16) < 0) {
            fprintf(stderr, "gamepad_vdev: setup_abs %d failed\n", k_axis_linux[i]);
            goto err;
        }
    }
    /* HAT */
    if (setup_abs(vdev->uinput_fd, ABS_HAT0X, -1, 1, 0, 0) < 0 ||
        setup_abs(vdev->uinput_fd, ABS_HAT0Y, -1, 1, 0, 0) < 0) {
        perror("gamepad_vdev: setup_abs HAT");
        goto err;
    }

    /* 4. FF 능력 선언 — 물리 장치 유무와 무관하게 항상 활성화
     *    물리 장치가 없을 때 FF 요청은 poll_ff에서 -EINVAL로 처리된다.
     *    물리 장치가 나중에 rebind되면 그 시점부터 진동이 작동한다. */
    vdev->has_ff = 1;
    if (ioctl(vdev->uinput_fd, UI_SET_EVBIT, EV_FF) < 0 ||
        ioctl(vdev->uinput_fd, UI_SET_FFBIT, FF_RUMBLE) < 0) {
        fprintf(stderr, "gamepad_vdev: FF setup failed, continuing without FF\n");
        vdev->has_ff = 0;
    }

    /* 5. 장치 생성 */
    struct uinput_setup us;
    memset(&us, 0, sizeof(us));
    snprintf(us.name, UINPUT_MAX_NAME_SIZE, "RetroPangUI P%d", slot + 1);
    us.id.bustype    = 0x0006; /* BUS_VIRTUAL */
    us.id.vendor     = 0x5052; /* "RP" */
    us.id.product    = (unsigned short)(slot + 1);
    us.id.version    = 1;
    us.ff_effects_max = 16;

    if (ioctl(vdev->uinput_fd, UI_DEV_SETUP, &us) < 0) {
        perror("gamepad_vdev: UI_DEV_SETUP");
        goto err;
    }
    if (ioctl(vdev->uinput_fd, UI_DEV_CREATE) < 0) {
        perror("gamepad_vdev: UI_DEV_CREATE");
        goto err;
    }

    fprintf(stderr, "gamepad_vdev: created \"%s\" (slot %d, ff=%d)\n",
            us.name, slot, vdev->has_ff);
    return vdev;

err:
    close(vdev->uinput_fd);
    free(vdev);
    return NULL;
}

void gp_vdev_destroy(GP_VDev *vdev)
{
    if (!vdev) return;
    ioctl(vdev->uinput_fd, UI_DEV_DESTROY);
    close(vdev->uinput_fd);
    /* phys_fd는 외부 소유 — 닫지 않음 */
    free(vdev);
}

void gp_vdev_rebind_phys(GP_VDev *vdev, int phys_evdev_fd)
{
    if (!vdev) return;
    vdev->phys_fd = phys_evdev_fd;
    for (int i = 0; i < FF_MAX_EFFECTS; i++)
        vdev->ff_id_map[i] = -1;
    fprintf(stderr, "gamepad_vdev: slot %d rebind phys_fd=%d\n",
            vdev->slot, phys_evdev_fd);
}

void gp_vdev_write_state(GP_VDev *vdev, const GP_State *state, const GP_State *prev)
{
    if (!vdev || !state) return;

    int changed = 0;

    /* 버튼 (DPAD 제외 13개) */
    for (int i = 0; i < BTN_MAP_LEN; i++) {
        int gp_btn = k_btn_gp[i];
        int new_val = state->buttons[gp_btn] ? 1 : 0;
        if (prev == NULL || new_val != (prev->buttons[gp_btn] ? 1 : 0)) {
            emit(vdev->uinput_fd, EV_KEY, (unsigned short)k_btn_linux[i], new_val);
            changed = 1;
        }
    }

    /* 스틱/트리거 축 */
    for (int i = 0; i < GP_AXIS_COUNT; i++) {
        int gp_ax = k_axis_gp[i];
        /* 트리거(GP_AXIS_L2, GP_AXIS_R2)는 0~1.0, 스틱은 -1.0~1.0 */
        int new_raw = (int)(state->axes[gp_ax] * 32767.0f);
        if (prev == NULL || new_raw != (int)(prev->axes[gp_ax] * 32767.0f)) {
            emit(vdev->uinput_fd, EV_ABS, (unsigned short)k_axis_linux[i], new_raw);
            changed = 1;
        }
    }

    /* DPAD → HAT */
    int hat_y = (state->buttons[GP_BTN_DPAD_UP]   ? -1 : 0)
              + (state->buttons[GP_BTN_DPAD_DOWN]  ?  1 : 0);
    int hat_x = (state->buttons[GP_BTN_DPAD_LEFT]  ? -1 : 0)
              + (state->buttons[GP_BTN_DPAD_RIGHT]  ?  1 : 0);
    if (hat_y != vdev->prev_hat_y) {
        emit(vdev->uinput_fd, EV_ABS, ABS_HAT0Y, hat_y);
        vdev->prev_hat_y = hat_y;
        changed = 1;
    }
    if (hat_x != vdev->prev_hat_x) {
        emit(vdev->uinput_fd, EV_ABS, ABS_HAT0X, hat_x);
        vdev->prev_hat_x = hat_x;
        changed = 1;
    }

    /* SYN_REPORT — 변경이 있을 때만 */
    if (changed) {
        emit(vdev->uinput_fd, EV_SYN, SYN_REPORT, 0);
    }
}

void gp_vdev_poll_ff(GP_VDev *vdev)
{
    if (!vdev || !vdev->has_ff) return;

    struct input_event ev;
    for (;;) {
        ssize_t n = read(vdev->uinput_fd, &ev, sizeof(ev));
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) break;
            fprintf(stderr, "gamepad_vdev: poll_ff read: %s\n", strerror(errno));
            break;
        }
        if (n == 0) break;

        if (ev.type == EV_UINPUT && ev.code == UI_FF_UPLOAD) {
            struct uinput_ff_upload upload;
            memset(&upload, 0, sizeof(upload));
            upload.request_id = (unsigned int)ev.value;
            ioctl(vdev->uinput_fd, UI_BEGIN_FF_UPLOAD, &upload);

            /*
             * upload.effect.id는 가상 장치가 할당한 슬롯 번호다.
             * 물리 장치에 그대로 전달하면 "기존 effect 수정"으로 해석되어
             * 슬롯이 없을 경우 EINVAL을 반환한다.
             * id=-1로 강제해 신규 할당을 요청하고, 반환된 phys_id를 매핑 테이블에 저장한다.
             */
            int virt_id = upload.effect.id;
            int phys_id_existing = (virt_id >= 0 && virt_id < FF_MAX_EFFECTS)
                                   ? vdev->ff_id_map[virt_id] : -1;

            /* 기존 매핑이 있으면 phys 슬롯 갱신, 없으면 신규 할당 */
            upload.effect.id = (phys_id_existing >= 0) ? phys_id_existing : -1;

            if (vdev->phys_fd >= 0) {
                int ret = ioctl(vdev->phys_fd, EVIOCSFF, &upload.effect);
                if (ret >= 0) {
                    /* upload.effect.id가 물리 장치 슬롯으로 갱신됨 */
                    if (virt_id >= 0 && virt_id < FF_MAX_EFFECTS)
                        vdev->ff_id_map[virt_id] = upload.effect.id;
                    upload.retval = 0;
                    fprintf(stderr, "gamepad_vdev: FF upload virt=%d → phys=%d\n",
                            virt_id, upload.effect.id);
                } else {
                    upload.retval = -errno;
                    fprintf(stderr, "gamepad_vdev: FF upload EVIOCSFF failed: %s\n",
                            strerror(errno));
                }
            } else {
                upload.retval = -EINVAL;
            }

            /* 커널은 UI_END_FF_UPLOAD에서 effect.id를 무시하지만 복원해둔다 */
            upload.effect.id = virt_id;
            ioctl(vdev->uinput_fd, UI_END_FF_UPLOAD, &upload);

        } else if (ev.type == EV_UINPUT && ev.code == UI_FF_ERASE) {
            struct uinput_ff_erase erase;
            memset(&erase, 0, sizeof(erase));
            erase.request_id = (unsigned int)ev.value;
            ioctl(vdev->uinput_fd, UI_BEGIN_FF_ERASE, &erase);
            if (vdev->phys_fd >= 0) {
                int vid = (int)erase.effect_id;
                int pid = (vid >= 0 && vid < FF_MAX_EFFECTS) ? vdev->ff_id_map[vid] : -1;
                if (pid >= 0) {
                    ioctl(vdev->phys_fd, EVIOCRMFF, pid);
                    vdev->ff_id_map[vid] = -1;
                }
            }
            ioctl(vdev->uinput_fd, UI_END_FF_ERASE, &erase);

        } else if (ev.type == EV_FF) {
            /* EV_FF.code = virt_id → phys_id로 변환해서 물리 장치에 전달 */
            if (vdev->phys_fd >= 0) {
                int virt_id = (int)ev.code;
                int phys_id = (virt_id >= 0 && virt_id < FF_MAX_EFFECTS)
                              ? vdev->ff_id_map[virt_id] : -1;
                if (phys_id >= 0) {
                    struct input_event fwd = ev;
                    fwd.code = (unsigned short)phys_id;
                    if (write(vdev->phys_fd, &fwd, sizeof(fwd)) < 0) {
                        fprintf(stderr, "gamepad_vdev: FF passthrough write: %s\n",
                                strerror(errno));
                    } else {
                        fprintf(stderr, "gamepad_vdev: FF play virt=%d phys=%d val=%d\n",
                                virt_id, phys_id, ev.value);
                    }
                } else {
                    fprintf(stderr, "gamepad_vdev: FF EV_FF virt_id=%d: no phys mapping\n",
                            virt_id);
                }
            }
        }
    }
}

int gp_vdev_get_uinput_fd(GP_VDev *vdev)
{
    if (!vdev) return -1;
    return vdev->uinput_fd;
}
