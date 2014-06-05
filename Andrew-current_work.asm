.include "m64def.inc"

.dseg
.org 0x100
string: .byte 1

.cseg
.org 0x0

;==============================
;=============DEFS=============
;==============================

;.def TEN = r20
;.def temp = r21
;.def result_lo = r16
;.def result_hi = r17

.DEF divN = R11 ; 8-bit-number to divide with

;.def num1_lo = r18
;.def num1_hi = r19
;.DEF divN = R11 ; 8-bit-number to divide with


;.def result = r19
;.def result_lo = r19
;.def result_hi = r20
;.def num1 = r21
;.def num1_lo = r21
;.def num1_hi = r22

.DEF result_lo = R12 ; LSB result
.DEF result_hi = R13 ; MSB result


.def zero       = r2 ; can't be r0 because r1:r0 is used for multiplication
.def count      = r3
.def score_high = r4 ; low registers chosen because they will be less popular for frequent usage
.def score_low  = r5
.def row        = r6
.def column     = r7
.def mask       = r8
.def press      = r9
.def ten        = r10 ; r10 holds the value 10
;.def counter = r11    ; used for timer
;.def counter2 = r12   ; used for timer
;.def counter3 = r13   ; used for timer
.def counter4 = r14   ; used for timer
.def temp       = r16
.def temp2      = r17



;================================
;=============MACROS=============
;================================


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


;=============MUL2=============

; multiplication of two 2-byte unsigned numbers with the results of 2-bytes
; all parameters are registers, @5:@4 should be in the form: rd+1:rd,
; where d is the even number, and they are not r1 and r0
; operation: (@5:@4) = (@1:@0)*(@3:@2)

.macro mul2 ; a * b
mul @0, @2 ; al * bl
movw @5:@4, r1:r0
mul @1, @2 ; ah * bl
add @5, r0
mul @0, @3 ; bh * al
add @5, r0
.endmacro

;=============DIV=============

; num1 / num2 = result
; num1 : @0, num2 : @1, result : @2
.macro div ; a /b
    push temp

    MOV temp, @0
    ldi @2, 0

divloop:
    CP temp, @1                ; if temp < num2 loop : return temp
    BRLT divend
    sub temp, @1
    inc @2
    rjmp divloop
divend:
    pop temp
.endmacro

.macro div16
.endmacro

;=============MOD=============

; num1 % num2 = result
; num1 : @0, num2 : @1, result : @2
.macro mod ; a /b
    MOV @2, @0

modloop:
    CP @2, @1
    BRLT modend
    sub @2, @1
    rjmp modloop
modend:
.endmacro

.macro mod16
.endmacro

;=============ITOA_C=============

; char* itoa(int num, char* str)
; {
;     int i = 0;
;  
;     /* Handle 0 explicitely, otherwise empty string is printed for 0 */
;     if (num == 0)
;     {
;         str[i++] = '0';
;         str[i] = '\0';
;         return str;
;     }
;     
;
;     // num2 may overflow in its final check if num is large enough
;     while (num2 > num)
;     {
;         num2 *= 10;
;     }
;     num2 = num2 / 10;
;     
;     while (num2 != 0)
;     {
;         str[i++] = (num / num2) + '0';
;         num = num % num2;
;         num2 = num2 / 10;
;     }
;  
;     str[i] = '\0'; // Append string terminator
;  
;     // Reverse the string
;     reverse(str, i);
;  
;     return str;
; }

;=============ITOA_AVR=============

; num1 : @0, num2 : @1
.macro itoa

prologue:
    push r29
    push r28
    in r28, SPL
    in r29, SPH
    sbiw r28:r29, 10 ; allocate some stack space
    out SPH, r29
    out SPL, r28
    push temp
    push result

itoa_core:
ldi XH, high(string)
ldi XL, low(string)

ldi_low_reg TEN, LOW(10)
ldi @1, 1 ; int num2 = 1;

loop1: ;     while (num2 > num)

    mul @1, TEN                   ; num2 *= 10;
    mov @1, r0

    CP @1, @0                ; num2 > num
    breq loop1
    brlt loop1

    div @1, TEN, result     ; num2 = num2 / 10;
    mov @1, result

loop2: ;     while (num != 0)

    CPI @1, 1                     ; if num2 < 1, break
    BRLT exit
    
    div @0, @1, result    ; int result = num / num2;

    ldi temp, '0'
    add result, temp
    st X+, result

    mod @0, @1, result          ; num = num % num2;
    mov @0, result

    div @1, TEN, result     ; num2 = num2 / 10;
    mov @1, result

    rjmp loop2

exit:
    ldi temp, 0      ;     str[i] = '\0'; // Append string terminator
    st X+, temp
epilogue:
    pop result
    pop temp
    adiw r28:r29, 10 ; de-allocates our space
    out SPH, r29
    out SPL, r28
    pop r28
    pop r29

.endmacro


;==============================
;=============MAIN=============
;==============================

main:
;ldi integer, 1
; pointer(2)+integer(2) = 4 bytes to store local variables,
ldi r28, low(RAMEND-4)
ldi r29, high(RAMEND-4)

;ldi num1, low(42)
ldi_low_reg row, low(4567)
ldi_low_reg column, high(4567)
ldi_low_reg result_lo, 0
ldi_low_reg result_hi, 0

rcall bigNumDiv

;rcall itoa_function

;itoa num1

;itoa num1, num2

; prepare parameters for function call
; r21:r20 keep the actual parameter s
;ldd r20, Y+1
;ldd r21, Y+2
;; call subroutine atio
;;rcall atoi
;; get the return result
;std Y+1, r24
;std Y+2, r25
;end:
;rjmp end
;; end of main function()


// allocated 6 bits of space, then write each number, decreasing the data pointer

; char* itoa(int num, char* str)
; {
;     int i = 0;
;  
;     /* Handle 0 explicitely, otherwise empty string is printed for 0 */
;     if (num == 0)
;     {
;         str[i++] = '0';
;         str[i] = '\0';
;         return str;
;     }
;     while (num != 0)
;     {
;         str[i++] = (num % 10) + '0';
;         num = num / 10;
;     }
;  
;     str[i] = '\0'; // Append string terminator
;  
;     // Reverse the string
;     reverse(str, i);
;  
;     return str;
; }


itoa_function:
prologue:
    push temp
    push row
    push column
    push result_lo
    push result_hi

itoa_core:
ldi XH, high(string)
ldi XL, low(string)
adiw XL:XH, 6 ; move data pointer 6 chars to the right

ldi_low_reg TEN, LOW(10)

loop2: ;     while (num != 0)

    CPI_low_reg column, 0                     ; if num < 1, break
    brne after_check
    CPI_low_reg row, 1
    BRLT exit

after_check:
    rcall bigNumDiv

    ;mod16 row, column, TEN, result_lo        ; str[i++] = (num % 10) + '0';
    
    ldi temp, '0'
    add divN, temp
    st -X, divN

    ;div16 row, column, TEN, result_lo, result_hi        ; num = num / 10;
    movw column:row, result_hi:result_lo

    rjmp loop2

exit:
    ldi temp, 0      ;     str[i] = '\0'; // Append string terminator
    st -X, temp
epilogue:
    push column
    push row
    pop result_hi
    pop result_lo
    pop temp
    ret


;=============DIV16===========

;.DEF LSB = R2 ; LeastSigBit 16-bit-number to be divided = row - R6
;.DEF MSB = R3 ; MostSigBit 16-bit-number to be divided = column - R7
;.DEF temp = R4 ; interim register = temp - R16
;.DEF loader = R8; multipurpose register for loading = temp2 - R17

bigNumDiv:
/*
push row
push column
push temp
;push divN
clr divN
push temp2

    ;ldi temp2,0x00 ; LestSigBit to be divided
    ;mov column,temp2
    ;ldi temp2, 0x00 ; MostSigBit to be divided
    ;mov row,temp2
    ldi temp2,0x0A ; 8 bit num to be divided with
    mov divN,temp2
; Divide column:row by divN
div8:
    clr temp ; clear temp register
    clr result_hi ; clear result (the result registers
    clr result_lo ; are also used to count to 16 for the
    inc result_lo ; division steps, is set to 1 at start)
; Start Div loop
div8a:
    clc ; clear carry-bit
    rol row ; rotate the next-upper bit of the number
    rol column ; to the interim register (multiply by 2)
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
    brcc div8a ; as long as zero rotate out of the result
     ; registers: go on with the division loop
endBigNumDiv:
    mov divN, temp

    ;Grab result before the pops!
    pop temp2
    ;pop result_hi
    ;pop result_lo
    ;pop divN
    pop temp
    pop column
    pop row
    */
    ret

