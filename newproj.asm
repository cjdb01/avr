; Christopher Di Bella <chrisdb>, Andrew Peacock <apea331>, Myles Cook <mdco436>
;
; project.asm
; COMP2121 race car project implementation
;
; 6 June, 2014

.include "m64def.inc"

; -------------------- Register definitions --------------------
.def mul_low     = r0  ; lsb of products
.def mul_high    = r1  ; msb of products
.def zero        = r2  ; can't be r0 because r1:r0 is used for multiplication
                       ; and zero should be constant most of the time
.def count       = r3  ; a counting variable
.def score_low   = r4  ; LSB of score
.def score_high  = r5  ; MSB of score
.def row         = r6  ; keypad row
.def column      = r7  ; keypad column
.def mask        = r8  ; keypad mask
.def press       = r9  ; keypad button pressed or not
.def ten         = r10 ; generally holds the value 10
.def divN        = r11 ; 8-bit number to divide with, also doubles as the remainder post-division
.def result_low  = r12 ; LSB of quotient
.def result_high = r13 ; MSB of quotient
.def seconds     = r14 ; holds the current number of seconds
; r15 not used
.def temp        = r16 ; a temporary register
.def temp2       = r17 ; a temporary register
.def delay_low   = r18 ; LSB of the delay
.def delay_high  = r19 ; MSB of the delay
.def data        = r20
.def counter     = r21 ; these are counters used by the timer
.def counter2    = r22
.def counter3    = r23

; -------------------- Globals --------------------
.dseg
    .org 0x100
    lives: .byte 1
    
    .org 0x101
    level: .byte 1
    
    .org 0x102
    top: .byte 1
    
    .org 0x103
    position: .byte 1
    
    .org 0x104
    rand: .byte 4
    
; -------------------- String data --------------------
    .org 0x108
    panel_row_0: .byte 8
    .org 0x110
    racer_row_0: .byte 9
    .org 0x119
    panel_row_1: .byte 8
    .org 0x121
    racer_row_1: .byte 9
    
; -------------------- Constants --------------------
.cseg
    .equ length = 16 ; string length
    
    ; random data
    .equ rand_a = 214013
    .equ rand_c = 2531011
    
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
    
; -------------------- Macros --------------------

; ldi doesn't work for registers below r16
; therefore we must make a macro that does this in one step
; 4 operations
.macro ldi_low_reg
    push temp
    ldi temp, @1
    mov @0, temp
    pop temp
.endmacro

; cpi doesn't work for registers below r16
; therefore we must make a macro that does this in one step
; 4 operations
.macro cpi_low_reg
    push temp
    mov temp, @0
    cpi temp, @1
    pop temp
.endmacro

; stores a character in memory
; 2 operations
; nothing is preserved
; assumes Z is initialised
.macro store_char
    ldi temp, @0
    st Z+, temp
.endmacro

; stores 8 characters in memory
; relies on store_char
; nothing is preserved
; initialises Z
; 18 operations
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
.endmacro

; -------------------- Interrupts --------------------
jmp reset

jmp Default ; IRQ0 Handler
jmp Default ; IRQ1 Handler
jmp Default ; IRQ2 Handler
jmp Default ; IRQ3 Handler
jmp Default ; IRQ4 Handler
jmp Default ; IRQ5 Handler
jmp Default ; IRQ6 Handler
jmp Default ; IRQ7 Handler
jmp Default ; Timer2 Compare Handler
jmp Default ; Timer2 Overflow Handler
jmp Default ; Timer1 Capture Handler
jmp Default ; Timer1 CompareA Handler
jmp Default ; Timer1 CompareB Handler
jmp Default ; Timer1 Overflow Handler
jmp Default ; Timer0 Compare Handler
jmp timer_0_prologue ; Timer0 Overflow Handler

default:
    reti
    
; -------------------- Timer 0 --------------------
; timer_0 interrupt
timer_0_prologue:
    push r29 ; save conflict registers
    push r28
    in r24, SREG
    push r24
timer_0:
    ; counter must tick 3597 times to reach one second
    cpi counter, 97
    brne timer_0_not_second
    
    cpi counter2, 10
    brne timer_0_second_loop
    
    rcall update ; every second, update

    ldi_low_reg counter,0 ; clear counter value after 3597 interrupts gives us one second
    ldi_low_reg counter2,0
    ldi_low_reg counter3,0

    cpi_low_reg seconds,30 ; every 30 seconds
    brlt timer_0_counter30 ; if seconds < 30
    
    rcall level_up

    ldi_low_reg seconds, 0
    rjmp timer_0_epilogue

timer_0_not_second:
    inc counter
    rjmp timer_0_epilogue
    
timer_0_second_loop:
    inc counter3
    cpi counter3, 100
    brne timer_0_epilogue
    inc counter2
    ldi counter3, 0

timer_0_counter30:
    inc seconds

timer_0_epilogue:
    pop r24
    out SREG, r24
    pop r28
	pop r29
    reti
    
; -------------------- Display code --------------------
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
    out PORTB, data ; set the data port's value up
    ldi temp, 1 << lcd_rs
    out PORTA, temp ; rs = 1, rw = 0 for a data write
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
    sbrc temp, lcd_bf ; if the busy flag is set then
    rjmp lcd_wait_busy_loop ; repeat the command read
    clr temp ; else
    out PORTA, temp ; turn off read mode
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
    ldi delay_low, low(15000)
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
    rcall lcd_wait_busy ; wait until the LCD is ready
    
    ; clear display
    ldi data, lcd_disp_clr
    rcall lcd_write_com
    rcall lcd_wait_busy ; wait until lcd is ready
    
    ; entry set command with i/d = 1, and s = 0
    ldi data, lcd_entry_set | (1 << lcd_id)
    rcall lcd_write_com ; set entry mode; increment = yes; shift = no
    rcall lcd_wait_busy ; wait until lcd is ready
    
    ; display on command with c = 0, and b = 1
    ; turn display on without a blinking cursor
    ldi data, lcd_disp_on | (1 << lcd_c)
    rcall lcd_write_com
    ret
    
; -------------------- Keypad code --------------------
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
    
    ; arrow keys are represented by the numbers 2, 4, 6, 8
    cpi temp, 2
    breq keypad_up
    cpi temp, 4
    breq keypad_left
    cpi temp, 6
    breq keypad_right
    cpi temp, 8
    breq keypad_down
    
    rjmp keypad_exit

keypad_up:
    ; check if the car is in the top row
    ; if it is, do nothing!
    ldi ZL, low(top)
    ldi ZH, high(top)
    ld temp, Z
    cpi temp, 1
    breq keypad_exit
    ldi temp2, 17 ; to move down is 17 characters away
    rcall move_vertical
    rjmp keypad_exit
    
keypad_left:
    ldi ZL, low(position)
    ldi ZH, high(position)
    ld temp, Z
    cpi temp, 0
    breq keypad_exit
    ldi temp2, 1
    rcall move_horisontal
    rjmp keypad_exit
    
keypad_right:
    ldi ZL, low(position)
    ldi ZH, high(position)
    ld temp, Z
    cpi temp, 7
    breq keypad_exit
    ldi temp2, -1
    rcall move_horisontal
    rjmp keypad_exit
    
keypad_down:
    ldi ZL, low(top)
    ldi ZH, high(top)
    ld temp, Z
    cpi temp, 0
    breq keypad_exit
    ldi temp2, -17
    rcall move_vertical
    rjmp keypad_exit
    
keypad_exit:
    ret

; -------------------- Set up code --------------------
reset:
    ; set up the stack
    ldi temp, low(RAMEND)
    out SPL, temp
    ldi temp, high(RAMEND)
    out SPH, temp
    
    ; set the output
    ldi temp, portd_dir
    out DDRD, temp
    ser temp
    out DDRC, temp
    
    ; set lives to 3
    ldi ZL, low(lives)
    ldi ZH, high(lives)
    ldi temp, 3
    st Z, temp
    
    ; set the level to 1
    ldi ZL, low(level)
    ldi ZH, high(level)
    ldi temp, 1
    st Z, temp
    
    ; set the car to be on top
    ldi ZL, low(top)
    ldi ZH, high(top)
    st Z, temp
    
    ; set the position to 0
    ldi ZL, low(position)
    ldi ZH, high(position)
    clr temp
    st Z, temp
    
    ; store the important strings
    store_string panel_row_0, 'L', ':', '1', ' ', 'C', ':', '3', '|'
    store_string racer_row_0, 'C', ' ', ' ', ' ', ' ', ' ', ' ', ' '
    store_char 0 ; null char useful for updates
    store_string panel_row_1, 'S', ':', ' ', ' ', ' ', ' ', '0', '|'
    store_string racer_row_1, ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
    store_char 0 ; null char useful for updates
    
    ; clear all registers
    clr zero
    clr count
    clr score_low
    clr score_high
    clr row
    clr column
    clr mask
    clr press
    ldi_low_reg ten, 10
    clr divN
    clr result_low
    clr result_high
    clr seconds
    clr temp
    clr temp2
    clr delay_low
    clr delay_high
    clr data
    clr counter
    clr counter2
    clr counter3
    clr XL
    clr XH
    clr YL
    clr YH
    clr ZL
    clr ZH
    
    ; set up timers
    ldi temp, 0b00000011
    out TCCR0, temp      ; Prescaling value=8 ;256*8/7.3728( Frequency of the clock 7.3728MHz, for the overflow it should go for 256 times)
    ldi temp, 1<<TOIE0   ; =278 microseconds
    out TIMSK, temp      ; T/C0 interrupt enable
    sei
    
    ; get the random seed
    rcall InitRandom

; -------------------- main --------------------
main:
    ldi_low_reg mask, init_column_mask
    clr column
    rcall lcd_init
    lsl count
    
    ; load the data to be printed
    ldi ZL, low(panel_row_0)
    ldi ZH, high(panel_row_0)
    
    ; convert score from int to string
    rcall itoa
    
    ; print to screen
    ldi_low_reg count, length
    rcall print_data
    rcall print_newline
    ; don't forget the null char!
    adiw Z, 1
    
    ; print line 2, null char can be ignored here
    ldi_low_reg count, length
    rcall print_data
    rcall lcd_wait_busy
    
    ; get user input
    rcall key_press
    
    ; output the current score
    out PORTC, score_low
    
    ; and repeat
    rjmp main

; -------------------- Functions --------------------
print_newline:
    rcall lcd_wait_busy
    ldi data, lcd_addr_set | lcd_line_2
    rcall lcd_write_com
    ret
    
print_data:
    ld data, Z+
    rcall lcd_wait_busy
    rcall lcd_write_data
    dec count
    brne print_data
    ret

; checks if the car is in the top row or the bottom row
; and loads the racetrack lane that the car is in into
; memory
on_top:
    ; prologue
    push temp
    
    ; body
    ldi ZL, low(top)
    ldi ZH, high(top)
    ld temp, Z
    
    ; top is 1 if the car is in racer_row_0
    cpi temp, 0
    breq on_bottom
    
    ; car is in top row
    ldi ZL, low(racer_row_0)
    ldi ZH, high(racer_row_0)
    rjmp on_top_epilogue
on_bottom:
    ldi ZL, low(racer_row_1)
    ldi ZH, high(racer_row_1)
on_top_epilogue:
    pop temp
    ret
    
; increases the level by 1
level_up:
    push temp
    push ZL
    push ZH
    ldi ZL, low(level)
    ldi ZH, high(level)
    ld temp, Z
    inc temp
    st Z, temp
    pop ZH
    pop ZL
    pop temp
    ret

; moves the car vertically
; direction dictated by temp2
move_vertical:
    ldi ZL, low(position)
    ldi ZH, high(position)
    ldi temp, ' '
    st Z, temp

    cpi temp2, 0
    brge move_vertical_up
    sbiw Z, 30
    rjmp move_vertical_store
move_vertical_up:
    adiw Z, 30
move_vertical_store:
    ; find out if we're going to drive into something and resolve accordingly
    ;rcall collision_check
    ldi temp, 'C'
    st Z, temp
    ret
    
; moves the car horisontally
; direction dictated by temp2
move_horisontal:
    ; get the distance from the start of the lane
    ldi ZL, low(position)
    ldi ZH, high(position)
    ld temp, Z
    add temp, temp2 ; move the position, then store it
    st Z, temp
    sub temp, temp2
    
    ; have Z pointing to the start of the
    ; lane the car is in
    rcall on_top
    ; move the to the car's actual position
    add ZL, temp
    adc ZH, zero
    
    ; prepare to shift the car (let it move halfway)
    ldi temp, ' '
    st Z, temp
    
    ; shift the Z pointer accordingly
    add ZL, temp2
    adc ZH, temp2
    
    ; find out if we're going to drive into something and resolve accordingly
    rcall collision_check
    ldi temp, 'C'
    st Z, temp
    ret
    
; checks if the car is about to drive into an obstacle or a power up and resolves accordingly
collision_check:
    ; prologue
    push ZL
    push ZH
    push temp
    push temp2
    
    
    ;body
    ; get what's currently being pointed to in memory
    ld temp, Z
    
    cpi temp, 'O' ; O for obstacle
    breq check_obstacle_collision
    cpi temp, 'S' ; S for default_powerup
    breq check_default_powerup_collision
check_obstacle_collision:
    rcall resolve_obstacle_collision
    rjmp collision_check_epilogue

check_default_powerup_collision:
    rcall resolve_default_powerup_collision

collision_check_epilogue:
    pop temp2
    pop temp
    pop ZH
    pop ZL

; resolves what happens if we crash into an obstacle
resolve_obstacle_collision:
    ldi ZL, low(lives)
    ldi ZH, high(lives)
    ld temp, Z
    
    ; decrement lives
    ; if lives == 0, game over!
    dec temp
    brne resolve_obstacle_collision_part_2
    rcall game_over
    
resolve_obstacle_collision_part_2:
    st Z, temp
    
    ; store the lives in memory as an ascii value
    ldi temp2, '0'
    add temp, temp2
    
    ldi ZL, low(panel_row_0)
    ldi ZH, high(panel_row_0)
    adiw Z, 6
    st Z, temp2
    
    ; run the motor
    ldi temp, 75
    out PORTE, temp
    rcall reset_level
    ret

; resolves what happens if we drive into a default powerup
resolve_default_powerup_collision:
    ; get the level
    ldi ZL, low(level)
    ldi ZH, high(level)
    ld temp, Z
    
    ; default powerup: socre += 10 * level
    mul temp, ten
    add score_low, mul_low
    adc score_high, mul_high
    
    ret
    
game_over:
    store_string panel_row_0, 'G', 'a', 'm', 'e', ' ', 'o', 'v', 'e'
    store_string racer_row_0, 'r', '!', ' ', ' ', ' ', ' ', ' ', ' '
    store_char 0 ; mustn't forget the null char!
    
    ; preserve the ascii score!
    ; pushes it on to the stack, to be retrieved later
    adiw Z, 2
    clr temp2
game_over_score_preservation:
    cpi temp2, 6
    breq game_over_part_2
    ld temp, Z
    push temp
    rjmp game_over_score_preservation
    
game_over_part_2:
    store_string panel_row_1, 'S', 'c', 'o', 'r', 'e', ':', ' ', ' '
    store_string racer_row_1, ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
    store_char 0
    
    ; pop the score off
    sbiw Z, 5
    ldi temp2, 6
game_over_score_restoration:
    pop temp
    st -Z, temp
    dec temp2
    brne game_over_score_restoration
    
    ; game over now!
    ; wait until something is done
game_over_end:
    rjmp game_over_end
    ret

; takes an integer and converts it to a string    
itoa:
    ; prologue
    push temp
    push score_low
    push score_high
    push result_low
    push result_high
    
    ; body
    ldi XL, low(panel_row_1)
    ldi XH, high(panel_row_1)
    adiw XL:XH, 7 ; move data pointer 6 chars to the right
    
    ; handle zero explicitly, otherwise empty string is printed for 0
    cpi_low_reg score_high, 0
    brne itoa_loop
    cpi_low_reg score_low, 0
    brne itoa_loop
    ldi temp, '0'
    st -X, temp
    
    rjmp itoa_epilogue
    
itoa_loop: ; while (num != 0)
    cpi_low_reg score_low, 0 ; if num < 1, break
    brne itoa_after_check
    cpi_low_reg score_high, 1
    brlt itoa_epilogue
    
itoa_after_check:
    rcall bigNumDiv
    
    ldi temp, '0'
    add divN, temp
    st -X, divN
    
    movw score_high:score_low, result_high:result_low
    
    rjmp itoa_loop
    
itoa_epilogue:
    pop result_high
    pop result_low
    pop score_high
    pop score_low
    pop temp
    ret
    
; divides a 16-bit number by an 8-bit number
; code from http://www.avr-asm-tutorial.net/avr_en/calc/DIV8E.html
bigNumDiv:
    push score_low
    push score_high
    push temp
    clr divN
    push temp2
    mov divN,ten
; Divide score_high:score_low by divN
div8:
    clr temp ; clear temp register
    clr result_high ; clear result (the result registers
    clr result_low ; are also used to score_high to 16 for the
    inc result_low ; division steps, is set to 1 at start)
; Start Div loop
div8a:
    clc ; clear carry-bit
    rol score_low ; rotate the next-upper bit of the number
    rol score_high ; to the interim register (multiply by 2)
    rol temp
    brcs div8b ; a one has rolled left, so subtract
    cp temp,divN ; Division result 1 or 0?
    brcs div8c ; jump over subtraction, if smaller
div8b:
    sub temp,divN; subtract number to divide with
    sec ; set carry-bit, result is a 1
    rjmp div8d ; jump to shift of the result bit
div8c:
    clc ; clear carry-bit, resulting bit is a 0
div8d:
    rol result_low ; rotate carry-bit into result registers
    rol result_high
    brcc div8a ; as long as score_low rotate out of the result
     ; registers: go on with the division loop
endBigNumDiv:
    mov divN, temp

    ;Grab result before the pops!
    pop temp2
    pop temp
    pop score_high
    pop score_low
    
    ret
    
; updates the game
update:
    ret

; resets the level
reset_level:
	ret
    
; random code provided by CSE
InitRandom:
    push r16 ; save conflict register

    in r16, TCNT1L ; Create random seed from time of timer 1
    sts RAND,r16
    sts RAND+2,r16
    in r16,TCNT1H
    sts RAND+1, r16
    sts RAND+3, r16

    pop r16 ; restore conflict register
    ret

GetRandom:
    push r0 ; save conflict registers
    push r1
    push r17
    push r18
    push r19
    push r20
    push r21
    push r22

    clr r22 ; remains zero throughout

    ldi r16, low(RAND_C) ; set original value to be equal to C
    ldi r17, BYTE2(RAND_C)
    ldi r18, BYTE3(RAND_C)
    ldi r19, BYTE4(RAND_C)

    ; calculate A*X + C where X is previous random number.  A is 3 bytes.
    lds r20, RAND
    ldi r21, low(RAND_A)
    mul r20, r21 ; low byte of X * low byte of A
    add r16, r0
    adc r17, r1
    adc r18, r22

    ldi r21, byte2(RAND_A)
    mul r20, r21  ; low byte of X * middle byte of A
    add r17, r0
    adc r18, r1
    adc r19, r22

    ldi r21, byte3(RAND_A)
    mul r20, r21  ; low byte of X * high byte of A
    add r18, r0
    adc r19, r1

    lds r20, RAND+1
    ldi r21, low(RAND_A)
    mul r20, r21  ; byte 2 of X * low byte of A
    add r17, r0
    adc r18, r1
    adc r19, r22

    ldi r21, byte2(RAND_A)
    mul r20, r21  ; byte 2 of X * middle byte of A
    add r18, r0
    adc r19, r1

    ldi r21, byte3(RAND_A)
    mul r20, r21  ; byte 2 of X * high byte of A
    add r19, r0

    lds r20, RAND+2
    ldi r21, low(RAND_A)
    mul r20, r21  ; byte 3 of X * low byte of A
    add r18, r0
    adc r19, r1

    ldi r21, byte2(RAND_A)
    mul r20, r21  ; byte 2 of X * middle byte of A
    add r19, r0

    lds r20, RAND+3
    ldi r21, low(RAND_A)	
    mul r20, r21  ; byte 3 of X * low byte of A
    add r19, r0

    sts RAND, r16 ; store random number
    sts RAND+1, r17
    sts RAND+2, r18
    sts RAND+3, r19

    mov r16, r19  ; prepare result (bits 30-23 of random number X)
    lsl r18
    rol r16

    pop r22 ; restore conflict registers
    pop r21 
    pop r20
    pop r19
    pop r18
    pop r17
    pop r1
    pop r0
    ret
