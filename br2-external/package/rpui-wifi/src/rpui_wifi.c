/* rpui_wifi.c — RetroPangUI WiFi 관리 데몬 + CLI
 * USB WiFi 동글 핫플러그 감지, wpa_supplicant/udhcpc 제어, ES와 파일 기반 IPC.
 * C99, POSIX, musl 호환. wpa_supplicant/wpa_cli/udhcpc는 서브프로세스로 실행
 * (raw wpa_supplicant 제어 소켓 프로토콜을 직접 구현하지 않고 기존 도구를 그대로 활용).
 *
 * 인자 없이 실행 = 데몬 모드 (상시 기동, init 스크립트가 기동).
 * 인자 있이 실행 = CLI 모드 (start/scanlist/list/enable/disable) — storage-mgr와
 * 동일하게, 실제 프로세스 기동/종료는 데몬에게 CMD 파일로 위임해 단일 관리 지점 유지.
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
#include <ctype.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/inotify.h>
#include <linux/netlink.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <poll.h>

#define MAX_DONGLES     8
#define STATUS_JSON     "/tmp/retropangui-wifi-status.json"
#define WIFI_CMD        "/tmp/retropangui-wifi-cmd"
#define WIFI_CMD_NAME   "retropangui-wifi-cmd"
#define WPA_CONF_TMP    "/tmp/rpui-wifi-%s.conf"
#define WPA_PID_TMP     "/run/rpui-wpa_supplicant-%s.pid"
#define UDHCPC_PID_TMP  "/run/rpui-udhcpc-%s.pid"

typedef struct {
    char ifname[16];
} Dongle;

static Dongle              g_dongle[MAX_DONGLES];
static int                 g_ndongle = 0;
static char                g_active_if[16] = "";   /* 현재 wpa_supplicant 기동 중인 인터페이스 */
static int                 g_connected = 0;
static char                g_ssid[64] = "";
static char                g_ip[16] = "";
static volatile sig_atomic_t g_running = 1;

/* ── 유틸 ──────────────────────────────────────────────── */

static void sig_handler(int s) { (void)s; g_running = 0; }

/* RETROPANGUI_SHARE → /share → ~/share 순서로 탐색 (MusicManager.cpp/rpui-launcher.py와 동일 규칙) */
static void get_share_root(char *buf, size_t sz)
{
    const char *env = getenv("RETROPANGUI_SHARE");
    if (env && env[0] != '\0') { snprintf(buf, sz, "%s", env); return; }

    if (access("/share", F_OK) == 0) { snprintf(buf, sz, "/share"); return; }

    const char *home = getenv("HOME");
    snprintf(buf, sz, "%s/share", home ? home : "/root");
}

static void wifi_conf_path(char *buf, size_t sz)
{
    char share[192];
    get_share_root(share, sizeof(share));
    snprintf(buf, sz, "%s/system/wifi.conf", share);
}

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

/* ── wifi.conf (ssid=/psk= 두 줄, share 파티션에 영속) ──── */

static int read_wifi_conf(char *ssid, size_t ssidsz, char *psk, size_t psksz)
{
    char path[256];
    wifi_conf_path(path, sizeof(path));

    FILE *f = fopen(path, "r");
    if (!f) return -1;

    ssid[0] = '\0';
    psk[0]  = '\0';
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        size_t n = strlen(line);
        while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = '\0';
        if (strncmp(line, "ssid=", 5) == 0)
            strncpy(ssid, line + 5, ssidsz - 1);
        else if (strncmp(line, "psk=", 4) == 0)
            strncpy(psk, line + 4, psksz - 1);
    }
    fclose(f);
    return ssid[0] ? 0 : -1;
}

static int write_wifi_conf(const char *ssid, const char *psk)
{
    char path[256];
    wifi_conf_path(path, sizeof(path));

    char dir[256];
    snprintf(dir, sizeof(dir), "%s", path);
    char *slash = strrchr(dir, '/');
    if (slash) { *slash = '\0'; mkdir(dir, 0755); /* 이미 있으면 무시 */ }

    FILE *f = fopen(path, "w");
    if (!f) { perror("[rpui-wifi] write_wifi_conf"); return -1; }
    fprintf(f, "ssid=%s\npsk=%s\n", ssid, psk);
    fclose(f);
    chmod(path, 0600); /* psk 평문 저장 — 소유자만 읽기 */
    return 0;
}

/* ── wpa_supplicant.conf용 문자열 이스케이프 ─────────────
 * ssid/psk는 CLI(궁극적으로 ES 메뉴 입력)에서 오므로 quoted 문자열 안에
 * 그대로 넣으면 안 됨 — " 와 \ 를 백슬래시 이스케이프 */
static void escape_wpa_string(const char *in, char *out, size_t outsz)
{
    size_t o = 0;
    for (size_t i = 0; in[i] != '\0' && o + 2 < outsz; i++) {
        if (in[i] == '"' || in[i] == '\\')
            out[o++] = '\\';
        out[o++] = in[i];
    }
    out[o] = '\0';
}

/* ── 무선 인터페이스 판별 ─────────────────────────────── */

static int is_wireless_if(const char *ifname)
{
    char path[128];
    snprintf(path, sizeof(path), "/sys/class/net/%s/wireless", ifname);
    if (access(path, F_OK) == 0) return 1;
    snprintf(path, sizeof(path), "/sys/class/net/%s/phy80211", ifname);
    return access(path, F_OK) == 0;
}

/* ── 서브프로세스 실행 ────────────────────────────────────
 * argv 배열로 직접 execvp — CLI에서 받은 SSID/PW를 쉘 인용 없이 그대로 넘겨
 * 셸 인젝션 위험을 원천 차단. quiet=1이면 stdout/stderr를 /dev/null로 보냄. */
static pid_t spawn_argv(char *const argv[], int quiet)
{
    pid_t pid = fork();
    if (pid < 0) { perror("[rpui-wifi] fork"); return -1; }
    if (pid == 0) {
        if (quiet) {
            int devnull = open("/dev/null", O_RDWR);
            if (devnull >= 0) {
                dup2(devnull, STDOUT_FILENO);
                dup2(devnull, STDERR_FILENO);
                close(devnull);
            }
        }
        execvp(argv[0], argv);
        _exit(127); /* execvp 실패 */
    }
    return pid;
}

/* 짧게 끝나는 명령을 실행하고 종료까지 대기 (wpa_cli scan 트리거 등) */
static void spawn_and_wait(char *const argv[])
{
    pid_t pid = spawn_argv(argv, 1);
    if (pid > 0) waitpid(pid, NULL, 0);
}

static void kill_pidfile(const char *pidfile)
{
    char buf[32];
    if (read_first_line(pidfile, buf, sizeof(buf)) == 0) {
        pid_t pid = (pid_t)atoi(buf);
        if (pid > 0) kill(pid, SIGTERM);
    }
    unlink(pidfile);
}

/* ── wpa_supplicant / udhcpc 기동·종료 ───────────────── */

static void stop_wifi_link(const char *ifname)
{
    char wpapid[64], dhcppid[64];
    snprintf(wpapid,  sizeof(wpapid),  WPA_PID_TMP,  ifname);
    snprintf(dhcppid, sizeof(dhcppid), UDHCPC_PID_TMP, ifname);
    kill_pidfile(dhcppid);
    kill_pidfile(wpapid);

    if (strcmp(g_active_if, ifname) == 0) {
        g_active_if[0] = '\0';
        g_connected = 0;
        g_ssid[0] = '\0';
        g_ip[0] = '\0';
    }
}

static int start_wifi_link(const char *ifname, const char *ssid, const char *psk)
{
    /* 기존에 이 인터페이스에서 돌던 인스턴스가 있으면 먼저 정리 */
    stop_wifi_link(ifname);

    char essid[80], epsk[136];
    escape_wpa_string(ssid, essid, sizeof(essid));
    escape_wpa_string(psk,  epsk,  sizeof(epsk));

    char conf_path[64];
    snprintf(conf_path, sizeof(conf_path), WPA_CONF_TMP, ifname);
    FILE *cf = fopen(conf_path, "w");
    if (!cf) { perror("[rpui-wifi] wpa conf"); return -1; }
    fprintf(cf,
        "ctrl_interface=/var/run/wpa_supplicant\n"
        "update_config=0\n"
        "network={\n"
        "    ssid=\"%s\"\n"
        "    psk=\"%s\"\n"
        "}\n",
        essid, epsk);
    fclose(cf);
    chmod(conf_path, 0600);

    char wpapid[64];
    snprintf(wpapid, sizeof(wpapid), WPA_PID_TMP, ifname);

    /* -B: 데몬화(자체 fork), -P: pidfile — 우리가 fork/wait 관리할 필요 없음 */
    char *const wpa_argv[] = {
        "wpa_supplicant", "-B", "-i", (char *)ifname,
        "-c", conf_path, "-P", wpapid, NULL
    };
    pid_t r = spawn_argv(wpa_argv, 1);
    if (r < 0) return -1;
    waitpid(r, NULL, 0); /* -B로 자체 데몬화하는 부모 프로세스만 기다림 (짧게 끝남) */

    char dhcppid[64];
    snprintf(dhcppid, sizeof(dhcppid), UDHCPC_PID_TMP, ifname);
    char *const dhcp_argv[] = {
        "udhcpc", "-i", (char *)ifname, "-b", "-p", dhcppid, NULL
    };
    spawn_argv(dhcp_argv, 1); /* 백그라운드로 넘어감(-b), 대기 불필요 */

    strncpy(g_active_if, ifname, sizeof(g_active_if) - 1);
    return 0;
}

/* 저장된 프로필이 없을 때도 스캔은 가능해야 하므로, network 블록 없이
 * wpa_supplicant만 붙여둔다 (연결은 안 하고 wpa_cli scan만 가능한 상태) */
static int start_scan_only_link(const char *ifname)
{
    stop_wifi_link(ifname);

    char conf_path[64];
    snprintf(conf_path, sizeof(conf_path), WPA_CONF_TMP, ifname);
    FILE *cf = fopen(conf_path, "w");
    if (!cf) { perror("[rpui-wifi] wpa conf (scan-only)"); return -1; }
    fprintf(cf, "ctrl_interface=/var/run/wpa_supplicant\nupdate_config=0\n");
    fclose(cf);
    chmod(conf_path, 0600);

    char wpapid[64];
    snprintf(wpapid, sizeof(wpapid), WPA_PID_TMP, ifname);

    char *const wpa_argv[] = {
        "wpa_supplicant", "-B", "-i", (char *)ifname,
        "-c", conf_path, "-P", wpapid, NULL
    };
    pid_t r = spawn_argv(wpa_argv, 1);
    if (r < 0) return -1;
    waitpid(r, NULL, 0);

    strncpy(g_active_if, ifname, sizeof(g_active_if) - 1);
    return 0;
}

/* wpa_cli status로 연결 상태/SSID 조회 (raw ctrl 소켓 프로토콜 대신 기존 도구 재사용) */
static void poll_wifi_status(void)
{
    if (!g_active_if[0]) return;

    char cmd[64];
    snprintf(cmd, sizeof(cmd), "wpa_cli -i %s status 2>/dev/null", g_active_if);
    FILE *p = popen(cmd, "r");
    if (!p) return;

    int completed = 0;
    char ssid[64] = "";
    char line[128];
    while (fgets(line, sizeof(line), p)) {
        size_t n = strlen(line);
        while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = '\0';
        if (strncmp(line, "wpa_state=COMPLETED", 20) == 0)
            completed = 1;
        else if (strncmp(line, "ssid=", 5) == 0)
            strncpy(ssid, line + 5, sizeof(ssid) - 1);
    }
    pclose(p);

    g_connected = completed;
    if (completed) {
        strncpy(g_ssid, ssid, sizeof(g_ssid) - 1);

        struct ifaddrs *ifa, *cur;
        g_ip[0] = '\0';
        if (getifaddrs(&ifa) == 0) {
            for (cur = ifa; cur; cur = cur->ifa_next) {
                if (!cur->ifa_addr || cur->ifa_addr->sa_family != AF_INET) continue;
                if (strcmp(cur->ifa_name, g_active_if) != 0) continue;
                struct sockaddr_in *sin = (struct sockaddr_in *)(void *)cur->ifa_addr;
                inet_ntop(AF_INET, &sin->sin_addr, g_ip, sizeof(g_ip));
                break;
            }
            freeifaddrs(ifa);
        }
    } else {
        g_ssid[0] = '\0';
        g_ip[0] = '\0';
    }
}

/* ── status.json 출력 (원자적 rename) ─────────────────── */

static void write_status_json(void)
{
    char tmp[80];
    snprintf(tmp, sizeof(tmp), "%s.tmp", STATUS_JSON);
    FILE *f = fopen(tmp, "w");
    if (!f) { perror("[rpui-wifi] write_status_json"); return; }

    fprintf(f, "{\n  \"dongles\": [\n");
    for (int i = 0; i < g_ndongle; i++)
        fprintf(f, "    \"%s\"%s\n", g_dongle[i].ifname, i < g_ndongle - 1 ? "," : "");
    fprintf(f,
        "  ],\n"
        "  \"connected\": %s,\n"
        "  \"ssid\": \"%s\",\n"
        "  \"ip\": \"%s\",\n"
        "  \"interface\": \"%s\"\n"
        "}\n",
        g_connected ? "true" : "false", g_ssid, g_ip, g_active_if);
    fclose(f);
    rename(tmp, STATUS_JSON);
}

/* ── 저장된 프로필로 자동 재연결 시도 ───────────────────
 * 동글이 1개면 그 인터페이스로, 여러 개면 첫 번째 감지된 동글로 시도.
 * (복수 동글 선택 UI는 ES 메뉴 쪽 작업 — 데몬은 일단 첫 번째로 시도) */
static void try_autoconnect(const char *ifname)
{
    char ssid[64], psk[128];
    if (read_wifi_conf(ssid, sizeof(ssid), psk, sizeof(psk)) != 0) {
        /* 저장된 프로필이 없어도 스캔(SSID 목록 조회)은 가능해야 함 */
        fprintf(stderr, "[rpui-wifi] 저장된 프로필 없음 — %s에 스캔 전용 wpa_supplicant 기동\n", ifname);
        start_scan_only_link(ifname);
        return;
    }
    fprintf(stderr, "[rpui-wifi] autoconnect: %s → %s\n", ifname, ssid);
    start_wifi_link(ifname, ssid, psk);
}

/* ── netlink uevent 파싱 (net subsystem) ────────────────
 * storage-mgr는 SUBSYSTEM=block을 보지만 여기서는 net을 본다.
 * 커널 uevent 포맷은 동일: "ACTION@/path\0KEY=VALUE\0..." 연속 */

static void parse_uevent(const char *buf, ssize_t len)
{
    char action[32] = "", ifname[32] = "", subsys[32] = "";

    const char *p = buf, *end = buf + len;
    while (p < end && *p) p++;
    if (p < end) p++;

    while (p < end) {
        const char *kv = p;
        while (p < end && *p) p++;
        if (p < end) p++;

        if      (strncmp(kv, "ACTION=",    7) == 0) strncpy(action, kv+7, sizeof(action)-1);
        else if (strncmp(kv, "INTERFACE=", 10)== 0) strncpy(ifname, kv+10, sizeof(ifname)-1);
        else if (strncmp(kv, "SUBSYSTEM=", 10)== 0) strncpy(subsys, kv+10, sizeof(subsys)-1);
    }

    if (strcmp(subsys, "net") != 0) return;
    if (!action[0] || !ifname[0]) return;

    if (strcmp(action, "add") == 0) {
        /* sysfs 노드가 완전히 준비될 때까지 짧게 대기 */
        usleep(300000);
        if (!is_wireless_if(ifname)) return;
        if (g_ndongle >= MAX_DONGLES) return;

        for (int i = 0; i < g_ndongle; i++)
            if (strcmp(g_dongle[i].ifname, ifname) == 0) return; /* 중복 */

        strncpy(g_dongle[g_ndongle].ifname, ifname, sizeof(g_dongle[g_ndongle].ifname)-1);
        g_ndongle++;
        fprintf(stderr, "[rpui-wifi] dongle added: %s\n", ifname);

        if (!g_active_if[0])
            try_autoconnect(ifname);

        write_status_json();

    } else if (strcmp(action, "remove") == 0) {
        for (int i = 0; i < g_ndongle; i++) {
            if (strcmp(g_dongle[i].ifname, ifname) == 0) {
                fprintf(stderr, "[rpui-wifi] dongle removed: %s\n", ifname);
                stop_wifi_link(ifname);
                memmove(&g_dongle[i], &g_dongle[i+1],
                        sizeof(Dongle) * (size_t)(g_ndongle - i - 1));
                g_ndongle--;
                write_status_json();
                break;
            }
        }
    }
}

/* ── CMD 파일 처리 (CLI → 데몬) ──────────────────────────
 * 첫 줄: 명령. ENABLE은 2~3번째 줄에 ssid/psk가 더 옴. */

static void handle_wifi_cmd(void)
{
    FILE *f = fopen(WIFI_CMD, "r");
    if (!f) return;

    char cmd[32] = "", ssid[64] = "", psk[128] = "";
    char line[256];
    int lineno = 0;
    while (fgets(line, sizeof(line), f)) {
        size_t n = strlen(line);
        while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = '\0';
        if (lineno == 0) strncpy(cmd, line, sizeof(cmd)-1);
        else if (lineno == 1) strncpy(ssid, line, sizeof(ssid)-1);
        else if (lineno == 2) strncpy(psk, line, sizeof(psk)-1);
        lineno++;
    }
    fclose(f);
    unlink(WIFI_CMD);

    if (!cmd[0]) return;
    fprintf(stderr, "[rpui-wifi] cmd: %s\n", cmd);

    if (strcmp(cmd, "START") == 0) {
        if (g_ndongle > 0) try_autoconnect(g_dongle[0].ifname);
    } else if (strcmp(cmd, "ENABLE") == 0) {
        if (ssid[0]) write_wifi_conf(ssid, psk);
        if (g_ndongle > 0) start_wifi_link(g_dongle[0].ifname, ssid, psk);
        else fprintf(stderr, "[rpui-wifi] enable 요청됐으나 동글 없음 — 저장만 함\n");
    } else if (strcmp(cmd, "DISABLE") == 0) {
        if (g_active_if[0]) stop_wifi_link(g_active_if);
    } else {
        fprintf(stderr, "[rpui-wifi] unknown cmd ignored\n");
    }

    write_status_json();
}

/* ── CLI 모드 ─────────────────────────────────────────── */

static int cli_write_cmd(const char *cmd, const char *ssid, const char *psk)
{
    FILE *f = fopen(WIFI_CMD, "w");
    if (!f) { perror("[rpui-wifi] cli"); return 1; }
    fprintf(f, "%s\n", cmd);
    if (ssid) fprintf(f, "%s\n%s\n", ssid, psk ? psk : "");
    fclose(f);
    return 0;
}

static int cli_list(void)
{
    char ssid[64] = "", psk[128] = "";
    int has = (read_wifi_conf(ssid, sizeof(ssid), psk, sizeof(psk)) == 0);
    printf("{\n  \"saved\": %s", has ? "true" : "false");
    if (has) printf(",\n  \"ssid\": \"%s\"", ssid);
    printf("\n}\n");
    return 0;
}

/* 이미 활성 인터페이스가 있으면 그걸로, 없으면 감지된 첫 동글로 스캔용 wpa_supplicant를
 * 잠깐 붙여서 스캔 (네트워크 프로필 없이 -B로 기동, scan만 목적) */
static int cli_scanlist(void)
{
    char ifname[16] = "";

    /* 실행 중인 데몬의 status.json에서 동글/활성 인터페이스 확인 */
    FILE *sf = fopen(STATUS_JSON, "r");
    if (sf) {
        char line[128];
        while (fgets(line, sizeof(line), sf)) {
            char *p = strstr(line, "\"interface\": \"");
            if (p) {
                p += strlen("\"interface\": \"");
                char *end = strchr(p, '"');
                if (end) { *end = '\0'; strncpy(ifname, p, sizeof(ifname)-1); }
            }
        }
        fclose(sf);
    }

    if (!ifname[0]) {
        fprintf(stderr, "[rpui-wifi] scanlist: 활성 인터페이스 없음 (동글 미감지 또는 wifi 비활성)\n");
        printf("{\"networks\": []}\n");
        return 1;
    }

    char *const scan_argv[] = { "wpa_cli", "-i", ifname, "scan", NULL };
    spawn_and_wait(scan_argv);
    sleep(2); /* 스캔 완료 대기 */

    char cmd[64];
    snprintf(cmd, sizeof(cmd), "wpa_cli -i %s scan_results 2>/dev/null", ifname);
    FILE *p = popen(cmd, "r");
    if (!p) { printf("{\"networks\": []}\n"); return 1; }

    printf("{\n  \"networks\": [\n");
    char line[256];
    int first = 1, header_skipped = 0;
    while (fgets(line, sizeof(line), p)) {
        if (!header_skipped) { header_skipped = 1; continue; } /* "bssid / frequency / ..." 헤더 스킵 */
        /* wpa_cli scan_results 컬럼: bssid  freq  signal  flags  ssid (탭 구분) */
        char *ssid_col = strrchr(line, '\t');
        if (!ssid_col) continue;
        ssid_col++;
        size_t n = strlen(ssid_col);
        while (n && (ssid_col[n-1] == '\n' || ssid_col[n-1] == '\r')) ssid_col[--n] = '\0';
        if (!n) continue;

        if (!first) printf(",\n");
        printf("    \"%s\"", ssid_col);
        first = 0;
    }
    printf("\n  ]\n}\n");
    pclose(p);
    return 0;
}

static int run_cli(int argc, char **argv)
{
    const char *sub = argv[1];

    if (strcmp(sub, "start") == 0) {
        return cli_write_cmd("START", NULL, NULL);
    } else if (strcmp(sub, "disable") == 0) {
        return cli_write_cmd("DISABLE", NULL, NULL);
    } else if (strcmp(sub, "list") == 0) {
        return cli_list();
    } else if (strcmp(sub, "scanlist") == 0) {
        return cli_scanlist();
    } else if (strcmp(sub, "enable") == 0) {
        if (argc < 4) {
            fprintf(stderr, "Usage: rpui-wifi enable <SSID> <passkey>\n");
            return 1;
        }
        return cli_write_cmd("ENABLE", argv[2], argv[3]);
    }

    fprintf(stderr,
        "Usage: rpui-wifi {start|scanlist|list|enable <SSID> <passkey>|disable}\n");
    return 1;
}

/* ── 데몬 모드 ────────────────────────────────────────── */

static int run_daemon(void)
{
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = sig_handler;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT,  &sa, NULL);

    /* 기동 시 이미 꽂혀있는 동글 스캔 (/sys/class/net 순회) */
    DIR *d = opendir("/sys/class/net");
    if (d) {
        struct dirent *e;
        while ((e = readdir(d)) != NULL && g_ndongle < MAX_DONGLES) {
            if (e->d_name[0] == '.') continue;
            if (!is_wireless_if(e->d_name)) continue;
            strncpy(g_dongle[g_ndongle].ifname, e->d_name,
                    sizeof(g_dongle[g_ndongle].ifname) - 1);
            g_ndongle++;
            fprintf(stderr, "[rpui-wifi] existing dongle: %s\n", e->d_name);
        }
        closedir(d);
    }
    if (g_ndongle > 0)
        try_autoconnect(g_dongle[0].ifname);
    write_status_json();

    if (access(WIFI_CMD, F_OK) == 0)
        handle_wifi_cmd();

    int nl_fd = socket(AF_NETLINK, SOCK_RAW | SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
    if (nl_fd < 0) { perror("[rpui-wifi] netlink socket"); return 1; }

    struct sockaddr_nl nl_addr;
    memset(&nl_addr, 0, sizeof(nl_addr));
    nl_addr.nl_family = AF_NETLINK;
    nl_addr.nl_pid    = (unsigned int)getpid();
    nl_addr.nl_groups = 1;
    if (bind(nl_fd, (struct sockaddr *)&nl_addr, sizeof(nl_addr)) < 0) {
        perror("[rpui-wifi] netlink bind"); close(nl_fd); return 1;
    }

    int in_fd = inotify_init1(IN_CLOEXEC);
    if (in_fd < 0) { perror("[rpui-wifi] inotify_init"); close(nl_fd); return 1; }
    if (inotify_add_watch(in_fd, "/tmp", IN_CREATE | IN_MOVED_TO) < 0) {
        perror("[rpui-wifi] inotify_add_watch");
        close(in_fd); close(nl_fd); return 1;
    }

    fprintf(stderr, "[rpui-wifi] started, %d dongle(s)\n", g_ndongle);

    struct pollfd fds[2] = {
        { .fd = nl_fd, .events = POLLIN },
        { .fd = in_fd, .events = POLLIN },
    };

    while (g_running) {
        int r = poll(fds, 2, 5000);
        if (r < 0) {
            if (errno == EINTR) continue;
            perror("[rpui-wifi] poll");
            break;
        }
        if (r == 0) {
            poll_wifi_status();
            write_status_json();
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
                if (ev->len && strcmp(ev->name, WIFI_CMD_NAME) == 0)
                    handle_wifi_cmd();
            }
        }
    }

    fprintf(stderr, "[rpui-wifi] exit\n");
    if (g_active_if[0]) stop_wifi_link(g_active_if);
    unlink(STATUS_JSON);
    close(in_fd);
    close(nl_fd);
    return 0;
}

/* ── main ──────────────────────────────────────────────── */

int main(int argc, char **argv)
{
    if (argc > 1)
        return run_cli(argc, argv);
    return run_daemon();
}
