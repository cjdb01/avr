/****  ExampleW.3.1    ******************************************/
         ; This example demonstrates on how the switching can be 
         ; implemented using the external interrupt.        
         ; The Motor is switched on and off using switches PB0 PB1
         ;*******************************************************
         ; connections:
         ;       PB0 (input pin) -> PD0 (External Interrupt 0)
         ;       PB1 (input pin) -> PD1 (External Interrupt 1)
         ;       Mot             -> PC0
         ; External interrupts ::refer ATMega64DataSheet page 89
         ;NOTE: External interrupts occur based on SREG...i flag
         ;
         ;**********************
         ;
         ;      
         ; 
/****************************************************************/
.include "m64def.inc"
.def temp = r16
.def speed = r17
.def counter = r18
.def counter2 = r19
.def counter3 = r20
.def counter4 = r21

; Setup the interrupt vectors so that the task will be given
; to the necessary subroutine when there is an interrupt

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
jmp Timer0  ; Timer0 Overflow Handler

Default: reti

Timer1:                  ; Prologue starts.
push r29                 ; Save all conflict registers in the prologue.
push r28
in r24, SREG
push r24                 ; Prologue ends.

rjmp exit



Timer0:                  ; Prologue starts.
push r29                 ; Save all conflict registers in the prologue.
push r28
in r24, SREG
push r24                 ; Prologue ends.

/**** a counter for 3597 is needed to get one second-- Three counters are used in this example **************/                                          
                         ; 3597  (1 interrupt 278microseconds therefore 3597 interrupts needed for 1 sec)
;cpi counter, 97          ; counting for 97
cpi counter, 2
brne counter97
 
;cpi counter2, 35         ; counting for 35
cpi counter2, 2
brne counter35          ; jumping into count 100

;cpi counter3, 100
;brne counter100          ; jumping into count 100

; 23588

rcall DISPLAY         ; every second, update

ldi counter,0    ; clear counter value after 3597 interrupts gives us one second
ldi counter2,0
ldi counter3,0

;cpi counter4,30             ; every 30 seconds
cpi counter4,3
brne counter30

rcall NEXT_LEVEL

ldi counter4, 0
rjmp exit

counter97:
    inc counter   ; if it is not a second, increment the counter
    rjmp exit

counter100:
    inc counter3
    rjmp exit

counter30:
    inc counter4
    rjmp exit

counter35:
    inc counter3 ; counting 100 for every 35 times := 35*100 := 3500
    ;cpi counter3,100 
    cpi counter3,10 
    brne exit
    inc counter2
    ldi counter3,0
    rjmp exit


exit: 
pop r24                  ; Epilogue starts;
out SREG, r24            ; Restore all conflict registers from the stack.
pop r28
pop r29
reti                     ; Return from the interrupt.

; interrupt place when Reset button is pressed
RESET:

ldi temp, high(RAMEND) ; Initialize stack pointer
out SPH, temp
ldi temp, low(RAMEND)
out SPL, temp
ldi speed,0            
ldi counter,0            
ldi counter2,0
ldi counter3,0
ldi counter4,0
ldi temp,255
out DDRC,temp
rjmp main

DISPLAY:

asr speed ; divide num by 4
asr speed
; TODO: display the number
ldi speed, 0 ; ret num to 0

ret

NEXT_LEVEL:

ret



; Main does not do anything in here  !!
main:
ldi temp, 0b00000010     ; 
out TCCR0, temp          ; Prescaling value=8  ;256*8/7.3728( Frequency of the clock 7.3728MHz, for the overflow it should go for 256 times)
ldi temp, 1<<TOIE0       ; =278 microseconds
out TIMSK, temp          ; T/C0 interrupt enable
sei                      ; Enable global interrupt
loop: rjmp loop          ; loop forever