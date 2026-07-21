# libretro-core-organizer.mk(코어 24개 _VERSION/_SITE 중앙 관리, 2026-07-21)는
# package/*/*.mk 와일드카드에 안 걸리는 package/ 바로 밑 파일이라 별도로 include -
# 반드시 아래 패키지 wildcard include보다 먼저 와야 함. 패키지 .mk 안에서
# include하면 안 됨: Buildroot의 pkg-utils.mk가 패키지명을
# $(dir $(lastword $(MAKEFILE_LIST)))로 추론하는데, 패키지 파일 안에서 이 include를
# 하면 그 시점부터 파일 끝까지 "마지막 파일"이 organizer.mk(위치: package/ 바로
# 밑)로 고정돼 이후 $(eval $(generic-package))가 패키지명을 전부 "package"로
# 잘못 추론함 - 24개 코어가 전부 같은 이름으로 등록되려다 충돌(실기기 빌드로 실측).
include $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/libretro-core-organizer.mk

include $(sort $(wildcard $(BR2_EXTERNAL_C5_PANGUI_PATH)/package/*/*.mk))
