; Christopher Di Bella <chrisdb>, Andrew Peacock <apeaNNN>, Myles Cook <mdco436>
;
; project.asm
; COMP2121 race car project implementation
;
; 26 May, 2014

.include "m64def.inc"

; -------------------- Registers --------------------
.def zero       = r2 ; can't be r0 because r1:r0 is used for multiplication
.def count      = r3
.def score_low  = r4
.def score_high = r5 ; low registers chosen because they will be less popular for frequent usage
.def row        = r6
.def column     = r7
.def mask       = r8
.def press      = r9
.def ten        = r10 ; r10 holds the value 10
.def divN = R11 ; 8-bit-number to divide with
.def result_lo = R12 ; 16bit div result
.def result_hi = R13 ; 16bit div result
.def counter4 = r14   ; used for timer
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
    push temp2
    mov temp2, @0
    cpi temp2, @1
    pop temp2
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

.macro get_points
    ld temp, Z

    cpi temp, 'O'
    breq get_points2
    jmp update_shift
get_points2:
    ldi temp, ' '
    st Z, temp
    adiw Z, 1
    push ZL
    push ZH
    ldi ZL, low(level)
    ldi ZH, high(level)
    ld temp2, Z
    add score_low, temp2
    adc score_high, zero
    pop ZH
    pop ZL
.endmacro

; -------------------- Interrupts --------------------
jmp RESET

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
jmp timer_0_prologue  ; Timer0 Overflow Handler

; Default
default: reti
; Reset
reset:
    ldi temp, 10
    mov ten, temp

    store_string panel_row_0, 'L', ':', '1', ' ', 'C', ':', '3', '|'
    store_string racer_row_0, 'C', 'S', 'S', 'S', 'S', 'S', 'S', 'S'
    store_string panel_row_1, 'S', ':', ' ', ' ', ' ', ' ', '0', '|'
    store_string racer_row_1, 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S'

    ; clear variables
    clr press
    clr zero
    clr r15

    ldi_low_reg counter,0            
    ldi_low_reg counter2,0
    ldi_low_reg counter3,0
    ldi_low_reg counter4,0
    
    ldi temp, low(RAMEND)
    out SPL,  temp
    ldi temp, high(RAMEND)
    out SPH,  temp
    
    ldi temp, portd_dir
    out DDRD, temp
    ser temp
    out DDRC, temp
    ;out PORTC, temp
    
    ldi ZL, low(not_top)
    ldi ZH, high(not_top)
    st Z, zero

    ldi ZL, low(position)
    ldi ZH, high(position)
    st Z, zero

    ldi ZL, low(lives)
    ldi ZH, high(lives)
    ldi temp, 3
    st Z, temp

    ldi ZL, low(level)
    ldi ZH, high(level)
    ldi temp, 1
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

    ldi temp, 0b00000011     ; 
    out TCCR0, temp          ; Prescaling value=8  ;256*8/7.3728( Frequency of the clock 7.3728MHz, for the overflow it should go for 256 times)
    ldi temp, 1<<TOIE0       ; =278 microseconds
    out TIMSK, temp          ; T/C0 interrupt enable
    sei

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
    
    rcall update         ; every second, update

    ldi_low_reg counter,0    ; clear counter value after 3597 interrupts gives us one second
    ldi_low_reg counter2,0
    ldi_low_reg counter3,0

    cpi_low_reg counter4,30             ; every 30 seconds
    brlt timer_0_counter30              ; if counter4 < 30
    
    cpi_low_reg counter4,31             ; display for 3 seconds, then reset
    brge timer_0_game_over_sleep              ; if counter4 > 30 

    rcall NEXT_LEVEL

    ldi_low_reg counter4, 0
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
    inc counter4
    rjmp timer_0_epilogue

timer_0_game_over_sleep:
    inc counter4
    cpi_low_reg counter4, 35
    brne timer_0_epilogue
    ldi_low_reg r15, 1

timer_0_epilogue:
    pop r24
    out SREG, r24
    pop r28
    reti

;========MOVE THIS TO THE CORRECT LOCATION WHEN COMPLETE======
NEXT_LEVEL:

ret
;========MOVE THIS TO THE CORRECT LOCATION WHEN COMPLETE======
    
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
    
    cpi temp, 0xA
    breq oopdate
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

oopdate:
    rcall update

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
    rcall reset_level
    rjmp auto_collision_exit
    
powerup_collision:
    ldi ZL, low(level)
    ldi ZH, high(level)
    ld temp, Z
    
    mul temp, ten
    add score_low, r0
    adc score_high, r1
    rjmp auto_collision_exit

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

    ldi_low_reg counter4, 31     ; after 3 seconds, rjmp to reset
    ret
;    rjmp auto_collision_exit
    
main:
    ldi_low_reg mask, init_column_mask
    clr column
    rcall lcd_init
    ;out TIMSK, temp          ; T/C0 interrupt enable
    lsl count
    ldi ZL, low(panel_row_0) ; point Y at the string
    ldi ZH, high(panel_row_0);recall that we must multiply any Program code label address
                                      ; by 2 to get the correct location
                                      
    cpi_low_reg r15, 1
    brne main2
    jmp reset
main2:
    rcall itoa_function
    ldi_low_reg count, length

    print_data
    print_newline
    ldi_low_reg count, length
    print_data
    rcall lcd_wait_busy

    rcall key_press
    out PORTC, score_low
    out PORTE, score_high
    rjmp main

; =============================
; ============itoa=============
; =============================


itoa_function:
prologue:
    push temp
    push score_low
    push score_high
    push result_lo
    push result_hi

itoa_core:
ldi XH, high(panel_row_1)
ldi XL, low(panel_row_1)
adiw XL:XH, 7 ; move data pointer 6 chars to the right

;ldi_low_reg TEN, LOW(10)

; Handle 0 explicitely, otherwise empty string is printed for 0
CPI_low_reg score_high, 0
brne loop2
CPI_low_reg score_low, 0
brne loop2
ldi temp, '0'
st -X, temp
rjmp exit

loop2: ;     while (num != 0)

    CPI_low_reg score_low, 0                     ; if num < 1, break
    brne after_check
    CPI_low_reg score_high, 1
    BRLT exit

after_check:
    rcall bigNumDiv

    
    ldi temp, '0'
    add divN, temp
    st -X, divN

    movw score_high:score_low, result_hi:result_lo

    rjmp loop2

exit:
    ;ldi temp, 0      ;     str[i] = '\0'; // Append string terminator
    ;st -X, temp
epilogue:
    pop result_hi
    pop result_lo
    pop score_high
    pop score_low
    pop temp
    ret


;=============DIV16===========

;.DEF LSB = R2 ; LeastSigBit 16-bit-number to be divided = score_low - R6
;.DEF MSB = R3 ; MostSigBit 16-bit-number to be divided = score_high - R7
;.DEF temp = R4 ; interim register = temp - R16
;.DEF loader = R8; multipurpose register for loading = temp2 - R17

bigNumDiv:

push score_low
push score_high
push temp
;push divN
clr divN
push temp2

    ;ldi temp2,0x00 ; LestSigBit to be divided
    ;mov score_high,temp2
    ;ldi temp2, 0x00 ; MostSigBit to be divided
    ;mov score_low,temp2
    ldi temp2,0x0A ; 8 bit num to be divided with
    mov divN,temp2
; Divide score_high:score_low by divN
div8:
    clr temp ; clear temp register
    clr result_hi ; clear result (the result registers
    clr result_lo ; are also used to score_high to 16 for the
    inc result_lo ; division steps, is set to 1 at start)
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
    rol result_lo ; rotate carry-bit into result registers
    rol result_hi
    brcc div8a ; as long as score_low rotate out of the result
     ; registers: go on with the division loop
endBigNumDiv:
    mov divN, temp

    ;Grab result before the pops!
    pop temp2
    ;pop result_hi
    ;pop result_lo
    ;pop divN
    pop temp
    pop score_high
    pop score_low
    
    ret


update:
    push temp
    push temp2
    ldi ZL, low(racer_row_0)
    ldi ZH, high(racer_row_0)
    
    get_points
    clr count
update_shift:
    ld temp, Z+
    cpi temp, 'O'
    breq update_shift_obstacle
    cpi temp, 'S'
    breq update_shift_powerup
    rjmp update_shift_condition

update_shift_obstacle:
    ld temp2, Z
    sbiw Z, 2
    push temp
    ld temp, Z
    cpi temp, 'C'
    brne update_shift_obstacle2
    jmp life_loss
update_shift_obstacle2:
    pop temp
    st Z+, temp
    st Z+, temp2
    rjmp update_shift_condition
    
update_shift_powerup:
    ld temp2, Z
    cpi_low_reg count, 4
    brne update_shift_powerup2
    jmp powerloss
update_shift_powerup2:
    cpi_low_reg count, 12
    brne update_shift_powerup3
    jmp powerloss
update_shift_powerup3:
    sbiw Z, 2
    push temp
    ld temp, Z
    cpi temp, 'C'
    breq powerboost
    pop temp
    st Z+, temp
    st Z+, temp2
    rjmp update_shift_condition

powerboost:
    pop temp
    push ZL
    push ZH
    ldi ZL, low(level)
    ldi ZH, high(level)
    ld temp, Z
    
    ;mul temp, ten
    add score_low, temp
    adc score_high, temp

    pop ZH
    pop ZL
    rjmp update_shift_condition

update_shift_condition:
    inc count
    cpi_low_reg count, 7
    breq update_shift_condition_row_0
    cpi_low_reg count, 14
    breq update_exit
    rjmp update_shift

update_shift_condition_row_0:
    ldi ZL, low(racer_row_1)
    ldi ZH, high(racer_row_1)
    
    get_points
    rjmp update_shift

life_loss:
    pop temp
    ldi ZL, low(lives)
    ldi ZH, high(lives)
    ld temp, Z
    
    dec temp
    brne life_loss2
    jmp game_over
life_loss2:
    st Z, temp
    
    ldi temp2, '0'
    add temp2, temp
    
    ldi ZL, low(panel_row_0)
    ldi ZH, high(panel_row_0)
    adiw Z, 6
    st Z, temp2
    rcall reset_level
    rjmp update_exit

powerloss:
    ldi temp2, ' '
    sbiw Z, 1
    st Z, temp2
    rjmp update_shift_condition
    
update_exit:
    pop temp2
    pop temp
    ret
    
reset_level:
    push ZL
    push ZH
    push temp
    
    store_string racer_row_0, 'C', ' ', ' ', ' ', ' ', ' ', ' ', ' '
    store_string racer_row_1, ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
    
    ldi ZL, low(position)
    ldi ZH, high(position)
    st Z, zero
    
    ldi ZL, low(not_top)
    ldi ZH, high(not_top)
    st Z, zero
    
    pop temp
    pop ZH
    pop ZL
    ret
