;.DEF LSB = R2 ; LeastSigBit 16-bit-number to be divided = row
;.DEF MSB = R3 ; MostSigBit 16-bit-number to be divided = column
;.DEF temp = R4 ; interim register = temp
.DEF divN = R11 ; 8-bit-number to divide with
.DEF lsbRes = R12 ; LSB result
.DEF msbRes = R13 ; MSB result
;.DEF loader = R8; multipurpose register for loading = temp2
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
	ldi temp2,0x00 ; LestSigBit to be divided
	mov column,temp2
	ldi temp2, 0x00 ; MostSigBit to be divided
	mov row,temp2
	ldi temp2,0x00 ; 8 bit num to be divided with
	mov divN,loader
; Divide column:row by divN
div8:
	clr temp ; clear temp register
	clr msbRes ; clear result (the result registers
	clr lsbRes ; are also used to count to 16 for the
	inc lsbRes ; division steps, is set to 1 at start)
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
	rol lsbRes ; rotate carry-bit into result registers
	rol msbRes
	brcc div8a ; as long as zero rotate out of the result
	 ; registers: go on with the division loop
endBigNumDiv:

	;Grab result before the pops!
	pop R0
	pop R1
	pop R2
	pop R3
	pop R4
	pop R5
	pop R16
