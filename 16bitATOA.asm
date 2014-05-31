.include "m64def.inc"

.dseg
.org 0x100
string: .byte 1

.cseg
.org 0x0

;==============================
;=============DEFS=============
;==============================

.def TEN = r10
.def temp = r18
;.def result = r19
.def result_lo = r19
.def result_hi = r20
;.def num1 = r21
.def num1_lo = r21
.def num1_hi = r22

.def num2_lo = r16
.def num2_hi = r17


;================================
;=============MACROS=============
;================================

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

.def rd1l = R0 ; LSB 16-bit-number to be divided
.def rd1h = R1 ; MSB 16-bit-number to be divided
.def rd1u = R2 ; interim register
.def rd2  = R3 ; 8-bit-number to divide with
.def rel  = R4 ; LSB result
.def reh  = R5 ; MSB result
; temp ; multipurpose register for loading
;
.cseg
.org 0
;
    rjmp start
;
start:
;
; Load the test numbers to the appropriate registers
;
.macro divideFunction
    mov rd1h,@0
    mov rd1l,@1
    mov temp,@2 ; number to be divided with
    mov rd2,temp
;
; Divide rd1h:rd1l  by rd2
;
div8:
    clr rd1u ; clear interim register
    clr reh  ; clear result (the result registers
    clr rel  ; are also used to count to 16 for the
    inc rel  ; division steps, is set to 1 at start)
;
; Here the division loop starts
;
div8a:
    clc      ; clear carry-bit
    rol rd1l ; rotate the next-upper bit of the number
    rol rd1h ; to the interim register (multiply by 2)
    rol rd1u
    brcs div8b ; a one has rolled left, so subtract
    cp rd1u,rd2 ; Division result 1 or 0?
    brcs div8c  ; jump over subtraction, if smaller
div8b:
    sub rd1u,rd2; subtract number to divide with
    sec      ; set carry-bit, result is a 1
    rjmp div8d  ; jump to shift of the result bit
div8c:
    clc      ; clear carry-bit, resulting bit is a 0
div8d:
    rol rel  ; rotate carry-bit into result registers
    rol reh
    brcc div8a  ; as long as zero rotate out of the result
                ; registers: go on with the division loop
; End of the division reached

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

LDI TEN, LOW(10)
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
ldi num1_lo, low(1000)
ldi num1_hi, high(1000)
ldi num2_lo, low(250)
ldi num2_hi, high(250)
ldi result_lo, 0
ldi result_hi, 0

divideFunction num1_lo, num1_hi, num2_lo, num2_hi

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