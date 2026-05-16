/* gamepad_mapping.h — 커스텀 매핑 관리
 *
 * SDL GameController 매핑 문자열 형식을 그대로 사용.
 * gamepad_config.json의 "sdl_mappings" 항목을 SDL에 직접 등록하면
 * SDL이 자동으로 해당 GUID를 GC 장치로 인식한다.
 *
 * 슬롯 히스토리(GUID → 슬롯 번호 매핑)도 같은 파일에 저장.
 */
#pragma once

#include <SDL2/SDL.h>

/* cfg_path에서 JSON 로드:
 *   - "sdl_mappings" → SDL_GameControllerAddMapping() 일괄 등록
 *   - "slot_history" → 인메모리 테이블 복원
 * 반환: 0 성공, -1 파일 열기 실패 */
int  gp_map_load(const char *cfg_path);

/* 현재 슬롯 히스토리를 cfg_path에 JSON으로 저장.
 * 반환: 0 성공, -1 쓰기 실패 */
int  gp_map_save(const char *cfg_path);

/* 슬롯 히스토리 조회/갱신 (gamepad_slot.c에서 사용) */
int  gp_map_preferred_slot(SDL_JoystickGUID guid); /* -1 = 기록 없음 */
void gp_map_update_history(SDL_JoystickGUID guid, int slot);

/* 저장된 cfg_path 경로 반환 (gp_map_load 이후 유효) */
const char *gp_map_config_path(void);
