; Christopher Di Bella <chrisdb>, Andrew Peacock <apeaNNN>, Myles Cook <mcooMMM>
;
; project.asm
; COMP2121 race car project implementation
;
; 26 May, 2014

.include "m64def.inc"

; -------------------- Registers --------------------
.def zero       = r2 ; can't be r0 because r1:r0 is used for multiplication
.def count      = r3
.def score_high = r4 ; low registers chosen because they will be less popular for frequent usage
.def score_low  = r5
.def row        = r6
.def column     = r7
.def mask       = r8
.def press      = r9
.def ten        = r10 ; r10 holds the value 10
.def temp       = r16
.def temp2      = r17
.def delay_high = r18
.def delay_low  = r19

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
    ammo: .byte 1

; -------------------- String data --------------------
    panel_row_0: .byte 8 ;"L:0 C:3|"
    racer_row_0: .byte 8 ; "C       "
    panel_row_1: .byte 8 ; "S:    0|"
    racer_row_1: .byte 8 ; "        "

; -------------------- Literals --------------------
.cseg
    .equ length = 16
    
    ; keypad bits
    .equ portd_dir        = 0xF0
    .equ init_column_mask = 0xEF
    .equ init_row_mask    = 0x01
    .equ row_mask         = 0x0F

    ; LCD protocol bits
    .equ lcd_rs = 3
    .equ lcd_rw = 1
    .equ lcd_e  = 2
    
    ; LCD functions
    .equ lcd_func_set  = 0b00110000
    .equ lcd_disp_off  = 0b00001000
    .equ lcd_disp_clr  = 0b00000001
    .equ lcd_disp_on   = 0b00001100
    .equ lcd_entry_set = 0b00000100
    .equ lcd_addr_set  = 0b10000000
    
    ; LCD function bits and constants
    .equ lcd_b  = 0
    .equ lcd_s  = 0
    .equ lcd_c  = 1
    .equ lcd_id = 1
    .equ lcd_f  = 2
    .equ lcd_n  = 3
    .equ lcd_bf = 7
    
    .equ lcd_line_1 = 0
    .equ lcd_line_2 = 0x40

; -------------------- Macros --------------------

; literally prints a new line
.macro print_newline
    rcall lcd_wait_busy
    ldi   data, lcd_addr_set | lcd_line_2
    rcall lcd_write_com                   ; move the insertion point to start of line 2
.endmacro ; print_newline

.macro print_data
print_data_loop:
    ld data, Z+                    ; read a character from the string
    rcall lcd_wait_busy
    rcall lcd_write_data            ; write the character to the screen
    dec count                       ; decrement character counter
    brne print_data_loop            ; loop again if there are more characters
.endmacro ; print_data

.macro ldi_low_reg
	push temp2
    ldi temp2, @1
    mov @0, temp2
	pop temp2
.endmacro ; ldi_low_reg

.macro cpi_low_reg
    mov temp2, @0
    cpi temp2, @1
.endmacro ; cpi_low_reg

.macro store_char
    ldi temp, @0
    st Z+, temp
.endmacro ; store_char

.macro store_string
    ldi ZL, low(@0)
    ldi ZH, high(@0)
    store_char @1
    store_char @2
    store_char @3
    store_char @4
    store_char @5
    store_char @6
    store_char @7
    store_char @8
.endmacro ; store_string

.macro on_top
    ldi ZL, low(not_top)
    ldi ZH, high(not_top)
    ld temp, Z

    cpi temp, 0
    brne bottom
    ldi ZL, low(racer_row_0)
    ldi ZH, high(racer_row_0)
    rjmp on_top_exit
bottom:
    ldi ZL, low(racer_row_1)
    ldi ZH, high(racer_row_1)
on_top_exit:
    nop
.endmacro ; on_top

; -------------------- Interrupts --------------------
jmp reset
jmp reset            ; irq0
jmp default          ; irq1
jmp default          ; irq2
jmp default          ; irq3
jmp default          ; irq4
jmp default          ; irq5
jmp default          ; irq6
jmp default          ; irq7
jmp default          ; timer2 compare
jmp default          ; timer2 overflow
jmp default          ; timer1 capture
jmp default          ; timer1 compare_a
jmp default          ; timer1 compare_b
jmp default          ; timer0 compare
jmp timer_0_prologue ; timer0 overflow

; Default
default: reti
; Reset
reset:
    ldi temp, 10
    mov ten, temp

    store_string panel_row_0, 'L', ':', '0', ' ', 'C', ':', '3', '|'
    store_string racer_row_0, 'C', ' ', ' ', '=', 'O', 'O', 'O', ' '
    store_string panel_row_1, 'S', ':', ' ', ' ', ' ', ' ', '0', '|'
    store_string racer_row_1, 208, ' ', ' ', ' ', ' ', '-', ' ', ' ' ; 208

    ; clear variables
    clr press
    clr zero
    
    ldi temp, low(RAMEND)
    out SPL,  temp
    ldi temp, high(RAMEND)
    out SPH,  temp
    
    ldi temp, portd_dir
    out DDRD, temp
    ser temp
    out DDRC, temp
    out PORTC, temp
    
    ldi ZL, low(not_top)
    ldi ZH, high(not_top)
    st Z, zero

    ldi ZL, low(position)
    ldi ZH, high(position)
    st Z, zero

	ldi ZL, low(ammo)
	ldi ZH, high(ammo)
	st Z, zero

	ldi ZL, low(lives)
	ldi ZH, high(lives)
	ldi temp, 3
	st Z, temp

    clr score_low
    clr score_high
	clr temp
    clr temp2

	clr XL
	clr XH
	clr YL
	clr YH
	clr ZL
	clr ZH

    jmp main

; timer_0 interrupt
timer_0_prologue:
    push r29        ; save conflict registers
    push r28
    in r24, SREG
    push r24
timer_0:
    ; counter must tick 3597 times to reach one second
    cpi counter, 97
    brne timer_0_not_second
    
    cpi counter2, 35
    brne timer_0_second_loop
    
timer_0_not_second:
    inc counter
    rjmp timer_0_epilogue
    
timer_0_second_loop:
    inc counter3
    cpi counter3, 100
    brne timer_0_epilogue
    inc counter2
    ldi counter3, 0

timer_0_epilogue:
    pop r24
    out SREG, r24
    pop r28
    reti

    
; ---------- Start of display core ----------

; Write a command to the LCD. data stores the value to be written
lcd_write_com:
    out PORTB, data
    clr temp
    out PORTA, temp
    nop ; a delay to meet timing
    sbi PORTA, lcd_e ; turn on enabling pin
    nop
    nop
    nop
    cbi PORTA, lcd_e
    nop
    nop
    nop
    ret

; Write a character to the LCD. data stores the value to be written
lcd_write_data:
    out PORTB, data         ; set the data port's value up
    ldi temp, 1 << lcd_rs
    out PORTA, temp         ; rs = 1, rw = 0 for a data write
    nop
    sbi PORTA, lcd_e
    nop
    nop
    nop
    cbi PORTA, lcd_e
    nop
    nop
    nop
    ret

; read the LCD busy flag until it reads as not busy
lcd_wait_busy:
    clr temp
    out DDRB, temp ; make PORTB an input port for now
    out PORTB, temp
    ldi temp, 1 << lcd_rw
    out PORTA, temp ; rs = 0, rw = 1 for a command port read
lcd_wait_busy_loop:
    nop
    sbi PORTA, lcd_e
    nop
    nop
    nop
    in temp, PINB
    cbi PORTA, lcd_e
    sbrc temp, lcd_bf       ; if the busy flag is set then
    rjmp lcd_wait_busy_loop ;    repeat the command read 
    clr temp                ; else
    out PORTA, temp         ;    turn off read mode
    ser temp
    out DDRB, temp ; make PORTD an output port
    ret
    
; delay function
delay:
    subi delay_low, 1
    sbci delay_high, 0
    nop
    nop
    nop
    brne delay
    ret
    
; initialises the LCD
lcd_init:
    ser temp
    out DDRB, temp ; PORTB is usually all output
    out DDRA, temp ; PORTA is the control port, and is always all outputs
    
    ; we wish to delay the output for 15ms
    ldi delay_low,  low(15000)
    ldi delay_high, high(15000)
    rcall delay
    
    ; set command with n = 1, and f = 0
    ldi data, lcd_func_set | (1 << lcd_n)
    rcall lcd_write_com ; function set command with 2 lines and 5*7 font
    
    ; delay for more than 4.1ms
    ldi delay_low, low(4100)
    ldi delay_high, high(4100)
    rcall delay 
    
    rcall lcd_write_com ; function set command with 2 lines and 5*7 font
    
    ; delay for about a microsecond
    ldi delay_low, low(100)
    ldi delay_high, high(100)
    rcall delay
    
    rcall lcd_write_com ; function set command with 2 lines and 5*7 font
    rcall lcd_write_com ; function set command with 2 lines and 5*7 font
    rcall lcd_wait_busy
    
    ; turn display off
    ldi data, lcd_disp_off
    rcall lcd_write_com
    rcall lcd_wait_busy     ; wait until the LCD is ready
    
    ; clear display
    ldi data, lcd_disp_clr
    rcall lcd_write_com
    rcall lcd_wait_busy     ; wait until lcd is ready
    
    ; entry set command with i/d = 1, and s = 0
    ldi data, lcd_entry_set | (1 << lcd_id)
    rcall lcd_write_com ; set entry mode; increment = yes; shift = no
    rcall lcd_wait_busy ; wait until lcd is ready
    
    ; display on command with c = 0, and b = 1
    ; turn display on without a blinking cursor
    ldi data, lcd_disp_on | (1 << lcd_c)
    rcall lcd_write_com
    ret
    
; -------------------- End of display core --------------------

; -------------------- Start of keypad code --------------------
key_press:
    ldi_low_reg mask, init_column_mask
    clr column
column_loop:
    out PORTD, mask
    ldi temp, 0xFF
    
keypad_delay:
    dec temp
    brne keypad_delay

    in temp, PIND
    andi temp, row_mask
    cpi temp, 0xF
    breq next_column

    ldi_low_reg mask, init_row_mask
    clr row
    
row_loop:
    mov temp2, temp
    and temp2, mask
    brne skip_conversion

    rcall convert
    ret
    
skip_conversion:
    inc row
    lsl mask
    jmp row_loop
    
next_column:
    cpi_low_reg column, 3
    breq poll_set
    sec
    rol mask
    inc column
    jmp column_loop

poll_set:
    ldi_low_reg press, 0
    out PORTB, press
    ret
    
convert:
    cpi_low_reg column, 3
    breq letters
    cpi_low_reg row, 3
    breq symbols
    mov temp, row
    lsl temp
    add temp, row
    add temp, column
    inc temp
    jmp poll_check
    
letters:
    ldi temp, 0xA
    add temp, row
    jmp poll_check
    
symbols:
    cpi_low_reg column, 1
    breq keypad_zero
    jmp poll_check
    
keypad_zero:
    clr temp

poll_check:
    cpi_low_reg press, 0
    breq keypad_poll_check_not_pressed
	ret
    
keypad_poll_check_not_pressed:
    ldi_low_reg press, 1
    
    cpi temp, 2
    breq keypad_up
    cpi temp, 4
    breq keypad_left
    cpi temp, 6
    breq keypad_right
    cpi temp, 8
    brne keypad_exit
    
    rcall keypad_down
    rjmp keypad_exit

keypad_up:
    ldi ZL, low(position)
    ldi ZH, high(position)
    ld temp2, Z

    ldi ZL, low(racer_row_0)
    ldi ZH, high(racer_row_0)
    add ZL, temp2
    adc ZH, zero
    
    rcall auto_collision_checking
    ldi temp, 'C'
    st Z, temp

    ldi ZL, low(racer_row_1)
    ldi ZH, high(racer_row_1)
    add ZL, temp2
    adc ZH, zero
    ldi temp, ' '
    st Z, temp

    ; set the 'not_top' flag to 0
    ldi ZL, low(not_top)
    ldi ZH, high(not_top)
    ldi temp, 0
    st Z, temp

    rjmp keypad_exit

keypad_left:
    ldi ZL, low(position)
    ldi ZH, high(position)
    ld temp2, Z

    cpi temp2, 0
    breq keypad_exit
    
    on_top

    add ZL, temp2
    adc ZH,zero
    ldi temp, ' '
    st Z, temp
    sbiw Z, 1
	rcall auto_collision_checking
    ldi temp, 'C'
    st Z, temp

    dec temp2
    ldi ZL, low(position)
    ldi ZH, high(position)
    st Z, temp2
    rjmp keypad_exit

keypad_exit:
    ret

keypad_right:
    ldi ZL, low(position)
    ldi ZH, high(position)
    ld temp2, Z

    cpi temp2, 7
    breq keypad_exit
    
    on_top

    add ZL, temp2
    adc ZH, zero
    ldi temp, ' '
    st Z+, temp
	rcall auto_collision_checking
    ldi temp, 'C'
    st Z, temp

    inc temp2
    ldi ZL, low(position)
    ldi ZH, high(position)
    st Z, temp2

    rjmp keypad_exit

keypad_down:
    ldi ZL, low(position)
    ldi ZH, high(position)
    ld temp2, Z

    ldi ZL, low(racer_row_1)
    ldi ZH, high(racer_row_1)

    add ZL, temp2
    adc ZH, zero
	rcall auto_collision_checking
    ldi temp, 'C'
    st Z, temp

    ldi ZL, low(racer_row_0)
    ldi ZH, high(racer_row_0)
    add ZL, temp2
    adc ZH, zero
    ldi temp, ' '
    st Z, temp

    ldi ZL, low(not_top)
    ldi ZH, high(not_top)
    ldi temp, 1
    st Z, temp

    ret
    
; -------------------- End of keypad code --------------------

; -------------------- Collision checking --------------------

; automatic collision checking checks if the car is about to drive into an obstacle or power-up when it moves straight
auto_collision_checking:
    push ZL
    push ZH
    push temp
	push temp2
    ld temp2, Z

    cpi temp2, 'O' ; O for obstacle
    breq obstacle_collision
    cpi temp2, 'S' ; S for powerup
    breq powerup_collision
    cpi temp2, '-'
    breq ammo_boost_1
    cpi temp2, '='
    breq ammo_boost_2
    cpi temp2, 208
    breq ammo_boost_3
    
    clr temp2

auto_collision_exit:
	pop temp2
    pop temp
    pop ZH
    pop ZL
    ret
    
obstacle_collision:
    ldi ZL, low(lives)
    ldi ZH, high(lives)
    ld temp, Z
    
    dec temp
    breq game_over
    
    st Z, temp
    
    ldi temp2, '0'
    add temp2, temp
    
    ldi ZL, low(panel_row_0)
    ldi ZH, high(panel_row_0)
    adiw Z, 6
    st Z, temp2
    
    ldi temp, 75
    out PORTE, temp
    
    rjmp auto_collision_exit
    
powerup_collision:
    ldi ZL, low(level)
    ldi ZH, high(level)
    ld temp, Z
    
    mul temp, ten
    add score_low, r1
    adc score_high, r0
    rjmp auto_collision_exit
    
ammo_boost_3:
    rcall ammo_load
    cpi temp2, 253
    brsh ammo_boost_2
    lsl temp2
    inc temp2
    lsl temp2
    inc temp2
    lsl temp2
    inc temp2
    rcall ammo_store
    rjmp auto_collision_exit
ammo_boost_2:
    rcall ammo_load
    cpi temp2, 254
    breq ammo_boost_1
    lsl temp2
    inc temp2
    lsl temp2
    inc temp2
    rcall ammo_store
    rjmp auto_collision_exit
ammo_boost_1:
    rcall ammo_load
    cpi temp2, 255
    breq auto_collision_exit
    lsl temp2
    inc temp2
    rcall ammo_store
    rjmp auto_collision_exit
    
ammo_load:
    ldi ZL, low(ammo)
    ldi ZH, high(ammo)
    ld temp2, Z
    ret
    
ammo_store:
    st Z, temp2
    out PORTC, temp2
    ret

game_over:
    store_string panel_row_0, 'G', 'a', 'm', 'e', ' ', 'o', 'v', 'e'
    store_string racer_row_0, 'r', '!', ' ', ' ', ' ', ' ', ' ', ' '
    store_string panel_row_1, 'S', 'c', 'o', 'r', 'e', ':', ' ', '6'
    store_string racer_row_1, '5', '5', '3', '5', ' ', ' ', ' ', ' '
    rcall lcd_init
    lsl count
    ldi ZL, low(panel_row_0)
    ldi ZH, high(panel_row_0)
    ldi_low_reg count, length
    print_data
    print_newline
    ldi_low_reg count, length
    print_data
    rcall lcd_wait_busy
temp_exit:
    rjmp temp_exit
;    rjmp auto_collision_exit
    
main:
    ldi_low_reg mask, init_column_mask
    clr column
    rcall lcd_init
    out TIMSK, temp          ; T/C0 interrupt enable
    lsl count
    ldi ZL, low(panel_row_0) ; point Y at the string
    ldi ZH, high(panel_row_0);recall that we must multiply any Program code label address
                                    ; by 2 to get the correct location
    ldi_low_reg count, length

    print_data
    print_newline
    ldi_low_reg count, length
    print_data
    rcall lcd_wait_busy
    
    rcall key_press
    
    ;out PORTC, score_low
    rjmp main