/* rpui_bt.c — RetroPangUI 블루투스 관리 데몬 + CLI
 * USB BT 동글(hciN) 핫플러그 감지, /var/lib/bluetooth를 share 파티션으로
 * 영속화, bluetoothctl(BlueZ 5.72, 논인터랙티브 단발 명령 지원)을
 * 서브프로세스로 실행해 어댑터 설정·페어링을 제어한다.
 *
 * 인자 없이 실행 = 데몬 모드 (상시 기동, 핫플러그 감지 전담).
 * 인자 있이 실행 = CLI 모드 — bluetoothctl은 D-Bus 호출 기반이라 별도
 * 프로세스 소유권 충돌이 없으므로, rpui-wifi와 달리 CLI가 데몬에
 * CMD파일로 위임하지 않고 매 호출마다 직접 bluetoothctl을 실행한다.
 */
#define _POSIX_C_SOURCE 200809L
#define _DEFAULT_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <linux/netlink.h>
#include <poll.h>
#include <stdint.h>

#define MAX_ADAPTERS   8
#define STATUS_JSON    "/tmp/retropangui-bt-status.json"
#define BLACKLIST_FILE "system/bt-blacklist.conf"
#define SCAN_SECONDS   "8"

static char g_adapters[MAX_ADAPTERS][16];
static int  g_nadapter = 0;
static int  g_persisted = 0; /* /var/lib/bluetooth 심볼릭 링크 설정 완료 여부 */
static volatile sig_atomic_t g_running = 1;

static void sig_handler(int s) { (void)s; g_running = 0; }

/* ── 유틸 ──────────────────────────────────────────────── */

/* RETROPANGUI_SHARE → /share → ~/share 순서 (rpui-wifi와 동일 규칙) */
static void get_share_root(char *buf, size_t sz)
{
    const char *env = getenv("RETROPANGUI_SHARE");
    if (env && env[0] != '\0') { snprintf(buf, sz, "%s", env); return; }

    if (access("/share", F_OK) == 0) { snprintf(buf, sz, "/share"); return; }

    const char *home = getenv("HOME");
    snprintf(buf, sz, "%s/share", home ? home : "/root");
}

static void mkdir_p(const char *path)
{
    char tmp[256];
    snprintf(tmp, sizeof(tmp), "%s", path);
    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(tmp, 0755);
            *p = '/';
        }
    }
    mkdir(tmp, 0755);
}

static pid_t spawn_argv(char *const argv[], int quiet)
{
    pid_t pid = fork();
    if (pid < 0) { perror("[rpui-bt] fork"); return -1; }
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
        _exit(127);
    }
    return pid;
}

static void spawn_and_wait(char *const argv[])
{
    pid_t pid = spawn_argv(argv, 1);
    if (pid > 0) waitpid(pid, NULL, 0);
}

static void bt_ctl(const char *cmd)
{
    char cmdbuf[64];
    snprintf(cmdbuf, sizeof(cmdbuf), "%s", cmd);
    char *argv[] = { (char*)"bluetoothctl", (char*)"--", cmdbuf, NULL };
    spawn_and_wait(argv);
}

/* ── /var/lib/bluetooth 영속화 ────────────────────────────
 * bluez5_utils의 S40bluetoothd는 share 마운트(S61share)보다 먼저 떠서
 * 로컬 /var/lib/bluetooth로 시작한다. rpui-bt는 share 마운트 이후
 * (S65) 기동되므로, 여기서 한 번 심볼릭 링크로 갈아끼우고 bluetoothd를
 * 재시작해 이후 페어링 정보가 share에 영속되도록 한다. */
static void setup_persistence(void)
{
    if (g_persisted) return;

    struct stat st;
    if (lstat("/var/lib/bluetooth", &st) == 0 && S_ISLNK(st.st_mode)) {
        g_persisted = 1; /* 이미 심볼릭 링크로 전환됨 (재부팅 후 재실행 케이스) */
        return;
    }

    char share[192], target[256];
    get_share_root(share, sizeof(share));
    snprintf(target, sizeof(target), "%s/system/bluetooth", share);
    mkdir_p(target);

    char *stop_argv[] = { (char*)"/etc/init.d/S40bluetoothd", (char*)"stop", NULL };
    spawn_and_wait(stop_argv);
    usleep(300000);

    /* 로컬 /var/lib/bluetooth는 비어있거나 첫 부팅 임시 데이터뿐 — 통째로 교체 */
    char cmd[512];
    snprintf(cmd, sizeof(cmd), "rm -rf /var/lib/bluetooth && ln -s '%s' /var/lib/bluetooth", target);
    char *sh_argv[] = { (char*)"sh", (char*)"-c", cmd, NULL };
    spawn_and_wait(sh_argv);

    char *start_argv[] = { (char*)"/etc/init.d/S40bluetoothd", (char*)"start", NULL };
    spawn_and_wait(start_argv);
    usleep(500000); /* bluetoothd가 D-Bus에 등록될 시간 확보 */

    g_persisted = 1;
    fprintf(stderr, "[rpui-bt] /var/lib/bluetooth → %s 로 영속화 완료\n", target);
}

/* 어댑터 기본 설정 — Just Works 자동 페어링(PIN 입력 UI 없음), 항상 검색 가능 상태는
 * 아님(불필요한 자동 페어링 방지, trust-pad/trust-audio 실행 시에만 discoverable) */
static void configure_adapter(void)
{
    bt_ctl("power on");
    bt_ctl("agent NoInputNoOutput");
    bt_ctl("default-agent");
    bt_ctl("pairable on");
}

/* ── status.json (tmp+rename로 원자적 기록) ──────────────── */

static void write_status_json(void)
{
    char tmp[64];
    snprintf(tmp, sizeof(tmp), "%s.tmp", STATUS_JSON);
    FILE *f = fopen(tmp, "w");
    if (!f) return;

    fprintf(f, "{\n  \"adapters\": [\n");
    for (int i = 0; i < g_nadapter; i++)
        fprintf(f, "    \"%s\"%s\n", g_adapters[i], (i < g_nadapter - 1) ? "," : "");
    fprintf(f, "  ],\n  \"powered\": %s\n}\n", g_nadapter > 0 ? "true" : "false");

    fclose(f);
    rename(tmp, STATUS_JSON);
}

/* ── 블랙리스트 (share에 저장, MAC 한 줄씩) ──────────────── */

static void blacklist_path(char *buf, size_t sz)
{
    char share[192];
    get_share_root(share, sizeof(share));
    snprintf(buf, sz, "%s/%s", share, BLACKLIST_FILE);
}

static int is_blacklisted(const char *mac)
{
    char path[256];
    blacklist_path(path, sizeof(path));
    FILE *f = fopen(path, "r");
    if (!f) return 0;

    char line[128];
    int found = 0;
    while (fgets(line, sizeof(line), f)) {
        size_t n = strlen(line);
        while (n && (line[n-1] == '\n' || line[n-1] == '\r')) line[--n] = '\0';
        char *sp = strchr(line, ' ');
        size_t maclen = sp ? (size_t)(sp - line) : strlen(line);
        if (maclen == strlen(mac) && strncasecmp(line, mac, maclen) == 0) { found = 1; break; }
    }
    fclose(f);
    return found;
}

static void cli_blacklist(const char *mac, const char *name)
{
    char path[256];
    blacklist_path(path, sizeof(path));
    char dir[256]; snprintf(dir, sizeof(dir), "%s", path);
    char *slash = strrchr(dir, '/');
    if (slash) { *slash = '\0'; mkdir_p(dir); }

    if (is_blacklisted(mac)) { printf("이미 블랙리스트에 있음: %s\n", mac); return; }

    FILE *f = fopen(path, "a");
    if (!f) { fprintf(stderr, "블랙리스트 기록 실패\n"); return; }
    fprintf(f, "%s %s\n", mac, name ? name : "");
    fclose(f);
    printf("블랙리스트 등록: %s %s\n", mac, name ? name : "");
}

static void cli_unblacklist(const char *mac)
{
    char path[256];
    blacklist_path(path, sizeof(path));
    FILE *f = fopen(path, "r");
    if (!f) { printf("블랙리스트 없음\n"); return; }

    char tmp[280];
    snprintf(tmp, sizeof(tmp), "%s.tmp", path);
    FILE *out = fopen(tmp, "w");
    if (!out) { fclose(f); return; }

    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (strncasecmp(line, mac, strlen(mac)) == 0) continue;
        fputs(line, out);
    }
    fclose(f); fclose(out);
    rename(tmp, path);
    printf("블랙리스트 해제: %s\n", mac);
}

/* ── CLI: 목록/스캔 (bluetoothctl 출력 파싱, JSON으로 재출력) ── */

/* "Device XX:XX:XX:XX:XX:XX Name..." 줄들을 JSON 배열로 변환 */
static void print_devices_json(FILE *p)
{
    printf("{\n  \"devices\": [\n");
    char line[256];
    int first = 1;
    while (fgets(line, sizeof(line), p)) {
        char *dp = strstr(line, "Device ");
        if (!dp) continue;
        dp += 7;
        char mac[18] = "";
        char *sp = strchr(dp, ' ');
        if (!sp || (size_t)(sp - dp) >= sizeof(mac)) continue;
        strncpy(mac, dp, (size_t)(sp - dp));
        mac[sp - dp] = '\0';

        char *name = sp + 1;
        size_t nlen = strlen(name);
        while (nlen && (name[nlen-1] == '\n' || name[nlen-1] == '\r')) name[--nlen] = '\0';

        if (is_blacklisted(mac)) continue;

        if (!first) printf(",\n");
        printf("    {\"mac\": \"%s\", \"name\": \"%s\"}", mac, name);
        first = 0;
    }
    printf("%s  ]\n}\n", first ? "" : "\n");
}

static void cli_list(void)
{
    FILE *p = popen("bluetoothctl devices Paired 2>/dev/null", "r");
    if (!p) { printf("{\"devices\": []}\n"); return; }
    print_devices_json(p);
    pclose(p);
}

static void cli_live_devices(void)
{
    char cmd[64];
    snprintf(cmd, sizeof(cmd), "bluetoothctl --timeout %s scan on >/dev/null 2>&1", SCAN_SECONDS);
    system(cmd); /* 고정 인자, 사용자 입력 없음 — 안전 */

    FILE *p = popen("bluetoothctl devices 2>/dev/null", "r");
    if (!p) { printf("{\"devices\": []}\n"); return; }
    print_devices_json(p);
    pclose(p);
}

/* 장치 하나의 Icon 필드를 읽어 종류 판별 (input-gaming / audio-*) */
static int device_icon_matches(const char *mac, const char *needle)
{
    char cmd[64];
    snprintf(cmd, sizeof(cmd), "bluetoothctl info %s 2>/dev/null", mac);
    FILE *p = popen(cmd, "r");
    if (!p) return 0;

    char line[256];
    int match = 0;
    while (fgets(line, sizeof(line), p)) {
        if (strstr(line, "Icon:") && strstr(line, needle)) { match = 1; break; }
    }
    pclose(p);
    return match;
}

/* 스캔 후 지정 아이콘 종류의 첫 장치를 자동 pair+trust+connect */
static void auto_trust(const char *icon_needle, const char *label)
{
    char cmd[64];
    snprintf(cmd, sizeof(cmd), "bluetoothctl --timeout %s scan on >/dev/null 2>&1", SCAN_SECONDS);
    system(cmd);

    FILE *p = popen("bluetoothctl devices 2>/dev/null", "r");
    if (!p) { printf("스캔 실패\n"); return; }

    char line[256], found_mac[18] = "", found_name[128] = "";
    while (fgets(line, sizeof(line), p)) {
        char *dp = strstr(line, "Device ");
        if (!dp) continue;
        dp += 7;
        char mac[18] = "";
        char *sp = strchr(dp, ' ');
        if (!sp || (size_t)(sp - dp) >= sizeof(mac)) continue;
        strncpy(mac, dp, (size_t)(sp - dp));
        mac[sp - dp] = '\0';

        if (is_blacklisted(mac)) continue;
        if (!device_icon_matches(mac, icon_needle)) continue;

        strncpy(found_mac, mac, sizeof(found_mac) - 1);
        char *name = sp + 1;
        size_t nlen = strlen(name);
        while (nlen && (name[nlen-1] == '\n' || name[nlen-1] == '\r')) name[--nlen] = '\0';
        strncpy(found_name, name, sizeof(found_name) - 1);
        break;
    }
    pclose(p);

    if (!found_mac[0]) { printf("탐지된 %s 장치 없음\n", label); return; }

    printf("발견: %s (%s) — 페어링 시도\n", found_name, found_mac);
    char argv_buf[3][64];
    snprintf(argv_buf[0], sizeof(argv_buf[0]), "pair %s", found_mac);
    snprintf(argv_buf[1], sizeof(argv_buf[1]), "trust %s", found_mac);
    snprintf(argv_buf[2], sizeof(argv_buf[2]), "connect %s", found_mac);
    for (int i = 0; i < 3; i++) {
        char *argv[] = { (char*)"bluetoothctl", (char*)"--", argv_buf[i], NULL };
        spawn_and_wait(argv);
        usleep(500000);
    }
    printf("완료: %s (%s)\n", found_name, found_mac);
}

static void cli_remove(const char *mac)
{
    char cmdbuf[64];
    snprintf(cmdbuf, sizeof(cmdbuf), "remove %s", mac);
    char *argv[] = { (char*)"bluetoothctl", (char*)"--", cmdbuf, NULL };
    spawn_and_wait(argv);
    printf("제거: %s\n", mac);
}

/* ── 데몬: netlink 핫플러그 감지 ───────────────────────────
 * SUBSYSTEM=bluetooth 이벤트에는 net과 달리 INTERFACE=가 없고 DEVPATH만
 * 있음 — DEVPATH의 마지막 구성요소(hciN)를 장치명으로 사용. */
static void parse_uevent(const char *buf, ssize_t len)
{
    char action[32] = "", devpath[192] = "", subsys[32] = "";

    const char *p = buf, *end = buf + len;
    while (p < end && *p) p++;
    if (p < end) p++;

    while (p < end) {
        const char *kv = p;
        while (p < end && *p) p++;
        if (p < end) p++;

        if      (strncmp(kv, "ACTION=",    7)  == 0) strncpy(action,  kv+7,  sizeof(action)-1);
        else if (strncmp(kv, "DEVPATH=",   8)  == 0) strncpy(devpath, kv+8,  sizeof(devpath)-1);
        else if (strncmp(kv, "SUBSYSTEM=", 10) == 0) strncpy(subsys,  kv+10, sizeof(subsys)-1);
    }

    if (strcmp(subsys, "bluetooth") != 0) return;
    if (!action[0] || !devpath[0]) return;

    const char *slash = strrchr(devpath, '/');
    const char *hciname = slash ? slash + 1 : devpath;
    if (strncmp(hciname, "hci", 3) != 0) return; /* L2CAP 등 하위 노드 이벤트 제외 */

    if (strcmp(action, "add") == 0) {
        for (int i = 0; i < g_nadapter; i++)
            if (strcmp(g_adapters[i], hciname) == 0) return;
        if (g_nadapter >= MAX_ADAPTERS) return;

        strncpy(g_adapters[g_nadapter], hciname, sizeof(g_adapters[g_nadapter]) - 1);
        g_nadapter++;
        fprintf(stderr, "[rpui-bt] adapter added: %s\n", hciname);

        usleep(500000); /* sysfs/D-Bus 등록 완료 대기 */
        setup_persistence();
        configure_adapter();
        write_status_json();

    } else if (strcmp(action, "remove") == 0) {
        for (int i = 0; i < g_nadapter; i++) {
            if (strcmp(g_adapters[i], hciname) == 0) {
                fprintf(stderr, "[rpui-bt] adapter removed: %s\n", hciname);
                memmove(&g_adapters[i], &g_adapters[i+1],
                        sizeof(g_adapters[0]) * (size_t)(g_nadapter - i - 1));
                g_nadapter--;
                write_status_json();
                break;
            }
        }
    }
}

static void run_daemon(void)
{
    signal(SIGTERM, sig_handler);
    signal(SIGINT,  sig_handler);

    write_status_json();

    int nl_fd = socket(AF_NETLINK, SOCK_RAW | SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
    if (nl_fd < 0) { perror("[rpui-bt] netlink socket"); return; }

    struct sockaddr_nl addr;
    memset(&addr, 0, sizeof(addr));
    addr.nl_family = AF_NETLINK;
    addr.nl_pid    = (uint32_t)getpid();
    addr.nl_groups = 1;

    if (bind(nl_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("[rpui-bt] netlink bind");
        close(nl_fd);
        return;
    }

    fprintf(stderr, "[rpui-bt] started\n");

    char buf[4096];
    struct pollfd pfd = { .fd = nl_fd, .events = POLLIN };

    while (g_running) {
        int r = poll(&pfd, 1, 5000);
        if (r < 0) { if (errno == EINTR) continue; break; }
        if (r == 0) continue; /* idle tick */

        ssize_t len = recv(nl_fd, buf, sizeof(buf) - 1, 0);
        if (len <= 0) continue;
        buf[len] = '\0';
        parse_uevent(buf, len);
    }

    close(nl_fd);
    fprintf(stderr, "[rpui-bt] stopped\n");
}

/* ── main ─────────────────────────────────────────────── */

static void usage(void)
{
    fprintf(stderr,
        "사용법: rpui-bt <list|live_devices|trust-pad|trust-audio|remove <MAC>|"
        "blacklist <MAC> [name]|unblacklist <MAC>>\n");
}

int main(int argc, char **argv)
{
    if (argc == 1) { run_daemon(); return 0; }

    if      (strcmp(argv[1], "list") == 0)         cli_list();
    else if (strcmp(argv[1], "live_devices") == 0) cli_live_devices();
    else if (strcmp(argv[1], "trust-pad") == 0)    auto_trust("input-gaming", "컨트롤러");
    else if (strcmp(argv[1], "trust-audio") == 0)  auto_trust("audio-", "오디오 장치");
    else if (strcmp(argv[1], "remove") == 0 && argc >= 3)      cli_remove(argv[2]);
    else if (strcmp(argv[1], "blacklist") == 0 && argc >= 3)   cli_blacklist(argv[2], argc >= 4 ? argv[3] : NULL);
    else if (strcmp(argv[1], "unblacklist") == 0 && argc >= 3) cli_unblacklist(argv[2]);
    else { usage(); return 1; }

    return 0;
}
