; 2026-07-08: byeoru(uim 한글 입력기)의 한/영 전환 기본 키는 "<Shift> "
; (Shift+Space)인데, 콘솔/curses 기반 프로그램(uim-fep, kmscon)에서는
; Shift+Space가 그냥 Space와 동일한 바이트로만 전달돼서(터미널이 modifier
; 상태를 얹은 별도 이스케이프 시퀀스를 안 보내는 한 구분 불가 - 실제로
; uim 사용자들 사이에 콘솔 환경에서 흔히 보고되는 문제) 전환이 안 됨.
; Ctrl+Space는 NUL(0x00) 제어 바이트로 확실히 구분되는 바이트를 만들어내서
; 콘솔 환경에서도 안정적으로 동작함을 실기기에서 확인 - 이 키로 교체.
(custom-set-value! (quote byeoru-on-key) (list "<Control> "))
(custom-set-value! (quote byeoru-latin-key) (list "<Control> "))
