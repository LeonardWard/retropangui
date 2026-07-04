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
#include <ctype.h>
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
#define BT_DISCOVERY_JSON "/tmp/retropangui-bt-discovery.json"
#define AGENT_PATH        "/rpui/agent"
#define DISCOVERY_MAX_WAIT 30 /* 초 */

static char g_adapters[MAX_ADAPTERS][16];
static int  g_nadapter = 0;

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

/* ── /var/lib/bluetooth 영속화는 불필요 ────────────────────
 * 2026-07-04: 처음엔 bluez5_utils의 S40bluetoothd가 share 마운트보다
 * 먼저 떠서 로컬 /var/lib/bluetooth로 시작하니, share 파티션(exFAT)으로
 * 심볼릭 링크를 걸어 영속화하는 코드가 있었음 — 그런데 exFAT는 콜론(:)이
 * 든 파일/디렉토리명을 아예 못 만든다(mkdir: Invalid argument). BlueZ는
 * 페어링 정보를 /var/lib/bluetooth/<어댑터MAC>/<기기MAC>/ 형태(콜론 포함)
 * 로 저장하므로, 이 심볼릭 링크가 오히려 본딩 데이터 저장을 막아서
 * 재부팅하면 페어링이 통째로 사라지는 문제를 만들고 있었음(실기기 확인).
 *
 * 실제로는 루트 파일시스템 자체가 overlay(lowerdir=squashfs 읽기전용,
 * upperdir=/overlay/upper, ext4·재부팅해도 유지됨)라서, /var/lib/bluetooth를
 * 아무 손도 안 대고 그냥 두면 자동으로 /overlay/upper/var/lib/bluetooth에
 * 저장되어 이미 영속됨 — 별도 처리가 애초에 필요 없었음. */

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
    /* "remove <MAC>"을 한 문자열로 합쳐서 넘기면 bluetoothctl이 그 전체를
     * 명령어 이름으로 찾다가 실패해 조용히 무시함(2026-07-05 실기기 확인) —
     * remove와 MAC을 반드시 별도 argv로 넘겨야 함(쉘에서 직접 실행한 것과
     * 동일하게). */
    char *argv[] = { (char*)"bluetoothctl", (char*)"--", (char*)"remove", (char*)mac, NULL };
    spawn_and_wait(argv);
    printf("제거: %s\n", mac);
}

/* 페어링 기록 전체 초기화 — GUI의 "삭제" 메뉴(목록 없이 바로 전체 삭제)용 */
static void cli_remove_all(void)
{
    FILE *p = popen("bluetoothctl devices Paired 2>/dev/null", "r");
    if (!p) { printf("페어링된 기기 없음\n"); return; }

    char line[256];
    int count = 0;
    while (fgets(line, sizeof(line), p)) {
        char *dp = strstr(line, "Device ");
        if (!dp) continue;
        dp += 7;
        char mac[18] = "";
        char *sp = strchr(dp, ' ');
        if (!sp || (size_t)(sp - dp) >= sizeof(mac)) continue;
        strncpy(mac, dp, (size_t)(sp - dp));
        mac[sp - dp] = '\0';

        cli_remove(mac);
        count++;
    }
    pclose(p);
    printf("전체 삭제 완료: %d개\n", count);
}

/* ── D-Bus: 어댑터 경로/속성 ──────────────────────────────── */

static char *adapter_obj_path(const char *hciname)
{
    return g_strdup_printf("/org/bluez/%s", hciname);
}

/* g_adapters[0]("상위" 어댑터, 보통 hci0)만 실제로 사용 — 전원 on, 스캔,
 * 페어링 전부 여기서만 진행. 2026-07-04 실기기에서 확인: BT 동글 2개를
 * 동시에 켜두면(둘 다 discoverable/scanning) 2.4GHz 자체 간섭으로 페어링이
 * 붙었다 끊겼다 하는 불안정한 증상이 생김 — 동글 하나만 뽑으니 바로
 * 정상화됨. 보조 어댑터는 감지만 하고 전원을 켜지 않는다(상위 어댑터가
 * 제거되면 다음 것이 자동 승계). */
static const char *primary_adapter(void)
{
    return g_nadapter > 0 ? g_adapters[0] : NULL;
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
    const char *primary = primary_adapter();
    if (!primary) return;
    char *path = adapter_obj_path(primary);
    g_dbus_connection_call(g_conn, "org.bluez", path, "org.bluez.Adapter1", "StopDiscovery",
        NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, NULL, NULL); /* best-effort, 결과 무시 */
    g_free(path);
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
    gint16 rssi;
    gboolean has_rssi;
    char vendor[32];
} DeviceProps;

/* Modalias 형식 예: "bluetooth:v05C4p09CCd0100", "usb:v2DC8p6101d...".
 * 'v' 뒤 4자리 hex가 vendor id — 소규모 테이블만 인식(완벽한 OUI DB 아님). */
static void vendor_from_modalias(const char *modalias, char *out, size_t outsz)
{
    out[0] = '\0';
    if (!modalias) return;
    const char *v = strchr(modalias, ':'); /* "bluetooth:"/"usb:" 뒤에서부터 찾아 안전하게 'v' 위치 확보 */
    v = v ? strchr(v, 'v') : NULL;
    if (!v || strlen(v) < 5) return;

    char hexbuf[5];
    strncpy(hexbuf, v + 1, 4);
    hexbuf[4] = '\0';
    long vid = strtol(hexbuf, NULL, 16);

    switch (vid) {
        case 0x2DC8: snprintf(out, outsz, "%s", "8BitDo");    break;
        case 0x054C: snprintf(out, outsz, "%s", "Sony");      break;
        case 0x045E: snprintf(out, outsz, "%s", "Microsoft"); break;
        case 0x057E: snprintf(out, outsz, "%s", "Nintendo");  break;
        case 0x0E6F: snprintf(out, outsz, "%s", "PDP");       break;
        case 0x20D6: snprintf(out, outsz, "%s", "PowerA");    break;
        default: break; /* 매칭 없음 — 빈 문자열 유지 */
    }
}

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
        else if (strcmp(key, "RSSI") == 0 && g_variant_is_of_type(value, G_VARIANT_TYPE_INT16)) {
            out->rssi = g_variant_get_int16(value);
            out->has_rssi = TRUE;
        } else if (strcmp(key, "Modalias") == 0 && g_variant_is_of_type(value, G_VARIANT_TYPE_STRING))
            vendor_from_modalias(g_variant_get_string(value, NULL), out->vendor, sizeof(out->vendor));
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

/* 활성 스캔 세션 중 검색된 기기 전체 목록을 GUI가 폴링할 수 있도록 JSON으로
 * 기록. GetManagedObjects를 매 시그널마다 통째로 다시 조회하는 방식이라
 * 다소 낭비지만, 이 프로젝트 규모(기기 수 적음, 스캔 세션도 짧음)에선
 * 허용 가능한 수준 — 기존 코드도 매 시그널마다 GetAll을 부르는 방식이라 일관됨. */
static void write_discovery_list(void)
{
    char tmp[64];
    snprintf(tmp, sizeof(tmp), "%s.tmp", BT_DISCOVERY_JSON);

    const char *primary = primary_adapter();
    GError *err = NULL;
    GVariant *result = NULL;
    if (primary) {
        result = g_dbus_connection_call_sync(g_conn, "org.bluez", "/",
            "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", NULL,
            G_VARIANT_TYPE("(a{oa{sa{sv}}})"), G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &err);
    }
    if (err) { g_error_free(err); err = NULL; }

    FILE *f = fopen(tmp, "w");
    if (!f) { if (result) g_variant_unref(result); return; }

    if (!result) {
        fprintf(f, "{\"devices\": []}\n");
        fclose(f);
        rename(tmp, BT_DISCOVERY_JSON);
        return;
    }

    char *prefix = g_strdup_printf("/org/bluez/%s/dev_", primary);
    GVariant *managed = g_variant_get_child_value(result, 0);

    fprintf(f, "{\n  \"devices\": [\n");
    int first = 1;

    GVariantIter iter;
    const gchar *obj_path;
    GVariant *interfaces;
    g_variant_iter_init(&iter, managed);
    while (g_variant_iter_loop(&iter, "{&o@a{sa{sv}}}", &obj_path, &interfaces)) {
        if (!g_str_has_prefix(obj_path, prefix)) continue;

        GVariant *dev = g_variant_lookup_value(interfaces, "org.bluez.Device1", G_VARIANT_TYPE("a{sv}"));
        if (!dev) continue;

        DeviceProps dp;
        parse_device_props_dict(dev, &dp);
        g_variant_unref(dev);

        if (!dp.address[0] || is_blacklisted(dp.address)) continue;

        if (!first) fprintf(f, ",\n");
        first = 0;

        fprintf(f, "    {\"mac\": \"%s\", \"name\": \"%s\", \"icon\": \"%s\", \"looks_like_pad\": %s",
            dp.address, dp.name, dp.icon,
            strncmp(dp.icon, "input-gaming", 12) == 0 ? "true" : "false");
        if (dp.has_rssi)
            fprintf(f, ", \"rssi\": %d", dp.rssi);
        fprintf(f, ", \"vendor\": \"%s\", \"paired\": %s, \"trusted\": %s, \"connected\": %s}",
            dp.vendor, dp.paired ? "true" : "false", dp.trusted ? "true" : "false",
            dp.connected ? "true" : "false");
    }

    fprintf(f, "%s  ]\n}\n", first ? "" : "\n");
    fclose(f);
    rename(tmp, BT_DISCOVERY_JSON);

    g_variant_unref(managed);
    g_variant_unref(result);
    g_free(prefix);
}

/* 페어링 탐색 중 처음 매칭된 후보 하나에만 고정 — 동일 물리 기기가 서로
 * 다른 MAC 2개로 동시에 광고되는 경우(2026-07-04 실기기에서 8BitDo SN30
 * Pro가 이런 걸로 확인됨) 여러 후보를 동시에 pair 시도하면 상태 메시지가
 * 뒤섞여서 실제로는 실패한 쪽의 "완료"가 찍히는 등 혼란이 생김. */
static char g_pairing_target[256] = "";
static int  g_connect_retries = 0;
#define MAX_CONNECT_RETRIES 5 /* Batocera doConnect()와 동일 — 컨트롤러 쪽이 첫 연결을 흘리는 경우가 있음 */

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

/* Connect()는 컨트롤러 쪽이 첫 시도를 흘리는 경우가 흔해서(Batocera 코드에도
 * 동일 재시도 로직 있음) 실패해도 바로 포기하지 않고 최대 5번 재시도 —
 * 성공하면 별도 처리 없이 리턴(다음 PropertiesChanged에서 Connected:true로
 * 자연스럽게 이어짐). */
static void on_connect_result(GObject *src, GAsyncResult *res, gpointer user_data);

static gboolean retry_connect_cb(gpointer user_data)
{
    char *obj_path = (char*)user_data;
    if (g_pairing_target[0] && strcmp(obj_path, g_pairing_target) == 0) {
        g_dbus_connection_call(g_conn, "org.bluez", obj_path, "org.bluez.Device1", "Connect",
            NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 15000, NULL, on_connect_result, g_strdup(obj_path));
    }
    g_free(obj_path);
    return G_SOURCE_REMOVE;
}

static void on_connect_result(GObject *src, GAsyncResult *res, gpointer user_data)
{
    char *obj_path = (char*)user_data;
    GError *err = NULL;
    GVariant *r = g_dbus_connection_call_finish(G_DBUS_CONNECTION(src), res, &err);
    if (r) { g_variant_unref(r); g_free(obj_path); return; } /* 성공 — PropertiesChanged가 이어서 처리 */

    g_connect_retries++;
    fprintf(stderr, "[rpui-bt] connect 실패(%d/%d): %s\n", g_connect_retries, MAX_CONNECT_RETRIES,
            err ? err->message : "?");

    if (g_connect_retries < MAX_CONNECT_RETRIES && g_pairing_target[0]
        && strcmp(obj_path, g_pairing_target) == 0) {
        char msg[256];
        snprintf(msg, sizeof(msg), "CONNECTING 재시도 %d/%d", g_connect_retries, MAX_CONNECT_RETRIES);
        write_pairing_status(msg);
        g_timeout_add(1000, retry_connect_cb, g_strdup(obj_path));
    } else {
        char msg[256];
        snprintf(msg, sizeof(msg), "실패: connect (%s)", err ? err->message : "?");
        write_pairing_status(msg);
        g_pairing_target[0] = '\0';
    }
    if (err) g_error_free(err);
    g_free(obj_path);
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
    /* g_pair_filter가 "*"이면 아이콘 무관하게 통과 — 사용자가 목록에서 수동으로
     * 고른 기기(PAIR_MAC)이므로 아이콘 필터링을 건너뛴다. */
    if (g_pair_filter[0] != '*' && (!dp.icon[0] || strncmp(dp.icon, g_pair_filter, strlen(g_pair_filter)) != 0)) return;

    if (!g_pairing_target[0]) {
        snprintf(g_pairing_target, sizeof(g_pairing_target), "%s", obj_path);
        g_connect_retries = 0;
    }

    const char *label = dp.name[0] ? dp.name : dp.address;

    if (dp.connected) {
        char msg[256];
        snprintf(msg, sizeof(msg), "CONNECTED %s (%s)", label, dp.address);
        write_pairing_status(msg);
        fprintf(stderr, "[rpui-bt] %s\n", msg);
        /* 세션을 여기서 바로 끝내지 않는다 — 8BitDo SN30 Pro 등 일부 패드는
         * 붙었다가 몇 초 뒤 스스로 끊기는 고질적 증상이 있어서(2026-07-05
         * 실기기 재확인: Connected 스냅샷을 찍고 세션을 끝내버린 직후 실제
         * 연결이 끊겼는데 아무도 재시도를 안 해서 방치됨), g_pair_filter와
         * g_pairing_target을 그대로 두고 계속 모니터링한다. 끊기면 다음
         * PropertiesChanged에서 이 함수가 다시 불려 trusted&&paired&&!connected
         * 분기로 자동 재연결을 시도한다. 최종 세션 종료는
         * on_discovery_timeout()의 타임아웃(또는 GUI가 scan-stop을 보낼 때)
         * 에서만 처리. */
        return;
    }

    /* Recalbox 소스의 알려진 우회책 순서 그대로 따름 — 페어링 전에 먼저
     * Trust부터 설정. 일부 게임패드(8BitDo SN30 Pro 등)는 이 순서가 아니면
     * 본딩 도중 스스로 연결을 끊음(HCI status 0x13, Remote User Terminated
     * Connection — 2026-07-04 실기기 bluetoothd -d 로그로 확인).
     * 참고: https://bbs.archlinux.org/viewtopic.php?pid=2193776#p2193776 */
    if (!dp.trusted) {
        char msg[256];
        snprintf(msg, sizeof(msg), "TRUSTING %s (%s)", label, dp.address);
        write_pairing_status(msg);
        g_dbus_connection_call(g_conn, "org.bluez", obj_path,
            "org.freedesktop.DBus.Properties", "Set",
            g_variant_new("(ssv)", "org.bluez.Device1", "Trusted", g_variant_new_boolean(TRUE)),
            NULL, G_DBUS_CALL_FLAGS_NONE, 5000, NULL, async_call_log, (gpointer)"trust");
        return;
    }

    if (!dp.paired) {
        char msg[256];
        snprintf(msg, sizeof(msg), "PAIRING %s (%s)", label, dp.address);
        write_pairing_status(msg);
        g_dbus_connection_call(g_conn, "org.bluez", obj_path, "org.bluez.Device1", "Pair",
            NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 15000, NULL, async_call_log, (gpointer)"pair");
        return;
    }

    /* trusted && paired && !connected */
    char msg[256];
    snprintf(msg, sizeof(msg), "CONNECTING %s (%s)", label, dp.address);
    write_pairing_status(msg);
    g_dbus_connection_call(g_conn, "org.bluez", obj_path, "org.bluez.Device1", "Connect",
        NULL, NULL, G_DBUS_CALL_FLAGS_NONE, 15000, NULL, on_connect_result, g_strdup(obj_path));
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
        if (g_pair_filter[0]) write_discovery_list();
    }
    g_variant_unref(interfaces);
}

static void on_properties_changed(GDBusConnection *conn, const gchar *sender, const gchar *object_path,
    const gchar *interface, const gchar *signal, GVariant *params, gpointer user_data)
{
    (void)conn; (void)sender; (void)interface; (void)signal; (void)user_data; (void)params;
    maybe_pair_device(object_path);
    if (g_pair_filter[0]) write_discovery_list();
}

/* ── 데몬: netlink 핫플러그 감지 (기존과 동일, 어댑터 설정만 D-Bus로) ── */

static void adapter_added(const char *hciname)
{
    for (int i = 0; i < g_nadapter; i++)
        if (strcmp(g_adapters[i], hciname) == 0) return;
    if (g_nadapter >= MAX_ADAPTERS) return;

    int was_empty = (g_nadapter == 0);
    strncpy(g_adapters[g_nadapter], hciname, sizeof(g_adapters[g_nadapter]) - 1);
    g_nadapter++;
    fprintf(stderr, "[rpui-bt] adapter added: %s\n", hciname);

    if (was_empty) {
        /* 첫 어댑터만 상위(primary)로 전원을 켬 — RF 간섭 방지(primary_adapter() 주석 참고) */
        configure_adapter(hciname);
    } else {
        fprintf(stderr, "[rpui-bt] %s는 보조 어댑터로 대기(전원 안 켬)\n", hciname);
    }
    write_status_json();
}

static int hci_name_cmp(const void *a, const void *b)
{
    return strcmp((const char*)a, (const char*)b);
}

/* /sys/class/bluetooth/ 스캔 순서(readdir)는 정렬 보장이 없어서, hci0가
 * 항상 먼저 primary로 잡히도록 이름순 정렬 후 추가한다. */
static void scan_existing_adapters(void)
{
    DIR *d = opendir("/sys/class/bluetooth");
    if (!d) return;

    char names[MAX_ADAPTERS][16];
    int n = 0;
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL && n < MAX_ADAPTERS) {
        if (strncmp(ent->d_name, "hci", 3) == 0)
            snprintf(names[n++], sizeof(names[0]), "%s", ent->d_name);
    }
    closedir(d);

    qsort(names, (size_t)n, sizeof(names[0]), hci_name_cmp);
    for (int i = 0; i < n; i++) adapter_added(names[i]);
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
                int was_primary = (i == 0);
                memmove(&g_adapters[i], &g_adapters[i+1],
                        sizeof(g_adapters[0]) * (size_t)(g_nadapter - i - 1));
                g_nadapter--;
                if (was_primary && g_nadapter > 0) {
                    fprintf(stderr, "[rpui-bt] %s를 새 상위 어댑터로 승격\n", g_adapters[0]);
                    configure_adapter(g_adapters[0]);
                }
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
        /* maybe_pair_device()가 CONNECTED 상태에서도 세션을 안 끝내고 계속
         * 모니터링하게 바뀌었으니(끊김 재발 시 자동 재연결 위해), 여기서
         * 최종적으로 실제 연결 상태를 한 번 더 확인해서 "TIMEOUT"이 실제로는
         * 연결돼 있는데도 잘못 뜨는 일이 없게 한다. */
        int actually_connected = 0;
        if (g_pairing_target[0]) {
            DeviceProps dp;
            if (get_device_props(g_pairing_target, &dp) && dp.connected) {
                char msg[256];
                snprintf(msg, sizeof(msg), "CONNECTED %s (%s)",
                         dp.name[0] ? dp.name : dp.address, dp.address);
                write_pairing_status(msg);
                actually_connected = 1;
            }
        }
        if (!actually_connected) {
            write_pairing_status("TIMEOUT");
            fprintf(stderr, "[rpui-bt] 페어링 탐색 시간 초과\n");
        }
        g_pair_filter[0] = '\0';
        g_pairing_target[0] = '\0';
        stop_discovery_all();
        write_discovery_list(); /* 빈 배열 — GUI에 스캔 종료 알림 */
    }
    return G_SOURCE_REMOVE;
}

/* maybe_pair_device()는 InterfacesAdded/PropertiesChanged 시그널에만 반응하는데,
 * 이미 BlueZ가 알고 있는 기기(예: 과거에 페어링됐다가 !Connected인 상태로
 * 남아있는 기기)는 다시 광고를 시작해도 "속성이 실제로 안 바뀌면" 시그널
 * 자체가 새로 안 올 수 있다 — 그러면 스캔을 시작해도 재연결이 영영 트리거
 * 안 됨(2026-07-04 실기기 확인: Paired=true인 8BitDo SN30 Pro가 재부팅 후
 * 다시 켜져도 데몬이 전혀 반응 안 하고 Connected=no로 계속 남음). 스캔 시작
 * 시점에 이미 알려진 기기들에 대해서도 한 번씩 강제로 maybe_pair_device()를
 * 호출해서 즉시 반응하도록 한다. */
static void kickstart_known_devices(void)
{
    const char *primary = primary_adapter();
    if (!primary) return;

    GError *err = NULL;
    GVariant *result = g_dbus_connection_call_sync(g_conn, "org.bluez", "/",
        "org.freedesktop.DBus.ObjectManager", "GetManagedObjects", NULL,
        G_VARIANT_TYPE("(a{oa{sa{sv}}})"), G_DBUS_CALL_FLAGS_NONE, 5000, NULL, &err);
    if (err) { g_error_free(err); return; }
    if (!result) return;

    char *prefix = g_strdup_printf("/org/bluez/%s/dev_", primary);
    GVariant *managed = g_variant_get_child_value(result, 0);

    GVariantIter iter;
    const gchar *obj_path;
    GVariant *interfaces;
    g_variant_iter_init(&iter, managed);
    while (g_variant_iter_loop(&iter, "{&o@a{sa{sv}}}", &obj_path, &interfaces)) {
        if (!g_str_has_prefix(obj_path, prefix)) continue;
        GVariant *dev = g_variant_lookup_value(interfaces, "org.bluez.Device1", G_VARIANT_TYPE("a{sv}"));
        if (!dev) continue;
        g_variant_unref(dev);
        maybe_pair_device(obj_path);
    }

    g_variant_unref(managed);
    g_variant_unref(result);
    g_free(prefix);
}

static void begin_pairing_search(const char *icon_filter)
{
    const char *primary = primary_adapter();
    if (!primary) { write_pairing_status("실패: 사용 가능한 BT 어댑터 없음"); return; }

    snprintf(g_pair_filter, sizeof(g_pair_filter), "%s", icon_filter);
    g_pairing_target[0] = '\0';
    write_pairing_status("SCANNING");
    write_discovery_list(); /* 빈 목록(또는 이미 알려진 기기)으로 초기화 */
    start_discovery_on(primary);
    kickstart_known_devices(); /* 이미 알려진 기기(재연결 대상) 즉시 확인 */
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
    else if (strcmp(line, "STOP") == 0) {
        g_pair_filter[0] = '\0';
        g_pairing_target[0] = '\0';
        stop_discovery_all();
        write_discovery_list();
        write_pairing_status("STOPPED");
    } else if (strncmp(line, "PAIR_MAC:", 9) == 0) {
        if (!g_pair_filter[0]) return G_SOURCE_CONTINUE; /* 활성 스캔 세션 중일 때만 유효 */

        char mac[64];
        snprintf(mac, sizeof(mac), "%s", line + 9);
        for (char *p = mac; *p; p++) *p = (char)toupper((unsigned char)*p);

        char obj_path[256];
        const char *primary = primary_adapter();
        if (!primary) return G_SOURCE_CONTINUE;
        snprintf(obj_path, sizeof(obj_path), "/org/bluez/%s/dev_", primary);
        size_t plen = strlen(obj_path);
        for (const char *p = mac; *p && plen + 1 < sizeof(obj_path); p++)
            obj_path[plen++] = (*p == ':') ? '_' : *p;
        obj_path[plen] = '\0';

        snprintf(g_pairing_target, sizeof(g_pairing_target), "%s", obj_path);
        snprintf(g_pair_filter, sizeof(g_pair_filter), "*");
        g_connect_retries = 0;
        maybe_pair_device(obj_path);
    }

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
        "사용법: rpui-bt <list|live_devices|trust-pad|trust-audio|"
        "scan-start-pad|scan-start-audio|scan-stop|pair <MAC>|remove <MAC>|remove-all|"
        "blacklist <MAC> [name]|unblacklist <MAC>>\n");
}

int main(int argc, char **argv)
{
    if (argc == 1) { run_daemon(); return 0; }

    if      (strcmp(argv[1], "list") == 0)         cli_list();
    else if (strcmp(argv[1], "live_devices") == 0) cli_live_devices();
    else if (strcmp(argv[1], "trust-pad") == 0)    cli_auto_trust("TRUST_PAD", "컨트롤러");
    else if (strcmp(argv[1], "trust-audio") == 0)  cli_auto_trust("TRUST_AUDIO", "오디오 장치");
    /* GUI 전용 non-blocking 트리거 — trust-pad/trust-audio는 블로킹 폴링이라
     * GUI 스레드에서 쓰기 부적합, 이건 명령만 전달하고 즉시 리턴한다. */
    else if (strcmp(argv[1], "scan-start-pad") == 0)   cli_write_cmd("TRUST_PAD");
    else if (strcmp(argv[1], "scan-start-audio") == 0) cli_write_cmd("TRUST_AUDIO");
    else if (strcmp(argv[1], "scan-stop") == 0)        cli_write_cmd("STOP");
    else if (strcmp(argv[1], "pair") == 0 && argc >= 3) {
        char cmd[64];
        snprintf(cmd, sizeof(cmd), "PAIR_MAC:%s", argv[2]);
        cli_write_cmd(cmd);
    }
    else if (strcmp(argv[1], "remove") == 0 && argc >= 3)      cli_remove(argv[2]);
    else if (strcmp(argv[1], "remove-all") == 0)               cli_remove_all();
    else if (strcmp(argv[1], "blacklist") == 0 && argc >= 3)   cli_blacklist(argv[2], argc >= 4 ? argv[3] : NULL);
    else if (strcmp(argv[1], "unblacklist") == 0 && argc >= 3) cli_unblacklist(argv[2]);
    else { usage(); return 1; }

    return 0;
}
