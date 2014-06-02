.DEF rd1l = R0 ; LSB 16-bit-number to be divided
.DEF rd1h = R1 ; MSB 16-bit-number to be divided
.DEF rd1u = R2 ; interim register
.DEF rd2 = R3 ; 8-bit-number to divide with
.DEF rel = R4 ; LSB result
.DEF reh = R5 ; MSB result
.DEF rmp = R16; multipurpose register for loading
.CSEG
.ORG 0
bigNumDiv:
push R0
push R1
push R2
push R3
push R4
push R5
push R16
	ldi rmp,0x00 ; LSB to be divided
	mov rd1h,rmp
	ldi rmp, 0x08 ; MSB to be divided
	mov rd1l,rmp
	ldi rmp,0x04 ; 8 bit num to be divided with
	mov rd2,rmp
; Divide rd1h:rd1l by rd2
div8:
	clr rd1u ; clear interim register
	clr reh ; clear result (the result registers
	clr rel ; are also used to count to 16 for the
	inc rel ; division steps, is set to 1 at start)
; Here the division loop starts
div8a:
	clc ; clear carry-bit
	rol rd1l ; rotate the next-upper bit of the number
	rol rd1h ; to the interim register (multiply by 2)
	rol rd1u
	brcs div8b ; a one has rolled left, so subtract
	cp rd1u,rd2 ; Division result 1 or 0?
	brcs div8c ; jump over subtraction, if smaller
div8b:
	sub rd1u,rd2; subtract number to divide with
	sec ; set carry-bit, result is a 1
	rjmp div8d ; jump to shift of the result bit
div8c:
	clc ; clear carry-bit, resulting bit is a 0
div8d:
	rol rel ; rotate carry-bit into result registers
	rol reh
	brcc div8a ; as long as zero rotate out of the result
	 ; registers: go on with the division loop
endBigNumDiv:
	pop R0
	pop R1
	pop R2
	pop R3
	pop R4
	pop R5
	pop R16
