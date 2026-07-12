/*
 * odroid-drm-fbset — Odroid C5 (Amlogic S905X5M, aml_drm) HDMI 모드 설정 도구.
 * 원본 블랙박스 바이너리의 atomic commit을 debugfs로 실측한 사양을 따른다.
 * 출력 문자열 포맷은 스크립트가 grep으로 파싱하므로 변경 금지.
 */
#define _POSIX_C_SOURCE 200809L /* C99 모드에서 O_CLOEXEC 노출용 */

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <xf86drm.h>
#include <xf86drmMode.h>

#define DRM_DEVICE "/dev/dri/card0"

#ifndef DRM_PLANE_TYPE_PRIMARY
#define DRM_PLANE_TYPE_PRIMARY 1
#endif

/* drmModeGetConnectorTypeName()은 libdrm 2.4.112+ 전용이라 자체 테이블 사용 */
static const char *connector_type_name(uint32_t type)
{
    switch (type) {
    case DRM_MODE_CONNECTOR_VGA:         return "VGA";
    case DRM_MODE_CONNECTOR_DVII:        return "DVI-I";
    case DRM_MODE_CONNECTOR_DVID:        return "DVI-D";
    case DRM_MODE_CONNECTOR_DVIA:        return "DVI-A";
    case DRM_MODE_CONNECTOR_Composite:   return "Composite";
    case DRM_MODE_CONNECTOR_SVIDEO:      return "SVIDEO";
    case DRM_MODE_CONNECTOR_LVDS:        return "LVDS";
    case DRM_MODE_CONNECTOR_Component:   return "Component";
    case DRM_MODE_CONNECTOR_9PinDIN:     return "DIN";
    case DRM_MODE_CONNECTOR_DisplayPort: return "DP";
    case DRM_MODE_CONNECTOR_HDMIA:       return "HDMI-A";
    case DRM_MODE_CONNECTOR_HDMIB:       return "HDMI-B";
    case DRM_MODE_CONNECTOR_TV:          return "TV";
    case DRM_MODE_CONNECTOR_eDP:         return "eDP";
    case DRM_MODE_CONNECTOR_VIRTUAL:     return "Virtual";
    case DRM_MODE_CONNECTOR_DSI:         return "DSI";
#ifdef DRM_MODE_CONNECTOR_DPI
    case DRM_MODE_CONNECTOR_DPI:         return "DPI";
#endif
#ifdef DRM_MODE_CONNECTOR_WRITEBACK
    case DRM_MODE_CONNECTOR_WRITEBACK:   return "Writeback";
#endif
#ifdef DRM_MODE_CONNECTOR_SPI
    case DRM_MODE_CONNECTOR_SPI:         return "SPI";
#endif
#ifdef DRM_MODE_CONNECTOR_USB
    case DRM_MODE_CONNECTOR_USB:         return "USB";
#endif
    default:                             return "Unknown";
    }
}

/* 오브젝트의 프로퍼티를 이름으로 찾아 ID를 반환. 없으면 0. */
static uint32_t find_prop_id(int fd, uint32_t obj_id, uint32_t obj_type,
                             const char *name)
{
    drmModeObjectProperties *props;
    uint32_t prop_id = 0;
    uint32_t i;

    props = drmModeObjectGetProperties(fd, obj_id, obj_type);
    if (!props)
        return 0;

    for (i = 0; i < props->count_props; i++) {
        drmModePropertyRes *p = drmModeGetProperty(fd, props->props[i]);
        if (!p)
            continue;
        if (strcmp(p->name, name) == 0)
            prop_id = p->prop_id;
        drmModeFreeProperty(p);
        if (prop_id)
            break;
    }
    drmModeFreeObjectProperties(props);
    return prop_id;
}

/* 오브젝트 프로퍼티의 현재 값을 이름으로 조회. 성공 시 1, 실패 시 0. */
static int get_prop_value(int fd, uint32_t obj_id, uint32_t obj_type,
                          const char *name, uint64_t *out)
{
    drmModeObjectProperties *props;
    int found = 0;
    uint32_t i;

    props = drmModeObjectGetProperties(fd, obj_id, obj_type);
    if (!props)
        return 0;

    for (i = 0; i < props->count_props && !found; i++) {
        drmModePropertyRes *p = drmModeGetProperty(fd, props->props[i]);
        if (!p)
            continue;
        if (strcmp(p->name, name) == 0) {
            *out = props->prop_values[i];
            found = 1;
        }
        drmModeFreeProperty(p);
    }
    drmModeFreeObjectProperties(props);
    return found;
}

static int do_showmodes(int fd, drmModeRes *res)
{
    int i, j;

    printf("Found %d CRTC(s) and %d CONNECTOR(s)\n",
           res->count_crtcs, res->count_connectors);

    printf("CRTC ID(s):\n");
    for (i = 0; i < res->count_crtcs; i++)
        printf("\tCRTC[%d] = %d\n", i, res->crtcs[i]);

    printf("CONNECTOR(s):\n");
    for (i = 0; i < res->count_connectors; i++) {
        drmModeConnector *conn = drmModeGetConnector(fd, res->connectors[i]);
        if (!conn)
            continue;

        printf("\tCONNECTOR[%d] = %d, %s-%d (%d modes)\n",
               i, conn->connector_id,
               connector_type_name(conn->connector_type),
               conn->connector_type_id, conn->count_modes);

        for (j = 0; j < conn->count_modes; j++) {
            drmModeModeInfo *m = &conn->modes[j];
            printf("\t\t%s : %dx%d@%d%s\n",
                   m->name, m->hdisplay, m->vdisplay, (int)m->vrefresh,
                   (m->type & DRM_MODE_TYPE_PREFERRED) ? " (preferred)" : "");
        }
        drmModeFreeConnector(conn);
    }
    return 0;
}

static int do_setmode(int fd, drmModeRes *res, const char *mode_name)
{
    drmModeConnector *conn = NULL;
    drmModePlane *plane = NULL;
    drmModeAtomicReq *req = NULL;
    drmModeModeInfo *mode = NULL;
    uint32_t crtc_id = 0, blob_id = 0;
    int crtc_idx = -1;
    int i, ret = 1;

    /* connected이고 모드가 있는 첫 커넥터 */
    for (i = 0; i < res->count_connectors; i++) {
        drmModeConnector *c = drmModeGetConnector(fd, res->connectors[i]);
        if (!c)
            continue;
        if (c->connection == DRM_MODE_CONNECTED && c->count_modes > 0) {
            conn = c;
            break;
        }
        drmModeFreeConnector(c);
    }

    /* 현재 encoder의 CRTC 우선, 없으면 첫 CRTC */
    if (conn) {
        if (conn->encoder_id) {
            drmModeEncoder *enc = drmModeGetEncoder(fd, conn->encoder_id);
            if (enc) {
                crtc_id = enc->crtc_id;
                drmModeFreeEncoder(enc);
            }
        }
        if (!crtc_id && res->count_crtcs > 0)
            crtc_id = res->crtcs[0];
        for (i = 0; i < res->count_crtcs; i++) {
            if (res->crtcs[i] == crtc_id) {
                crtc_idx = i;
                break;
            }
        }
    }

    if (!conn || !crtc_id || crtc_idx < 0) {
        fprintf(stderr, "failed get connector or crtc\n");
        goto out;
    }

    /* 모드 선택: preferred 또는 정확한 이름 일치(폴백 금지) */
    if (strcmp(mode_name, "preferred") == 0) {
        for (i = 0; i < conn->count_modes; i++) {
            if (conn->modes[i].type & DRM_MODE_TYPE_PREFERRED) {
                mode = &conn->modes[i];
                break;
            }
        }
        if (!mode)
            mode = &conn->modes[0];
    } else {
        for (i = 0; i < conn->count_modes; i++) {
            if (strcmp(conn->modes[i].name, mode_name) == 0) {
                mode = &conn->modes[i];
                break;
            }
        }
        if (!mode) {
            fprintf(stderr, "mode '%s' not found (use -showmodes to list)\n",
                    mode_name);
            goto out;
        }
    }

    /* 해당 CRTC를 지원하는 primary plane 탐색 */
    {
        drmModePlaneRes *pres = drmModeGetPlaneResources(fd);
        if (pres) {
            uint32_t p;
            for (p = 0; p < pres->count_planes; p++) {
                drmModePlane *pl = drmModeGetPlane(fd, pres->planes[p]);
                uint64_t ptype;
                if (!pl)
                    continue;
                if ((pl->possible_crtcs & (1u << crtc_idx)) &&
                    get_prop_value(fd, pl->plane_id, DRM_MODE_OBJECT_PLANE,
                                   "type", &ptype) &&
                    ptype == DRM_PLANE_TYPE_PRIMARY) {
                    plane = pl;
                    break;
                }
                drmModeFreePlane(pl);
            }
            drmModeFreePlaneResources(pres);
        }
    }

    {
        uint32_t conn_crtc_id_p, crtc_mode_id_p, crtc_active_p;

        conn_crtc_id_p = find_prop_id(fd, conn->connector_id,
                                      DRM_MODE_OBJECT_CONNECTOR, "CRTC_ID");
        crtc_mode_id_p = find_prop_id(fd, crtc_id,
                                      DRM_MODE_OBJECT_CRTC, "MODE_ID");
        crtc_active_p  = find_prop_id(fd, crtc_id,
                                      DRM_MODE_OBJECT_CRTC, "ACTIVE");
        if (!conn_crtc_id_p || !crtc_mode_id_p || !crtc_active_p) {
            fprintf(stderr, "failed to set mode: %d-%s\n",
                    ENOENT, strerror(ENOENT));
            goto out;
        }

        if (drmModeCreatePropertyBlob(fd, mode, sizeof(*mode), &blob_id)) {
            fprintf(stderr, "failed to set mode: %d-%s\n",
                    errno, strerror(errno));
            goto out;
        }

        req = drmModeAtomicAlloc();
        if (!req) {
            fprintf(stderr, "failed to set mode: %d-%s\n",
                    ENOMEM, strerror(ENOMEM));
            goto out;
        }

        drmModeAtomicAddProperty(req, crtc_id, crtc_mode_id_p, blob_id);
        drmModeAtomicAddProperty(req, crtc_id, crtc_active_p, 1);
        drmModeAtomicAddProperty(req, conn->connector_id,
                                 conn_crtc_id_p, crtc_id);
    }

    /*
     * 플레인 처리 (실측 기반):
     * - fb 있음 + 파이프라인 비활성(부팅 직후 fbcon 상태) → fbcon fb 재사용해 활성화
     * - 이미 활성 → 건드리지 않음(모드만 변경)
     * - fb 없음 → 모드만 커밋, 경고
     *
     * 부팅 직후 debugfs 실측에서 fbcon이 plane->state->crtc를 이미 붙여놓아
     * (enable=0인데도 GETPLANE의 crtc_id가 0이 아닐 수 있음) crtc_id==0
     * 검사만으로는 부팅 상태를 못 잡는다 - CRTC ACTIVE 현재값(부팅 시 0,
     * 커밋 후 1)을 판정에 함께 쓴다.
     */
    uint64_t crtc_active_now = 1;
    get_prop_value(fd, crtc_id, DRM_MODE_OBJECT_CRTC, "ACTIVE",
                   &crtc_active_now);
    if (plane && plane->fb_id != 0 &&
        (crtc_active_now == 0 || plane->crtc_id == 0)) {
        drmModeFB *fb = drmModeGetFB(fd, plane->fb_id);
        if (fb) {
            /* fbcon fb는 세로 2배(더블버퍼)일 수 있어 모드 크기와 min이 필수 */
            uint32_t w = fb->width  < mode->hdisplay ? fb->width  : mode->hdisplay;
            uint32_t h = fb->height < mode->vdisplay ? fb->height : mode->vdisplay;
            uint32_t pid = plane->plane_id;
            struct { const char *name; uint64_t val; } pprops[] = {
                { "FB_ID",   plane->fb_id },
                { "CRTC_ID", crtc_id },
                { "SRC_X",   0 },
                { "SRC_Y",   0 },
                { "SRC_W",   (uint64_t)w << 16 },
                { "SRC_H",   (uint64_t)h << 16 },
                { "CRTC_X",  0 },
                { "CRTC_Y",  0 },
                { "CRTC_W",  w },
                { "CRTC_H",  h },
            };
            size_t n;
            for (n = 0; n < sizeof(pprops) / sizeof(pprops[0]); n++) {
                uint32_t prop = find_prop_id(fd, pid, DRM_MODE_OBJECT_PLANE,
                                             pprops[n].name);
                if (!prop) {
                    fprintf(stderr, "failed to set mode: %d-%s\n",
                            ENOENT, strerror(ENOENT));
                    drmModeFreeFB(fb);
                    goto out;
                }
                drmModeAtomicAddProperty(req, pid, prop, pprops[n].val);
            }
            drmModeFreeFB(fb);
        } else {
            fprintf(stderr,
                    "warning: no framebuffer attached, mode set without enabling plane\n");
        }
    } else if (!plane || plane->fb_id == 0) {
        fprintf(stderr,
                "warning: no framebuffer attached, mode set without enabling plane\n");
    }
    /* plane->crtc_id != 0 : 이미 활성이므로 플레인은 그대로 둔다 */

    if (drmModeAtomicCommit(fd, req, DRM_MODE_ATOMIC_ALLOW_MODESET, NULL)) {
        fprintf(stderr, "failed to set mode: %d-%s\n", errno, strerror(errno));
        goto out;
    }

    /* 스크립트가 grep으로 파싱하는 문자열 — 포맷 변경 금지 */
    printf("Display mode is changed to '%s' (%dx%d@%d)\n",
           mode->name, mode->hdisplay, mode->vdisplay, (int)mode->vrefresh);
    ret = 0;

out:
    if (blob_id)
        drmModeDestroyPropertyBlob(fd, blob_id);
    if (req)
        drmModeAtomicFree(req);
    if (plane)
        drmModeFreePlane(plane);
    if (conn)
        drmModeFreeConnector(conn);
    return ret;
}

static void usage(const char *prog)
{
    fprintf(stderr,
            "usage: %s -outputmode <name>   set display mode (atomic commit)\n"
            "       %s -outputmode preferred set EDID preferred mode\n"
            "       %s -showmodes           list CRTCs, connectors and modes\n",
            prog, prog, prog);
}

int main(int argc, char *argv[])
{
    drmModeRes *res;
    const char *mode_name = NULL;
    int showmodes = 0;
    int fd, ret;

    if (argc == 3 && strcmp(argv[1], "-outputmode") == 0) {
        mode_name = argv[2];
    } else if (argc == 2 && strcmp(argv[1], "-showmodes") == 0) {
        showmodes = 1;
    } else {
        usage(argv[0]);
        return 1;
    }

    fd = open(DRM_DEVICE, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "failed to open device %s\n", DRM_DEVICE);
        return 1;
    }

    drmSetClientCap(fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1);
    if (drmSetClientCap(fd, DRM_CLIENT_CAP_ATOMIC, 1)) {
        fprintf(stderr, "no atomic modesetting support: %s\n",
                strerror(errno));
        close(fd);
        return 1;
    }
    /* WRITEBACK_CONNECTORS는 켜지 않는다 — Writeback 커넥터가 리소스에 안 보이게 */

    res = drmModeGetResources(fd);
    if (!res) {
        fprintf(stderr, "failed get connector or crtc\n");
        close(fd);
        return 1;
    }

    if (showmodes)
        ret = do_showmodes(fd, res);
    else
        ret = do_setmode(fd, res, mode_name);

    drmModeFreeResources(res);
    close(fd);
    return ret;
}
