.include "m64def.inc"

.dseg
.org 0x100
string: .byte 1

.cseg
.org 0x0

;==============================
;=============DEFS=============
;==============================


.def zero       = r2 ; can't be r0 because r1:r0 is used for multiplication
.def count      = r3
.def score_high = r4 ; low registers chosen because they will be less popular for frequent usage
.def score_low  = r5
.def row        = r6
.def column     = r7
.def mask       = r8
.def press      = r9
.def ten        = r10 ; r10 holds the value 10
.DEF divN = R11 ; 8-bit-number to divide with
.DEF result_lo = R12 ; LSB result
.DEF result_hi = R13 ; MSB result
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


;==============================
;=============MAIN=============
;==============================

main:
;ldi integer, 1
; pointer(2)+integer(2) = 4 bytes to store local variables,
ldi temp, low(RAMEND)
out SPL, temp
ldi temp, high(RAMEND)
out SPH, temp

ldi_low_reg zero, low(75)
ldi_low_reg count, high(75)
ldi_low_reg result_lo, 0
ldi_low_reg result_hi, 0

;rcall bigNumDiv

rcall itoa_function

main_loop:
rjmp main_loop

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
    push zero
    push count
    push result_lo
    push result_hi

itoa_core:
ldi XH, high(string)
ldi XL, low(string)
adiw XL:XH, 7 ; move data pointer 6 chars to the right

;ldi_low_reg TEN, LOW(10)

; Handle 0 explicitely, otherwise empty string is printed for 0
CPI_low_reg count, 0
brne loop2
CPI_low_reg zero, 0
brne loop2
ldi temp, '0'
st -X, temp
rjmp exit

loop2: ;     while (num != 0)

    CPI_low_reg zero, 0                     ; if num < 1, break
    brne after_check
    CPI_low_reg count, 1
    BRLT exit

after_check:
    rcall bigNumDiv

    
    ldi temp, '0'
    add divN, temp
    st -X, divN

    movw count:zero, result_hi:result_lo

    rjmp loop2

exit:
;    ldi temp, 0      ;     str[i] = '\0'; // Append string terminator
;    st -X, temp
epilogue:
    pop result_hi
    pop result_lo
    pop count
    pop zero
    pop temp
    ret


;=============DIV16===========

;.DEF LSB = R2 ; LeastSigBit 16-bit-number to be divided = zero - R6
;.DEF MSB = R3 ; MostSigBit 16-bit-number to be divided = count - R7
;.DEF temp = R4 ; interim register = temp - R16
;.DEF loader = R8; multipurpose register for loading = temp2 - R17

bigNumDiv:

push zero
push count
push temp
;push divN
clr divN
push temp2

    ;ldi temp2,0x00 ; LestSigBit to be divided
    ;mov count,temp2
    ;ldi temp2, 0x00 ; MostSigBit to be divided
    ;mov zero,temp2
    ldi temp2,0x0A ; 8 bit num to be divided with
    mov divN,temp2
; Divide count:zero by divN
div8:
    clr temp ; clear temp register
    clr result_hi ; clear result (the result registers
    clr result_lo ; are also used to count to 16 for the
    inc result_lo ; division steps, is set to 1 at start)
; Start Div loop
div8a:
    clc ; clear carry-bit
    rol zero ; rotate the next-upper bit of the number
    rol count ; to the interim register (multiply by 2)
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
    pop count
    pop zero
    
    ret