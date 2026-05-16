# PS1/PS2 USB 어댑터 아날로그 모드 유지를 위해 SDL HIDAPI 비활성화
# HIDAPI 사용 시 컨트롤러가 아날로그 모드를 잃고 오작동(Dim/버튼 오입력) 발생
export SDL_JOYSTICK_HIDAPI=0
