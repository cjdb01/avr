;.DEF LSB = R2 ; LeastSigBit 16-bit-number to be divided = row - R6
;.DEF MSB = R3 ; MostSigBit 16-bit-number to be divided = column - R7
;.DEF temp = R4 ; interim register = temp - R16
;.DEF loader = R8; multipurpose register for loading = temp2 - R17

.DEF divN = R11 ; 8-bit-number to divide with
.DEF result_lo = R12 ; LSB result
.DEF result_hi = R13 ; MSB result

.CSEG
.ORG 0
bigNumDiv:
push row
push column
push temp
push divN
push temp2

	ldi temp2,0x00 ; LestSigBit to be divided
	mov column,temp2
	ldi temp2, 0x00 ; MostSigBit to be divided
	mov row,temp2
	ldi temp2,0x00 ; 8 bit num to be divided with
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

	
	;Grab result before the pops!
	pop temp2
	;pop result_hi
	;pop result_lo
	pop divN
	pop temp
	pop column
	pop row
