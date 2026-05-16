#include "gamepad_mapping.h"

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* ── 슬롯 히스토리 ──────────────────────────────────────────── */

#define MAX_HISTORY 16  /* 최대 기억 장치 수 (순환 덮어쓰기) */

typedef struct {
    SDL_JoystickGUID guid;
    int              slot;
    bool             valid;
} HistEntry;

static HistEntry s_history[MAX_HISTORY];
static char      s_cfg_path[256];

static HistEntry *find_history(SDL_JoystickGUID guid) {
    for (int i = 0; i < MAX_HISTORY; i++) {
        if (s_history[i].valid &&
            memcmp(&s_history[i].guid, &guid, sizeof(guid)) == 0)
            return &s_history[i];
    }
    return NULL;
}

int gp_map_preferred_slot(SDL_JoystickGUID guid) {
    const HistEntry *e = find_history(guid);
    return e ? e->slot : -1;
}

void gp_map_update_history(SDL_JoystickGUID guid, int slot) {
    HistEntry *e = find_history(guid);
    if (e) {
        e->slot = slot;
        return;
    }
    /* 빈 슬롯 찾기 */
    for (int i = 0; i < MAX_HISTORY; i++) {
        if (!s_history[i].valid) {
            s_history[i].guid  = guid;
            s_history[i].slot  = slot;
            s_history[i].valid = true;
            return;
        }
    }
    /* 꽉 찼으면 slot 0 덮어쓰기 (LRU 미구현, 단순화) */
    s_history[0].guid  = guid;
    s_history[0].slot  = slot;
    s_history[0].valid = true;
}

const char *gp_map_config_path(void) {
    return s_cfg_path[0] ? s_cfg_path : NULL;
}

/* ── 최소 JSON 파서 헬퍼 ─────────────────────────────────── */
/*
 * gamepad_config.json 구조:
 * {
 *   "slot_history": [
 *     { "slot": 0, "guid": "030000005e0400008e02000010010000" }
 *   ],
 *   "sdl_mappings": [
 *     "GUID,Name,platform:Linux,a:b0,..."
 *   ]
 * }
 *
 * 완전한 JSON 파서 없이 줄 단위로 처리.
 * 형식이 위와 같이 고정돼 있다고 가정.
 */

/* 문자열에서 JSON 문자열 값 추출: "key": "VALUE" → VALUE 복사 */
static bool extract_str(const char *line, const char *key, char *out, int outlen) {
    const char *p = strstr(line, key);
    if (!p) return false;
    p += strlen(key);
    p = strchr(p, '"');
    if (!p) return false;
    p++;
    const char *end = strchr(p, '"');
    if (!end) return false;
    int len = (int)(end - p);
    if (len >= outlen) len = outlen - 1;
    memcpy(out, p, len);
    out[len] = '\0';
    return true;
}

/* 문자열에서 JSON 정수 값 추출: "key": N */
static bool extract_int(const char *line, const char *key, int *out) {
    const char *p = strstr(line, key);
    if (!p) return false;
    p += strlen(key);
    p = strchr(p, ':');
    if (!p) return false;
    p++;
    while (*p == ' ') p++;
    *out = atoi(p);
    return true;
}

/* ── 로드 ────────────────────────────────────────────────── */
int gp_map_load(const char *cfg_path) {
    if (!cfg_path) return -1;

    FILE *f = fopen(cfg_path, "r");
    if (!f) return -1;

    SDL_strlcpy(s_cfg_path, cfg_path, sizeof(s_cfg_path));

    enum { SEC_NONE, SEC_HISTORY, SEC_MAPPINGS } section = SEC_NONE;

    /* slot_history 파싱용 임시 상태 */
    int  pending_slot = -1;
    char pending_guid[64] = {0};

    char line[512];
    while (fgets(line, sizeof(line), f)) {
        /* 섹션 진입 감지 */
        if (strstr(line, "\"slot_history\"")) {
            section = SEC_HISTORY;
            pending_slot = -1;
            pending_guid[0] = '\0';
            continue;
        }
        if (strstr(line, "\"sdl_mappings\"")) {
            section = SEC_MAPPINGS;
            continue;
        }

        if (section == SEC_HISTORY) {
            /* 객체 닫힘 → 레코드 확정 */
            if (strchr(line, '}')) {
                if (pending_slot >= 0 && pending_guid[0]) {
                    SDL_JoystickGUID guid =
                        SDL_JoystickGetGUIDFromString(pending_guid);
                    gp_map_update_history(guid, pending_slot);
                }
                pending_slot = -1;
                pending_guid[0] = '\0';
                continue;
            }
            /* 배열 끝 */
            if (strchr(line, ']')) {
                section = SEC_NONE;
                continue;
            }
            extract_int(line, "\"slot\"", &pending_slot);
            extract_str(line, "\"guid\"", pending_guid, sizeof(pending_guid));
        }

        if (section == SEC_MAPPINGS) {
            /* 배열 끝 */
            if (strchr(line, ']')) {
                section = SEC_NONE;
                continue;
            }
            /* 따옴표로 감싼 매핑 문자열 추출 */
            const char *start = strchr(line, '"');
            if (!start) continue;
            start++;
            const char *end = strrchr(start, '"');
            if (!end || end == start) continue;

            char mapping[512];
            int  len = (int)(end - start);
            if (len >= (int)sizeof(mapping)) len = (int)sizeof(mapping) - 1;
            memcpy(mapping, start, len);
            mapping[len] = '\0';

            if (mapping[0] && SDL_GameControllerAddMapping(mapping) < 0)
                SDL_Log("gamepad_mapping: 매핑 등록 실패: %s\n", SDL_GetError());
        }
    }

    fclose(f);
    return 0;
}

/* ── 저장 ────────────────────────────────────────────────── */
int gp_map_save(const char *cfg_path) {
    if (!cfg_path) cfg_path = s_cfg_path;
    if (!cfg_path || !cfg_path[0]) return -1;

    FILE *f = fopen(cfg_path, "w");
    if (!f) return -1;

    fprintf(f, "{\n");
    fprintf(f, "  \"slot_history\": [\n");

    bool first = true;
    for (int i = 0; i < MAX_HISTORY; i++) {
        if (!s_history[i].valid) continue;
        char guid_str[64];
        SDL_JoystickGetGUIDString(s_history[i].guid, guid_str, sizeof(guid_str));
        if (!first) fprintf(f, ",\n");
        fprintf(f, "    { \"slot\": %d, \"guid\": \"%s\" }",
                s_history[i].slot, guid_str);
        first = false;
    }
    fprintf(f, "\n  ],\n");

    /* sdl_mappings는 현재 세션에서 동적 추가한 항목만 기록.
     * 기존 gamecontrollerdb.txt에 있는 매핑은 재기록하지 않는다. */
    fprintf(f, "  \"sdl_mappings\": []\n");
    fprintf(f, "}\n");

    fclose(f);
    return 0;
}
