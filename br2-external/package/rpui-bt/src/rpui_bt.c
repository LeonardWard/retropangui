/* rpui_bt.c — RetroPangUI 블루투스 관리 데몬 + CLI
 * USB BT 동글(hciN) 핫플러그 감지, /var/lib/bluetooth를 share 파티션으로
 * 영속화, BlueZ D-Bus API(GDBus/GIO)에 직접 붙어 어댑터 제어·에이전트·
 * 페어링을 이벤트 기반으로 처리한다.
 *
 * 2026-07-04 설계 변경: 처음엔 bluetoothctl을 서브프로세스로 실행하는
 * 방식이었는데, 실기기 테스트 결과 8BitDo 패드처럼 페어링 창이 짧은 기기를
 * 계속 놓쳤음(고정 시간 스캔 후 판단하는 방식이라 판단 시점엔 이미 창이
 * 닫혀있었음). Batocera/Recalbox 소스를 참고해보니 둘 다 D-Bus
 * InterfacesAdded/PropertiesChanged 시그널을 구독해서 기기가 보이는 즉시
 * 반응하는 방식 — bluetoothctl 서브프로세스 폴링을 버리고 이 방식으로 전환.
 *
 * 인자 없이 실행 = 데몬 모드 (상시 기동, GLib 메인루프로 D-Bus 이벤트 처리).
 * 인자 있이 실행 = CLI 모드 — list/live_devices/remove/blacklist는 여전히
 * bluetoothctl을 직접 호출(읽기 전용 조회라 경쟁 조건 없음). trust-pad/
 * trust-audio는 CMD 파일로 데몬에 위임 후 상태 파일을 폴링해 진행 상황 출력.
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
#include <stdint.h>
#include <dirent.h>
#include <gio/gio.h>
#include <gio/gunixfdlist.h>
#include <glib-unix.h>

#define MAX_ADAPTERS      8
#define STATUS_JSON       "/tmp/retropangui-bt-status.json"
#define BLACKLIST_FILE    "system/bt-blacklist.conf"
#define BT_CMD_FILE       "/tmp/retropangui-bt-cmd"
#define BT_PAIR_STATUS    "/tmp/retropangui-bt-pairing-status"
#define AGENT_PATH        "/rpui/agent"
#define DISCOVERY_MAX_WAIT 30 /* 초 */

static char g_adapters[MAX_ADAPTERS][16];
static int  g_nadapter = 0;
static int  g_persisted = 0;

static GDBusConnection *g_conn = NULL;
static GMainLoop       *g_loop = NULL;
static char g_pair_filter[32] = ""; /* "input-gaming" / "audio-" — 비어있으면 페어링 탐색 중 아님 */

/* ── 유틸 ──────────────────────────────────────────────── */

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
        if (*p == '/') { *p = '\0'; mkdir(tmp, 0755); *p = '/'; }
    }
    mkdir(tmp, 0755);
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

static pid_t spawn_argv(char *const argv[], int quiet)
{
    pid_t pid = fork();
    if (pid < 0) { perror("[rpui-bt] fork"); return -1; }
    if (pid == 0) {
        if (quiet) {
            int devnull = open("/dev/null", O_RDWR);
            if (devnull >= 0) { dup2(devnull, STDOUT_FILENO); dup2(devnull, STDERR_FILENO); close(devnull); }
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

/* ── /var/lib/bluetooth 영속화 (subprocess 기반, 변경 없음) ──
 * bluez5_utils의 S40bluetoothd는 share 마운트(S61share)보다 먼저 떠서
 * 로컬 /var/lib/bluetooth로 시작한다. rpui-bt는 share 마운트 이후
 * (S65) 기동되므로, 여기서 한 번 심볼릭 링크로 갈아끼우고 bluetoothd를
 * 재시작해 이후 페어링 정보가 share에 영속되도록 한다. */
static void setup_persistence(void)
{
    if (g_persisted) return;

    struct stat st;
    if (lstat("/var/lib/bluetooth", &st) == 0 && S_ISLNK(st.st_mode)) {
        g_persisted = 1;
        return;
    }

    char share[192], target[256];
    get_share_root(share, sizeof(share));
    snprintf(target, sizeof(target), "%s/system/bluetooth", share);
    mkdir_p(target);

    char *stop_argv[] = { (char*)"/etc/init.d/S40bluetoothd", (char*)"stop", NULL };
    spawn_and_wait(stop_argv);
    usleep(300000);

    char cmd[512];
    snprintf(cmd, sizeof(cmd), "cp -a /var/lib/bluetooth/. '%s/' 2>/dev/null; rm -rf /var/lib/bluetooth && ln -s '%s' /var/lib/bluetooth", target, target);
    char *sh_argv[] = { (char*)"sh", (char*)"-c", cmd, NULL };
    spawn_and_wait(sh_argv);

    char *start_argv[] = { (char*)"/etc/init.d/S40bluetoothd", (char*)"start", NULL };
    spawn_and_wait(start_argv);
    usleep(500000);

    g_persisted = 1;
    fprintf(stderr, "[rpui-bt] /var/lib/bluetooth → %s 로 영속화 완료\n", target);
}

/* ── status.json ──────────────────────────────────────────── */

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

static void write_pairing_status(const char *msg)
{
    char tmp[64];
    snprintf(tmp, sizeof(tmp), "%s.tmp", BT_PAIR_STATUS);
    FILE *f = fopen(tmp, "w");
    if (!f) return;
    fprintf(f, "%s\n", msg);
    fclose(f);
    rename(tmp, BT_PAIR_STATUS);
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

/* ── CLI: 목록/스캔 — 읽기 전용 조회라 bluetoothctl 서브프로세스 유지
 * (경쟁 조건 없음, pair/trust/connect처럼 창이 닫히는 문제와 무관) ──── */

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
    char *on_argv[]  = { (char*)"bluetoothctl", (char*)"--", (char*)"scan", (char*)"on", NULL };
    char *off_argv[] = { (char*)"bluetoothctl", (char*)"--", (char*)"scan", (char*)"off", NULL };
    spawn_and_wait(on_argv);
    sleep(8);
    spawn_and_wait(off_argv);

    FILE *p = popen("bluetoothctl devices 2>/dev/null", "r");
    if (!p) { printf("{\"devices\": []}\n"); return; }
    print_devices_json(p);
    pclose(p);
}

static void cli_remove(const char *mac)
{
    char cmdbuf[64];
    snprintf(cmdbuf, sizeof(cmdbuf), "remove %s", mac);
    char *argv[] = { (char*)"bluetoothctl", (char*)"--", cmdbuf, NULL };
    spawn_and_wait(argv);
    printf("제거: %s\n", mac);
}

/* ── D-Bus: 어댑터 경로/속성 ──────────────────────────────── */

static char *adapter_obj_path(const char *hciname)
{
    return g_strdup_printf("/org/bluez/%s", hciname);
}

static void adapter_set_bool(const char *hciname, const char *prop, gboolean val)
{
    char *path = adapter_obj_path(hciname);
    GError *err = NULL;
    GVariant *r = g_dbus_connection_call_sync(g_conn, "org.bluez", path,
        "org.freedesktop.DBus.Properties", "Set",
        g_variant_new("(ssv)", "org.bluez.Adapter1", prop, g_variant_new_boolean(val)),
        NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &err);
    if (r) g_variant_unref(r);
    if (err) {
        fprintf(stderr, "[rpui-bt] 어댑터 %s %s=%d 설정 실패: %s\n", hciname, prop, val, err->message);
        g_error_free(err);
    }
    g_free(path);
}

static void start_discovery_on(const char *hciname)
{
    char *path = adapter_obj_path(hciname);
    GError *err = NULL;
    GVariant *r = g_dbus_connection_call_sync(g_conn, "org.bluez", path,
        "org.bluez.Adapter1", "StartDiscovery", NULL,
        NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &err);
    if (r) g_variant_unref(r);
    if (err) { fprintf(stderr, "[rpui-bt] StartDiscovery(%s) 실패: %s\n", hciname, err->message); g_error_free(err); }
    g_free(path);
}

static void stop_discovery_all(void)
{
    for (int i = 0; i < g_nadapter; i++) {
        char *path = adapter_obj_path(g_adapters[i]);
        g_dbus_connection_call(g_conn, "org.bluez", path, "org.bluez.Adapter1", "StopDiscovery",
            NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, NULL, NULL); /* best-effort, 결과 무시 */
        g_free(path);
    }
}

/* 어댑터 기본 설정 — Just Works 자동 페어링(에이전트는 데몬 전체에 한 번만
 * 등록, register_agent() 참고). 항상 검색 가능 상태는 아님(불필요한 자동
 * 페어링 방지, trust-pad/trust-audio 실행 시에만 discoverable) */
static void configure_adapter(const char *hciname)
{
    adapter_set_bool(hciname, "Powered", TRUE);
    adapter_set_bool(hciname, "Pairable", TRUE);
}

/* ── D-Bus: Agent1 (Just Works, NoInputNoOutput) ─────────── */

static const gchar agent_xml[] =
"<node><interface name='org.bluez.Agent1'>"
"<method name='Release'/>"
"<method name='AuthorizeService'><arg type='o' direction='in'/><arg type='s' direction='in'/></method>"
"<method name='RequestPinCode'><arg type='o' direction='in'/><arg type='s' direction='out'/></method>"
"<method name='RequestPasskey'><arg type='o' direction='in'/><arg type='u' direction='out'/></method>"
"<method name='DisplayPasskey'><arg type='o' direction='in'/><arg type='u' direction='in'/><arg type='q' direction='in'/></method>"
"<method name='DisplayPinCode'><arg type='o' direction='in'/><arg type='s' direction='in'/></method>"
"<method name='RequestConfirmation'><arg type='o' direction='in'/><arg type='u' direction='in'/></method>"
"<method name='RequestAuthorization'><arg type='o' direction='in'/></method>"
"<method name='Cancel'/>"
"</interface></node>";

static void agent_method_call(GDBusConnection *conn, const gchar *sender, const gchar *object_path,
    const gchar *interface, const gchar *method, GVariant *params,
    GDBusMethodInvocation *invocation, gpointer user_data)
{
    (void)conn; (void)sender; (void)object_path; (void)interface; (void)params; (void)user_data;

    if (strcmp(method, "RequestPinCode") == 0)
        g_dbus_method_invocation_return_value(invocation, g_variant_new("(s)", "0000"));
    else if (strcmp(method, "RequestPasskey") == 0)
        g_dbus_method_invocation_return_value(invocation, g_variant_new("(u)", 0u));
    else
        /* Release/AuthorizeService/DisplayPasskey/DisplayPinCode/RequestConfirmation/
         * RequestAuthorization/Cancel — 반환값 없음, 즉시 승인(Just Works) */
        g_dbus_method_invocation_return_value(invocation, NULL);
}

static const GDBusInterfaceVTable agent_vtable = { agent_method_call, NULL, NULL, { 0 } };

static void register_agent(void)
{
    GError *err = NULL;
    GDBusNodeInfo *node = g_dbus_node_info_new_for_xml(agent_xml, &err);
    if (!node) {
        fprintf(stderr, "[rpui-bt] agent XML 파싱 실패: %s\n", err ? err->message : "?");
        if (err) g_error_free(err);
        return;
    }

    g_dbus_connection_register_object(g_conn, AGENT_PATH, node->interfaces[0],
        &agent_vtable, NULL, NULL, &err);
    if (err) {
        fprintf(stderr, "[rpui-bt] agent 오브젝트 등록 실패: %s\n", err->message);
        g_error_free(err); err = NULL;
    }

    GVariant *r1 = g_dbus_connection_call_sync(g_conn, "org.bluez", "/org/bluez",
        "org.bluez.AgentManager1", "RegisterAgent",
        g_variant_new("(os)", AGENT_PATH, "NoInputNoOutput"),
        NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &err);
    if (r1) g_variant_unref(r1);
    if (err) { fprintf(stderr, "[rpui-bt] RegisterAgent 실패: %s\n", err->message); g_error_free(err); err = NULL; }

    GVariant *r2 = g_dbus_connection_call_sync(g_conn, "org.bluez", "/org/bluez",
        "org.bluez.AgentManager1", "RequestDefaultAgent",
        g_variant_new("(o)", AGENT_PATH),
        NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &err);
    if (r2) g_variant_unref(r2);
    if (err) { fprintf(stderr, "[rpui-bt] RequestDefaultAgent 실패: %s\n", err->message); g_error_free(err); }

    g_dbus_node_info_unref(node);
    fprintf(stderr, "[rpui-bt] BlueZ 에이전트 등록 완료\n");
}

/* ── D-Bus: 기기 속성 조회 + 페어링 반응 로직 ─────────────── */

typedef struct {
    char address[18];
    char name[128];
    char icon[32];
    gboolean paired, trusted, connected;
} DeviceProps;

static void parse_device_props_dict(GVariant *dict, DeviceProps *out)
{
    memset(out, 0, sizeof(*out));
    GVariantIter iter;
    const gchar *key;
    GVariant *value;
    g_variant_iter_init(&iter, dict);
    while (g_variant_iter_next(&iter, "{&sv}", &key, &value)) {
        if (strcmp(key, "Address") == 0 && g_variant_is_of_type(value, G_VARIANT_TYPE_STRING))
            snprintf(out->address, sizeof(out->address), "%s", g_variant_get_string(value, NULL));
        else if ((strcmp(key, "Name") == 0 || strcmp(key, "Alias") == 0) && !out->name[0]
                 && g_variant_is_of_type(value, G_VARIANT_TYPE_STRING))
            snprintf(out->name, sizeof(out->name), "%s", g_variant_get_string(value, NULL));
        else if (strcmp(key, "Icon") == 0 && g_variant_is_of_type(value, G_VARIANT_TYPE_STRING))
            snprintf(out->icon, sizeof(out->icon), "%s", g_variant_get_string(value, NULL));
        else if (strcmp(key, "Paired") == 0 && g_variant_is_of_type(value, G_VARIANT_TYPE_BOOLEAN))
            out->paired = g_variant_get_boolean(value);
        else if (strcmp(key, "Trusted") == 0 && g_variant_is_of_type(value, G_VARIANT_TYPE_BOOLEAN))
            out->trusted = g_variant_get_boolean(value);
        else if (strcmp(key, "Connected") == 0 && g_variant_is_of_type(value, G_VARIANT_TYPE_BOOLEAN))
            out->connected = g_variant_get_boolean(value);
        g_variant_unref(value);
    }
}

static int get_device_props(const char *obj_path, DeviceProps *out)
{
    memset(out, 0, sizeof(*out));
    GError *err = NULL;
    GVariant *result = g_dbus_connection_call_sync(g_conn, "org.bluez", obj_path,
        "org.freedesktop.DBus.Properties", "GetAll",
        g_variant_new("(s)", "org.bluez.Device1"),
        G_VARIANT_TYPE("(a{sv})"), G_DBUS_CALL_FLAGS_NONE, 3000, NULL, &err);
    if (!result) {
        if (err) g_error_free(err);
        return 0;
    }
    GVariant *dict = g_variant_get_child_value(result, 0);
    parse_device_props_dict(dict, out);
    g_variant_unref(dict);
    g_variant_unref(result);
    return out->address[0] != '\0';
}

/* 페어링 탐색 중 처음 매칭된 후보 하나에만 고정 — 동일 물리 기기가 서로
 * 다른 MAC 2개로 동시에 광고되는 경우(2026-07-04 실기기에서 8BitDo SN30
 * Pro가 이런 걸로 확인됨) 여러 후보를 동시에 pair 시도하면 상태 메시지가
 * 뒤섞여서 실제로는 실패한 쪽의 "완료"가 찍히는 등 혼란이 생김. */
static char g_pairing_target[256] = "";

static void async_call_log(GObject *src, GAsyncResult *res, gpointer user_data)
{
    GError *err = NULL;
    GVariant *r = g_dbus_connection_call_finish(G_DBUS_CONNECTION(src), res, &err);
    const char *op = (const char*)user_data;
    if (r) g_variant_unref(r);
    if (err) {
        fprintf(stderr, "[rpui-bt] %s 실패: %s\n", op, err->message);
        char msg[256];
        snprintf(msg, sizeof(msg), "실패: %s (%s)", op, err->message);
        write_pairing_status(msg);
        g_pairing_target[0] = '\0'; /* 이 후보 포기 — 다른 후보(예: 같은 기기의 다른 MAC) 재시도 허용 */
        g_error_free(err);
    }
}

/* 페어링 탐색 중일 때 기기 상태에 따라 다음 단계(pair→trust→connect)를
 * 진행 — InterfacesAdded/PropertiesChanged 시그널마다 호출되어, 상태가
 * 바뀌는 즉시(폴링 지연 없이) 반응한다. Batocera의 connect_device()와
 * 동일한 발상. */
static void maybe_pair_device(const char *obj_path)
{
    if (!g_pair_filter[0]) return; /* 페어링 탐색 중 아님 */
    if (g_pairing_target[0] && strcmp(obj_path, g_pairing_target) != 0) return; /* 이미 다른 후보 진행 중 */

    DeviceProps dp;
    if (!get_device_props(obj_path, &dp)) return;
    if (!dp.address[0]) return;
    if (is_blacklisted(dp.address)) return;
    if (!dp.icon[0] || strncmp(dp.icon, g_pair_filter, strlen(g_pair_filter)) != 0) return;

    if (!g_pairing_target[0])
        snprintf(g_pairing_target, sizeof(g_pairing_target), "%s", obj_path);

    const char *label = dp.name[0] ? dp.name : dp.address;

    if (dp.connected) {
        char msg[256];
        snprintf(msg, sizeof(msg), "CONNECTED %s (%s)", label, dp.address);
        write_pairing_status(msg);
        fprintf(stderr, "[rpui-bt] %s\n", msg);
        g_pair_filter[0] = '\0';
        g_pairing_target[0] = '\0';
        stop_discovery_all();
        return;
    }

    if (dp.paired && dp.trusted) {
        char msg[256];
        snprintf(msg, sizeof(msg), "CONNECTING %s (%s)", label, dp.address);
        write_pairing_status(msg);
        g_dbus_connection_call(g_conn, "org.bluez", obj_path, "org.bluez.Device1", "Connect",
            NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 15000, NULL, async_call_log, (gpointer)"connect");
        return;
    }

    if (dp.paired && !dp.trusted) {
        char msg[256];
        snprintf(msg, sizeof(msg), "TRUSTING %s (%s)", label, dp.address);
        write_pairing_status(msg);
        g_dbus_connection_call(g_conn, "org.bluez", obj_path,
            "org.freedesktop.DBus.Properties", "Set",
            g_variant_new("(ssv)", "org.bluez.Device1", "Trusted", g_variant_new_boolean(TRUE)),
            NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, async_call_log, (gpointer)"trust");
        return;
    }

    /* !dp.paired */
    char msg[256];
    snprintf(msg, sizeof(msg), "PAIRING %s (%s)", label, dp.address);
    write_pairing_status(msg);
    g_dbus_connection_call(g_conn, "org.bluez", obj_path, "org.bluez.Device1", "Pair",
        NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 15000, NULL, async_call_log, (gpointer)"pair");
}

static void on_interfaces_added(GDBusConnection *conn, const gchar *sender, const gchar *object_path,
    const gchar *interface, const gchar *signal, GVariant *params, gpointer user_data)
{
    (void)conn; (void)sender; (void)object_path; (void)interface; (void)signal; (void)user_data;

    const gchar *path;
    GVariant *interfaces;
    g_variant_get(params, "(&o@a{sa{sv}})", &path, &interfaces);

    GVariant *dev = g_variant_lookup_value(interfaces, "org.bluez.Device1", G_VARIANT_TYPE("a{sv}"));
    if (dev) {
        g_variant_unref(dev);
        maybe_pair_device(path);
    }
    g_variant_unref(interfaces);
}

static void on_properties_changed(GDBusConnection *conn, const gchar *sender, const gchar *object_path,
    const gchar *interface, const gchar *signal, GVariant *params, gpointer user_data)
{
    (void)conn; (void)sender; (void)interface; (void)signal; (void)user_data; (void)params;
    maybe_pair_device(object_path);
}

/* ── 데몬: netlink 핫플러그 감지 (기존과 동일, 어댑터 설정만 D-Bus로) ── */

static void adapter_added(const char *hciname)
{
    for (int i = 0; i < g_nadapter; i++)
        if (strcmp(g_adapters[i], hciname) == 0) return;
    if (g_nadapter >= MAX_ADAPTERS) return;

    strncpy(g_adapters[g_nadapter], hciname, sizeof(g_adapters[g_nadapter]) - 1);
    g_nadapter++;
    fprintf(stderr, "[rpui-bt] adapter added: %s\n", hciname);

    setup_persistence();
    configure_adapter(hciname);
    write_status_json();
}

static void scan_existing_adapters(void)
{
    DIR *d = opendir("/sys/class/bluetooth");
    if (!d) return;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        if (strncmp(ent->d_name, "hci", 3) == 0)
            adapter_added(ent->d_name);
    }
    closedir(d);
}

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
    if (strncmp(hciname, "hci", 3) != 0) return;

    if (strcmp(action, "add") == 0) {
        usleep(500000);
        adapter_added(hciname);
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

static gboolean on_netlink_readable(GIOChannel *source, GIOCondition cond, gpointer user_data)
{
    (void)cond; (void)user_data;
    int fd = g_io_channel_unix_get_fd(source);
    char buf[4096];
    ssize_t len = recv(fd, buf, sizeof(buf) - 1, 0);
    if (len > 0) { buf[len] = '\0'; parse_uevent(buf, len); }
    return G_SOURCE_CONTINUE;
}

/* ── 데몬: CMD 파일 폴링 (trust-pad/trust-audio 요청 수신) ───── */

static gboolean on_discovery_timeout(gpointer user_data)
{
    (void)user_data;
    if (g_pair_filter[0]) {
        write_pairing_status("TIMEOUT");
        fprintf(stderr, "[rpui-bt] 페어링 탐색 시간 초과\n");
        g_pair_filter[0] = '\0';
        g_pairing_target[0] = '\0';
        stop_discovery_all();
    }
    return G_SOURCE_REMOVE;
}

static void begin_pairing_search(const char *icon_filter)
{
    snprintf(g_pair_filter, sizeof(g_pair_filter), "%s", icon_filter);
    g_pairing_target[0] = '\0';
    write_pairing_status("SCANNING");
    for (int i = 0; i < g_nadapter; i++) start_discovery_on(g_adapters[i]);
    g_timeout_add_seconds(DISCOVERY_MAX_WAIT, on_discovery_timeout, NULL);
}

static gboolean on_cmd_file_tick(gpointer user_data)
{
    (void)user_data;
    char line[64];
    if (read_first_line(BT_CMD_FILE, line, sizeof(line)) != 0) return G_SOURCE_CONTINUE;
    unlink(BT_CMD_FILE);

    if (strcmp(line, "TRUST_PAD") == 0)
        begin_pairing_search("input-gaming");
    else if (strcmp(line, "TRUST_AUDIO") == 0)
        begin_pairing_search("audio-");

    return G_SOURCE_CONTINUE;
}

static gboolean on_sigterm(gpointer user_data)
{
    (void)user_data;
    if (g_loop) g_main_loop_quit(g_loop);
    return G_SOURCE_REMOVE;
}

static void run_daemon(void)
{
    write_status_json();

    GError *err = NULL;
    g_conn = g_bus_get_sync(G_BUS_TYPE_SYSTEM, NULL, &err);
    if (!g_conn) {
        fprintf(stderr, "[rpui-bt] system bus 연결 실패: %s\n", err ? err->message : "?");
        if (err) g_error_free(err);
        return;
    }

    register_agent();

    g_dbus_connection_signal_subscribe(g_conn, "org.bluez",
        "org.freedesktop.DBus.ObjectManager", "InterfacesAdded", "/", NULL,
        G_DBUS_SIGNAL_FLAGS_NONE, on_interfaces_added, NULL, NULL);

    g_dbus_connection_signal_subscribe(g_conn, "org.bluez",
        "org.freedesktop.DBus.Properties", "PropertiesChanged", NULL, "org.bluez.Device1",
        G_DBUS_SIGNAL_FLAGS_NONE, on_properties_changed, NULL, NULL);

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

    GIOChannel *nl_ch = g_io_channel_unix_new(nl_fd);
    g_io_add_watch(nl_ch, G_IO_IN, on_netlink_readable, NULL);

    scan_existing_adapters();

    g_timeout_add(300, on_cmd_file_tick, NULL);

    g_unix_signal_add(SIGTERM, on_sigterm, NULL);
    g_unix_signal_add(SIGINT, on_sigterm, NULL);

    fprintf(stderr, "[rpui-bt] started (D-Bus)\n");

    g_loop = g_main_loop_new(NULL, FALSE);
    g_main_loop_run(g_loop);

    fprintf(stderr, "[rpui-bt] stopped\n");
    g_io_channel_unref(nl_ch);
    close(nl_fd);
    g_main_loop_unref(g_loop);
}

/* ── CLI: trust-pad/trust-audio — CMD 파일로 데몬에 위임 후
 * 상태 파일을 폴링해 진행 상황 출력 (Batocera의 bt_status tail과 동일 발상) ── */

static void cli_write_cmd(const char *cmd)
{
    FILE *f = fopen(BT_CMD_FILE, "w");
    if (!f) { fprintf(stderr, "명령 전달 실패 — rpui-bt 데몬이 실행 중인지 확인하세요\n"); return; }
    fprintf(f, "%s\n", cmd);
    fclose(f);
}

static void cli_auto_trust(const char *cmd, const char *label)
{
    unlink(BT_PAIR_STATUS);
    cli_write_cmd(cmd);

    char last[256] = "";
    for (int i = 0; i < DISCOVERY_MAX_WAIT * 5; i++) {
        usleep(200000);
        char cur[256];
        if (read_first_line(BT_PAIR_STATUS, cur, sizeof(cur)) != 0) continue;
        if (strcmp(cur, last) == 0) continue;

        strncpy(last, cur, sizeof(last) - 1);
        if (strcmp(cur, "SCANNING") == 0) { printf("탐색 중...\n"); continue; }
        if (strcmp(cur, "TIMEOUT") == 0) { printf("탐지된 %s 장치 없음 (%d초 대기)\n", label, DISCOVERY_MAX_WAIT); return; }
        if (strncmp(cur, "CONNECTED", 9) == 0) { printf("완료: %s\n", cur + 10); return; }
        if (strncmp(cur, "실패:", 6) == 0) { printf("%s\n", cur); return; }
        printf("%s\n", cur);
    }
    printf("응답 없음 (시간 초과)\n");
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
    else if (strcmp(argv[1], "trust-pad") == 0)    cli_auto_trust("TRUST_PAD", "컨트롤러");
    else if (strcmp(argv[1], "trust-audio") == 0)  cli_auto_trust("TRUST_AUDIO", "오디오 장치");
    else if (strcmp(argv[1], "remove") == 0 && argc >= 3)      cli_remove(argv[2]);
    else if (strcmp(argv[1], "blacklist") == 0 && argc >= 3)   cli_blacklist(argv[2], argc >= 4 ? argv[3] : NULL);
    else if (strcmp(argv[1], "unblacklist") == 0 && argc >= 3) cli_unblacklist(argv[2]);
    else { usage(); return 1; }

    return 0;
}
