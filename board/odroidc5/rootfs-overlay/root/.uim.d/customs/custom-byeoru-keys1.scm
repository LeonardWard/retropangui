; 2026-07-08: byeoru(uim 한글 입력기)의 한/영 전환 기본 키는 "<Shift> "
; (Shift+Space)인데, 콘솔/curses 기반 프로그램(uim-fep, kmscon)에서는
; Shift+Space가 그냥 Space와 동일한 바이트로만 전달돼서(터미널이 modifier
; 상태를 얹은 별도 이스케이프 시퀀스를 안 보내는 한 구분 불가 - 실제로
; uim 사용자들 사이에 콘솔 환경에서 흔히 보고되는 문제) 전환이 안 됨.
; Ctrl+Space는 NUL(0x00) 제어 바이트로 확실히 구분되는 바이트를 만들어내서
; 콘솔 환경에서도 안정적으로 동작함을 실기기에서 확인 - 이 키로 교체.
; 오른쪽 Alt(Alt_R)와 실제 한/영 키(Hangul, 있는 키보드 한정)도 같은 동작을
; 하도록 중복 매핑 - uim은 한 액션에 여러 키를 리스트로 묶을 수 있음(기본값도
; 원래 "zenkaku-hankaku"와 "<Shift> " 두 개가 같이 묶여 있었음). 모디파이어
; 없는 단일 키는 꺾쇠 없이 키심 이름 그대로 씀(uim이 X11/XKB 키심 이름 규약을
; 그대로 씀 - kmscon도 libxkbcommon 기반이라 같은 규약).
(custom-set-value! (quote byeoru-on-key) (list "<Control> " "Alt_R" "Hangul"))
(custom-set-value! (quote byeoru-latin-key) (list "<Control> " "Alt_R" "Hangul"))
