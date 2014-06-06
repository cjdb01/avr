; -------------------- Registers --------------------
.def zero = r2 ; can't be r0 because r1:r0 is used for multiplication
.def count = r3
.def score_low = r4
.def score_high = r5 ; low registers chosen because they will be less popular for frequent usage
.def row = r6
.def column = r7
.def mask = r8
.def press = r9
.def ten = r10 ; r10 holds the value 10
.def divN = R11 ; 8-bit-number to divide with
.def result_lo = R12 ; 16bit div result
.def result_hi = R13 ; 16bit div result
.def counter4 = r14 ; used for timer
.def temp = r16
.def temp2 = r17
.def delay_high = r18
.def delay_low = r19

.def data = r20
.def counter = r21
.def counter2 = r22
.def counter3 = r23

; -------------------- Globals --------------------
.dseg
    .org 0x100
    lives: .byte 1
    
    .org 0x101
    level: .byte 1

    .org 0x102
    not_top: .byte 1

    .org 0x103
    position: .byte 1

	.org 0x104
	rand: .byte 4

; -------------------- String data --------------------
    panel_row_0: .byte 8 ;"L:0 C:3|"
    racer_row_0: .byte 8 ; "C "
    panel_row_1: .byte 8 ; "S: 0|"
    racer_row_1: .byte 8 ; " "

; -------------------- Literals --------------------
.cseg
    .equ length = 16
    
	.equ RAND_A = 214013
	.equ RAND_C = 2531011

    ; keypad bits
    .equ portd_dir = 0xF0
    .equ init_column_mask = 0xEF
    .equ init_row_mask = 0x01
    .equ row_mask = 0x0F

    ; LCD protocol bits
    .equ lcd_rs = 3
    .equ lcd_rw = 1
    .equ lcd_e = 2
    
    ; LCD functions
    .equ lcd_func_set = 0b00110000
    .equ lcd_disp_off = 0b00001000
    .equ lcd_disp_clr = 0b00000001
    .equ lcd_disp_on = 0b00001100
    .equ lcd_entry_set = 0b00000100
    .equ lcd_addr_set = 0b10000000
    
    ; LCD function bits and constants
    .equ lcd_b = 0
    .equ lcd_s = 0
    .equ lcd_c = 1
    .equ lcd_id = 1
    .equ lcd_f = 2
    .equ lcd_n = 3
    .equ lcd_bf = 7
    
    .equ lcd_line_1 = 0
    .equ lcd_line_2 = 0x40


main:
    store_string panel_row_0, 'L', ':', '1', ' ', 'C', ':', '3', '|'
    store_string racer_row_0, 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'
    store_string panel_row_1, 'S', ':', ' ', ' ', ' ', ' ', '0', '|'
    store_string racer_row_1, 'O', 'O', 'O', 'O', 'O', 'O', 'O', 'O'
    rcall update
main_end:
    rjmp main_end

update:
    push temp
    push temp2
    push ten
    push ZL
    push ZH
    push YL
    push YH
    
    ldi ZL, low(racer_row_0)
    ldi ZH, high(racer_row_0)
    mov YL, ZL
    mov YH, ZH
    
    cpi temp, 'O'
    brne update_part_2
    rcall increase_points
    ldi temp, ' '
    st Z, temp
    
update_part_2:
    adiw Z, 1
    ld temp, Z
    ld temp2, Y
    
    cpi temp, 'O'
    brne update_part_3
    cpi temp2, 'C'
    brne update_part_3
    
    rcall obstacle_collision
    
update_part_3:
    cpi temp, 'S'
    brne update_part_5
    cpi temp2, 'C'
    brne update_part_4
    rcall powerboost
    
update_part_4:
    cpi count, 4
    brge update_part_5
    ldi temp, ' '
    st Z, temp
    
update_part_5:
    cpi temp, ' '
    breq update_part_6
    cpi temp, 'C'
    breq update_part_6
    st Y, temp
    ldi temp, ' '
    st Z, temp
    
update_part_6:
    inc count
    adiw Y, 1
    
    cpi count, 8
    brge update_part_7
    jmp update_part_2
    
update_part_7:
    cpi ten, 1
    breq update_epilogue
    clr count
    inc ten
    ldi ZL, low(racer_row_1)
    ldi ZH, high(racer_row_1)
    mov YL, ZL
    mov YH, ZH
    jmp update_part_2
    
update_epilogue:
    pop YH
    pop YL
    pop ZH
    pop ZL
    pop ten
    pop temp2
    pop temp
    ret
    
increase_points:
obstacle_collision:
powerboost:
    ret
