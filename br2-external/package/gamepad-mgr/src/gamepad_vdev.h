/* gamepad_vdev.h — uinput 가상 패드 관리 모듈
 *
 * /dev/uinput을 통해 Player 1~4 가상 gamepad 장치를 생성한다.
 * 물리 장치의 FF(Force Feedback)가 지원될 경우 FF 이벤트를 패스스루한다.
 */
#pragma once
#include "gamepad.h"   /* GP_State, GP_Button, GP_Axis 등 */

typedef struct GP_VDev GP_VDev;

/* 슬롯 0~3, phys_evdev_fd: /dev/input/eventX (없으면 -1, 나중에 rebind 가능) */
GP_VDev *gp_vdev_create(int slot, int phys_evdev_fd);
void     gp_vdev_destroy(GP_VDev *vdev);

/* 물리 장치 교체 (연결/해제 시). phys_evdev_fd=-1이면 unbind */
void     gp_vdev_rebind_phys(GP_VDev *vdev, int phys_evdev_fd);

/* prev와 비교해 변경된 필드만 EV_KEY/EV_ABS 이벤트로 write, SYN_REPORT로 마무리 */
void gp_vdev_write_state(GP_VDev *vdev, const GP_State *state, const GP_State *prev);

/* uinput fd에서 FF 이벤트를 non-blocking으로 읽어 물리 장치로 패스스루 */
void gp_vdev_poll_ff(GP_VDev *vdev);

/* uinput fd 반환 (외부에서 select/epoll 등록용) */
int gp_vdev_get_uinput_fd(GP_VDev *vdev);
