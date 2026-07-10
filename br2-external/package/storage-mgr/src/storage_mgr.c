/* storage_mgr.c — RetroPangUI 저장장치 관리 데몬
 * 외부 저장장치(USB/SD) 감지, ES와 파일 기반 IPC.
 * C99, POSIX, musl 호환. 외부 라이브러리 없음.
 */
#define _POSIX_C_SOURCE 200809L
#define _DEFAULT_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <signal.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/inotify.h>
#include <linux/netlink.h>
#include <poll.h>

#define MAX_DEVICES  16
#define DEVICES_JSON "/tmp/retropangui-storage-devices.json"
#define STORAGE_EVT  "/tmp/retropangui-storage-event"
#define STORAGE_CMD  "/tmp/retropangui-storage-cmd"
#define BOOT_CONF    "/boot/retropangui-boot.conf"

typedef struct {
    char id[64];      /* "INTERNAL" | "DEV UUID=xxxx" */
    char label[80];
    char dev[64];     /* /dev/mmcblk1p1 */
    char part[32];    /* mmcblk1p1 */
    char base[32];    /* mmcblk1 */
    int  size_gb;
    char type[16];    /* "emmc" | "usb" | "block" */
    char uuid[64];
} Device;

static Device              g_dev[MAX_DEVICES];
static int                 g_ndev    = 0;
static char                g_current[64] = "INTERNAL";
static char                g_boot_dev[32] = "";
static volatile sig_atomic_t g_running = 1;

/* ── 유틸 ──────────────────────────────────────────────── */

static void sig_handler(int s) { (void)s; g_running = 0; }

static int read_first_line(const char *path, char *buf, size_t sz)
{
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    int ok = (fgets(buf, (int)sz, f) != NULL);
    fclose(f);
    if (!ok) return -1;
    size_t n = strlen(buf);
    while (n && (buf[n-1] == '\n' || buf[n-1] == '\r')) buf[--n] = '\0';
    return 0;
}

/* ── 부트 디바이스 감지 ────────────────────────────────── */

static void detect_boot_dev(void)
{
    FILE *f = fopen("/proc/mounts", "r");
    if (!f) { strcpy(g_boot_dev, "mmcblk0"); return; }

    char line[256], dev[64], mp[64];
    char found[64] = "";
    int  have_boot = 0;

    while (fgets(line, sizeof(line), f)) {
        if (sscanf(line, "%63s %63s", dev, mp) < 2) continue;
        if (dev[0] != '/') continue;
        if (strcmp(dev, "/dev/root") == 0) continue;

        if (strcmp(mp, "/boot") == 0) {
            strncpy(found, dev, sizeof(found)-1);
            have_boot = 1;
            break;
        }
        if (!have_boot && strcmp(mp, "/") == 0 && found[0] == '\0')
            strncpy(found, dev, sizeof(found)-1);
    }
    fclose(f);

    if (!found[0]) { strcpy(g_boot_dev, "mmcblk0"); return; }

    /* /dev/mmcblk1p1 → basename → strip partition suffix */
    const char *bn = strrchr(found, '/');
    bn = bn ? bn + 1 : found;
    strncpy(g_boot_dev, bn, sizeof(g_boot_dev)-1);
    size_t n = strlen(g_boot_dev);
    while (n && g_boot_dev[n-1] >= '0' && g_boot_dev[n-1] <= '9') g_boot_dev[--n] = '\0';
    if (n && g_boot_dev[n-1] == 'p') g_boot_dev[--n] = '\0';

    fprintf(stderr, "[storage-mgr] boot device: %s\n", g_boot_dev);
}

/* ── UUID 조회 ─────────────────────────────────────────── */

static void lookup_uuid(const char *partname, char *uuid, size_t sz)
{
    uuid[0] = '\0';
    DIR *d = opendir("/dev/disk/by-uuid");
    if (!d) return;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (ent->d_name[0] == '.') continue;
        char lp[128], tgt[128];
        snprintf(lp, sizeof(lp), "/dev/disk/by-uuid/%s", ent->d_name);
        ssize_t len = readlink(lp, tgt, sizeof(tgt)-1);
        if (len <= 0) continue;
        tgt[len] = '\0';
        const char *t = strrchr(tgt, '/');
        t = t ? t+1 : tgt;
        if (strcmp(t, partname) == 0) {
            strncpy(uuid, ent->d_name, sz-1);
            break;
        }
    }
    closedir(d);
}

/* ── 장치 항목 빌드 ────────────────────────────────────── */

static void build_device(Device *d, const char *base, const char *part)
{
    memset(d, 0, sizeof(*d));
    strncpy(d->base, base, sizeof(d->base)-1);
    strncpy(d->part, part, sizeof(d->part)-1);
    snprintf(d->dev, sizeof(d->dev), "/dev/%s", part);

    /* 크기: /sys/block/{base}/{part}/size (512바이트 섹터) */
    char path[128];
    snprintf(path, sizeof(path), "/sys/block/%s/%s/size", base, part);
    char buf[32];
    if (read_first_line(path, buf, sizeof(buf)) == 0) {
        unsigned long long sec = strtoull(buf, NULL, 10);
        d->size_gb = (int)(sec / 2ULL / 1024ULL / 1024ULL);
    }

    lookup_uuid(part, d->uuid, sizeof(d->uuid));

    if (d->uuid[0])
        snprintf(d->id, sizeof(d->id), "DEV UUID=%s", d->uuid);
    else
        snprintf(d->id, sizeof(d->id), "DEV %s", part);

    if (strncmp(base, "mmcblk", 6) == 0)
        strcpy(d->type, "emmc");
    else if (strncmp(base, "sd", 2) == 0)
        strcpy(d->type, "usb");
    else
        strcpy(d->type, "block");

    const char *tlabel = strcmp(d->type, "emmc") == 0 ? "내장 eMMC" : "USB";
    snprintf(d->label, sizeof(d->label), "%s (%dGB)", tlabel, d->size_gb);
}

/* ── 전체 장치 스캔 ────────────────────────────────────── */

static void scan_devices(void)
{
    g_ndev = 0;

    /* INTERNAL: 부트 디바이스의 p3(share) 파티션을 첫 번째 항목으로 추가 */
    if (g_boot_dev[0]) {
        char partname[64];
        snprintf(partname, sizeof(partname), "%sp3", g_boot_dev);
        char pcheck[192];
        snprintf(pcheck, sizeof(pcheck), "/sys/block/%s/%s/partition",
                 g_boot_dev, partname);
        if (access(pcheck, F_OK) == 0) {
            build_device(&g_dev[0], g_boot_dev, partname);
            strncpy(g_dev[0].id, "INTERNAL", sizeof(g_dev[0].id)-1);
            fprintf(stderr, "[storage-mgr] internal: %s %dGB\n",
                    g_dev[0].dev, g_dev[0].size_gb);
            g_ndev = 1;
        }
    }

    DIR *bd = opendir("/sys/block");
    if (!bd) return;

    struct dirent *be;
    while ((be = readdir(bd)) != NULL && g_ndev < MAX_DEVICES) {
        const char *base = be->d_name;
        if (base[0] == '.') continue;
        if (strncmp(base, "loop", 4) == 0) continue;
        if (strncmp(base, "ram",  3) == 0) continue;
        if (g_boot_dev[0] && strncmp(base, g_boot_dev, strlen(g_boot_dev)) == 0) continue;

        char bpath[128];
        snprintf(bpath, sizeof(bpath), "/sys/block/%s", base);

        DIR *pd = opendir(bpath);
        if (!pd) continue;

        struct dirent *pe;
        while ((pe = readdir(pd)) != NULL && g_ndev < MAX_DEVICES) {
            if (pe->d_name[0] == '.') continue;
            if (strncmp(pe->d_name, base, strlen(base)) != 0) continue;
            if (strlen(pe->d_name) <= strlen(base)) continue;

            /* /sys/block/{base}/{part}/partition 존재 확인 */
            char pcheck[192];
            snprintf(pcheck, sizeof(pcheck), "%s/%s/partition", bpath, pe->d_name);
            if (access(pcheck, F_OK) != 0) continue;

            build_device(&g_dev[g_ndev], base, pe->d_name);
            fprintf(stderr, "[storage-mgr] found: %s %s %dGB uuid=%s\n",
                    g_dev[g_ndev].dev, g_dev[g_ndev].type,
                    g_dev[g_ndev].size_gb, g_dev[g_ndev].uuid);
            g_ndev++;
        }
        closedir(pd);
    }
    closedir(bd);
}

/* ── boot.conf 읽기 ────────────────────────────────────── */

static void read_boot_conf(void)
{
    FILE *f = fopen(BOOT_CONF, "r");
    if (!f) return;
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "sharedevice=", 12) == 0) {
            strncpy(g_current, line + 12, sizeof(g_current)-1);
            size_t n = strlen(g_current);
            while (n && (g_current[n-1] == '\n' || g_current[n-1] == '\r')) g_current[--n] = '\0';
            break;
        }
    }
    fclose(f);
}

/* ── boot.conf 쓰기 (sharedevice= 줄만 교체) ─────────── */

static void write_boot_conf(const char *sharedevice)
{
    char lines[64][256];
    int  nlines = 0, replaced = 0;

    FILE *fr = fopen(BOOT_CONF, "r");
    if (fr) {
        while (nlines < 64 && fgets(lines[nlines], sizeof(lines[nlines]), fr))
            nlines++;
        fclose(fr);
    }
    for (int i = 0; i < nlines; i++) {
        if (strncmp(lines[i], "sharedevice=", 12) == 0) {
            snprintf(lines[i], sizeof(lines[i]), "sharedevice=%s\n", sharedevice);
            replaced = 1;
        }
    }

    FILE *fw = fopen(BOOT_CONF, "w");
    if (!fw) { perror("[storage-mgr] write_boot_conf"); return; }
    for (int i = 0; i < nlines; i++) fputs(lines[i], fw);
    if (!replaced) fprintf(fw, "sharedevice=%s\n", sharedevice);
    fclose(fw);

    strncpy(g_current, sharedevice, sizeof(g_current)-1);
    fprintf(stderr, "[storage-mgr] sharedevice → %s\n", sharedevice);
}

/* ── devices.json 출력 (원자적 rename) ──────────────────── */

static void write_devices_json(void)
{
    char tmp[80];
    snprintf(tmp, sizeof(tmp), "%s.tmp", DEVICES_JSON);
    FILE *f = fopen(tmp, "w");
    if (!f) { perror("[storage-mgr] write_devices_json"); return; }

    fprintf(f, "{\n  \"current\": \"%s\",\n  \"devices\": [\n", g_current);
    for (int i = 0; i < g_ndev; i++) {
        fprintf(f,
            "    {\n"
            "      \"id\": \"%s\",\n"
            "      \"label\": \"%s\",\n"
            "      \"dev\": \"%s\",\n"
            "      \"size_gb\": %d,\n"
            "      \"type\": \"%s\",\n"
            "      \"uuid\": \"%s\"\n"
            "    }%s\n",
            g_dev[i].id, g_dev[i].label, g_dev[i].dev,
            g_dev[i].size_gb, g_dev[i].type, g_dev[i].uuid,
            i < g_ndev - 1 ? "," : "");
    }
    fprintf(f, "  ]\n}\n");
    fclose(f);
    rename(tmp, DEVICES_JSON);
}

/* ── netlink uevent 파싱 ────────────────────────────────── */
/* 커널이 보내는 원시 uevent: 첫 토큰 "ACTION@/path\0" 후 "KEY=VALUE\0" 연속 */

static void parse_uevent(const char *buf, ssize_t len)
{
    char action[32] = "", devname[64] = "", devtype[32] = "", subsys[32] = "";

    /* 헤더 토큰(ACTION@PATH) 건너뜀 */
    const char *p = buf, *end = buf + len;
    while (p < end && *p) p++;
    if (p < end) p++;  /* null 건너뜀 */

    while (p < end) {
        const char *kv = p;
        while (p < end && *p) p++;
        if (p < end) p++;

        if      (strncmp(kv, "ACTION=",    7) == 0) strncpy(action,  kv+7,  sizeof(action)-1);
        else if (strncmp(kv, "DEVNAME=",   8) == 0) strncpy(devname, kv+8,  sizeof(devname)-1);
        else if (strncmp(kv, "DEVTYPE=",   8) == 0) strncpy(devtype, kv+8,  sizeof(devtype)-1);
        else if (strncmp(kv, "SUBSYSTEM=", 10)== 0) strncpy(subsys,  kv+10, sizeof(subsys)-1);
    }

    if (strcmp(subsys,  "block")     != 0) return;
    if (strcmp(devtype, "partition") != 0) return;
    if (!action[0] || !devname[0])         return;
    /* 부트 디바이스 파티션 제외 */
    if (g_boot_dev[0] && strncmp(devname, g_boot_dev, strlen(g_boot_dev)) == 0) return;

    if (strcmp(action, "add") == 0) {
        if (g_ndev >= MAX_DEVICES) return;

        /* base: mmcblk1p1 → mmcblk1 */
        char base[32];
        strncpy(base, devname, sizeof(base)-1);
        size_t n = strlen(base);
        while (n && base[n-1] >= '0' && base[n-1] <= '9') base[--n] = '\0';
        if (n && base[n-1] == 'p') base[--n] = '\0';

        /* by-uuid 심볼릭 링크가 생성될 때까지 짧게 대기 */
        usleep(500000);

        build_device(&g_dev[g_ndev], base, devname);
        fprintf(stderr, "[storage-mgr] add: %s\n", g_dev[g_ndev].dev);

        FILE *ef = fopen(STORAGE_EVT, "a");
        if (ef) {
            fprintf(ef, "{\"action\":\"added\",\"id\":\"%s\",\"label\":\"%s\",\"dev\":\"/dev/%s\"}\n",
                    g_dev[g_ndev].id, g_dev[g_ndev].label, devname);
            fclose(ef);
        }
        g_ndev++;
        write_devices_json();

    } else if (strcmp(action, "remove") == 0) {
        char devpath[72];
        snprintf(devpath, sizeof(devpath), "/dev/%s", devname);
        for (int i = 0; i < g_ndev; i++) {
            if (strcmp(g_dev[i].dev, devpath) == 0) {
                fprintf(stderr, "[storage-mgr] remove: %s\n", devpath);
                FILE *ef = fopen(STORAGE_EVT, "a");
                if (ef) {
                    fprintf(ef, "{\"action\":\"removed\",\"dev\":\"%s\"}\n", devpath);
                    fclose(ef);
                }
                memmove(&g_dev[i], &g_dev[i+1], sizeof(Device) * (size_t)(g_ndev - i - 1));
                g_ndev--;
                write_devices_json();
                break;
            }
        }
    }
}

/* ── storage-cmd 처리 ──────────────────────────────────── */

static void handle_storage_cmd(void)
{
    FILE *f = fopen(STORAGE_CMD, "r");
    if (!f) return;
    char line[128] = "";
    fgets(line, sizeof(line), f);
    fclose(f);

    size_t n = strlen(line);
    while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = '\0';
    if (!n) { unlink(STORAGE_CMD); return; }

    fprintf(stderr, "[storage-mgr] cmd: %s\n", line);

    if (strcmp(line, "SELECT INTERNAL") == 0) {
        write_boot_conf("INTERNAL");
    } else if (strncmp(line, "SELECT DEV UUID=", 16) == 0) {
        /* "SELECT DEV UUID=xxxx" → boot.conf: "DEV UUID=xxxx" */
        write_boot_conf(line + 7);
    } else {
        fprintf(stderr, "[storage-mgr] unknown cmd ignored\n");
    }

    unlink(STORAGE_CMD);
    write_devices_json();
}

/* ── main ──────────────────────────────────────────────── */

int main(void)
{
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = sig_handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT,  &sa, NULL);

    detect_boot_dev();
    read_boot_conf();
    scan_devices();
    write_devices_json();

    /* 시작 시 대기 중인 cmd 처리 */
    if (access(STORAGE_CMD, F_OK) == 0)
        handle_storage_cmd();

    /* netlink 소켓 */
    int nl_fd = socket(AF_NETLINK, SOCK_RAW | SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
    if (nl_fd < 0) { perror("[storage-mgr] netlink socket"); return 1; }

    struct sockaddr_nl nl_addr;
    memset(&nl_addr, 0, sizeof(nl_addr));
    nl_addr.nl_family = AF_NETLINK;
    nl_addr.nl_pid    = (unsigned int)getpid();
    nl_addr.nl_groups = 1;  /* UEVENT 멀티캐스트 그룹 */
    if (bind(nl_fd, (struct sockaddr *)&nl_addr, sizeof(nl_addr)) < 0) {
        perror("[storage-mgr] netlink bind"); close(nl_fd); return 1;
    }

    /* inotify: /tmp 에서 storage-cmd 생성 감시 */
    int in_fd = inotify_init1(IN_CLOEXEC);
    if (in_fd < 0) { perror("[storage-mgr] inotify_init"); close(nl_fd); return 1; }
    if (inotify_add_watch(in_fd, "/tmp", IN_CREATE | IN_MOVED_TO) < 0) {
        perror("[storage-mgr] inotify_add_watch");
        close(in_fd); close(nl_fd); return 1;
    }

    fprintf(stderr, "[storage-mgr] started, %d device(s)\n", g_ndev);

    struct pollfd fds[2] = {
        { .fd = nl_fd, .events = POLLIN },
        { .fd = in_fd, .events = POLLIN },
    };

    while (g_running) {
        int r = poll(fds, 2, 5000);
        if (r < 0) {
            if (errno == EINTR) continue;
            perror("[storage-mgr] poll");
            break;
        }
        if (r == 0) {
            /* 5초 주기 갱신 */
            write_devices_json();
            continue;
        }

        if (fds[0].revents & POLLIN) {
            char buf[4096];
            ssize_t len = recv(nl_fd, buf, sizeof(buf)-1, MSG_DONTWAIT);
            if (len > 0) { buf[len] = '\0'; parse_uevent(buf, len); }
        }

        if (fds[1].revents & POLLIN) {
            char ibuf[sizeof(struct inotify_event) + NAME_MAX + 1];
            ssize_t len = read(in_fd, ibuf, sizeof(ibuf));
            if (len >= (ssize_t)sizeof(struct inotify_event)) {
                struct inotify_event *ev = (struct inotify_event *)ibuf;
                if (ev->len && strcmp(ev->name, "retropangui-storage-cmd") == 0)
                    handle_storage_cmd();
            }
        }
    }

    fprintf(stderr, "[storage-mgr] exit\n");
    unlink(DEVICES_JSON);
    unlink(STORAGE_EVT);
    close(in_fd);
    close(nl_fd);
    return 0;
}
