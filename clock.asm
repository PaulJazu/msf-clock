;    MSF Radio Clock
;    Copyright (C) 2004 Chris Johnson (http://www.chris-j.co.uk)

;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU General Public License as published by
;    the Free Software Foundation, either version 3 of the License, or
;    (at your option) any later version.

;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU General Public License for more details.

;    You should have received a copy of the GNU General Public License
;    along with this program.  If not, see <http://www.gnu.org/licenses/>.


#include <P16F877.inc>

#DEFINE BANK0 BCF STATUS,RP0    
#DEFINE BANK1 BSF STATUS,RP0

		__CONFIG _CP_OFF & _WDT_OFF & _PWRTE_ON & _XT_OSC & _LVP_OFF

adcmode equ		0x20			; whether to read or initialise the ADC
count	equ		0x21			; divide-by-5 counter
signal	equ		0x22			; signal status from radio
sigclk	equ		0x23
mode	equ		0x24			;	When bit n is off then we are:
								;	bit 0 - waiting for first mm
								;	bit 1 - timing possible mm candidate
								;	bit 2 - waiting for the next second
								;	bit 3 - currently decoding
bita	equ		0x25
bitb	equ		0x26
cursec	equ		0x27			; current second (binary)
tmpsec	equ		0x28
sync	equ		0x29
datefmt	equ		0x2A
butsta	equ		0x2B			; old button states

buzlen	equ		0x30
buztim	equ		0x31
beeplen	equ		0x32
beeptim	equ		0x33
beepon	equ		0x34
tmp1	equ		0x35


aledtim	equ		0x37
cycllim	equ		0x38
alcured	equ		0x39
alhrm	equ		0x3A
alhrl	equ		0x3B
alminm	equ		0x3C
alminl	equ		0x3D
umode	equ		0x3E
alon	equ		0x3F

dut		equ		0x40			; DUT1, in 100ms units. -ve values are 255,254,...

minm	equ		0x41			; reading values - these will be zero most of the time
minl	equ		0x42			; and will slowly fill up with date
hourm	equ		0x43
hourl	equ		0x44
dayomm	equ		0x45
dayoml	equ		0x46
monthm	equ		0x47
monthl	equ		0x48
yearm	equ		0x49
yearl	equ		0x4A
dayow	equ		0x4B
bst		equ		0x4C			; BST in effect flag. Data is read into this variable
								; and shifted to the LED on the next minute change.
secl	equ		0x4D
secm	equ		0x4E
adval	equ		0x4F

dispval	equ		0x50			; display function varibles
dispdig	equ		0x51			; double-digit (0-5)
disptmp	equ		0x52			; internal variable

milsec	equ		0x55			; milliseconds
censec	equ		0x56			; centiseconds
decsec	equ		0x57			; deciseconds

cminm	equ		0x61			; current values - these are batch-copied from the
cminl	equ		0x62			; completed reading values at the start of each minute
chourm	equ		0x63
chourl	equ		0x64
cdayomm	equ		0x65
cdayoml	equ		0x66
cmonthm	equ		0x67
cmonthl	equ		0x68
cyearm	equ		0x69
cyearl	equ		0x6A

lcdct	equ		0x70			; lcd digit number
lcddat	equ		0x74			; bcd values for lcd - goes up to 0x7C

		ORG		0x00			; Reset point
		GOTO	main
		ORG		0x04			; Interrupt point
		GOTO	intr


;		Initialise timer and interrupt, then
;		sit in an infinite loop waiting for interrupt
main	
		BANK1
		CLRF	TRISB			; set B to outputs
		CLRF	TRISD			; set D to outputs
		CLRF	TRISC			; set C to outputs
		MOVLW	B'00100001'
		MOVWF	TRISA			; set A0 and A5 to input
		BCF		TRISE,PSPMODE	; turn off parallel-slave mode on D 
		BSF		TRISE,0			; set E to inputs
		BSF		TRISE,1
		BSF		TRISE,2
		MOVLW	B'00001110'
		MOVWF	ADCON1

		MOVLW	B'10000010'		; timer divide by 8
		MOVWF	OPTION_REG		; gives 4.000Mhz/(4*8) = 125.00kHz
								
		BANK0
		MOVLW	B'00000001'
		MOVWF	ADCON0			; set ADC to Fosc/2, AN0, ADC global on

		CLRF	lcdct
		CLRF	PORTB
		CLRF	PORTA
		MOVLW	B'00010001'		; set initial display to horizontal bars
		MOVWF	0x74
		MOVWF	0x75
		MOVWF	0x76
		MOVWF	0x77
		MOVWF	0x78
		MOVWF	0x79
		MOVWF	0x7A
		MOVWF	0x7B
		MOVWF	0x7C
		MOVWF	0x7D
		MOVWF	0x7E
		MOVWF	0x7F
		CLRF	adcmode
		CLRF	sigclk
		CLRF	mode
		CLRF 	count
		CLRF	adval
		CLRF	sync
		CLRF	cursec
		CLRF	secm
		CLRF	secl
		CLRF	sigclk			
		CLRF	dut

		CLRF	minm
		CLRF	minl
		CLRF	hourm
		CLRF	hourl
		CLRF	dayomm
		CLRF	dayoml
		CLRF	monthm
		CLRF	monthl
		CLRF	yearm
		CLRF	yearl
		CLRF	dayow
		CLRF	bst

		CLRF	datefmt
		CLRF	butsta
		CLRF	buztim
		CLRF	buzlen
		CLRF	beeptim
		CLRF	beeplen	
		CLRF	beepon

		CLRF	cminm
		CLRF	cminl
		CLRF	chourm
		CLRF	chourl
		CLRF	cdayomm
		CLRF	cdayoml
		CLRF	cmonthm
		CLRF	cmonthl
		CLRF	cyearm
		CLRF	cyearl

		CLRF	tmp1
		CLRF	umode
		CLRF	alminl
		CLRF	alminm
		CLRF	milsec
		CLRF	censec
		CLRF	decsec
		MOVLW	.2			; set alarm to non-existant time initially
		MOVWF	alhrm
		MOVLW	.5
		MOVWF	alhrl
		CLRF	alon
		CLRF	alcured
		CLRF	cycllim
		MOVLW	.32
		MOVWF	aledtim

		BSF		INTCON,T0IE		; enable timer interrupt
		MOVLW	.130			; initialise timer to 130
		MOVWF	TMR0			; (255-130)*8.00us = 1.00ms
		BSF		INTCON,GIE		; enable global interrupts

loop
		GOTO	loop			; stay here for good, unless called to interrupt


; -----------------------------------------------------------------------------------
; Interrupt handler.
; Called every 1ms by TMR0 interrupt
intr
	;	MOVLW	.224		; set timer to 224
		MOVLW	.130		; set timer to 130
		MOVWF	TMR0
		BCF		INTCON,T0IF		; clear timer interrupt flag

		CALL	lcdupdate		; Update the display by moving to the next multiplexed digit
	
		; Update censec (1/100th sec digit) and decsec (1/10th sec digit)
		INCF	milsec,F
		MOVLW	.10
		SUBWF	milsec,W
		BTFSS	STATUS,Z
		GOTO	endsubsecupdate
		CLRF	milsec
		CALL	disprightsubse
		INCF	censec,F
		MOVLW	.10
		SUBWF	censec,W
		BTFSS	STATUS,Z
		GOTO	endsubsecupdate
		CLRF	censec
		INCF	decsec,F
		MOVLW	.10
		SUBWF	decsec,W
		BTFSS	STATUS,Z
		GOTO	endsubsecupdate
		CLRF	decsec
endsubsecupdate

		; Finished with part of ISR that needs to be updated every 1ms, so return 4 out of 5 times
		INCF	count,F			; increment count
		MOVLW	.5				; 5 * 0.992ms = 4.96ms, or 5.00ms for 8.00us TMR0 speed
		SUBWF	count,W			; 
		BTFSS	STATUS,Z		; if count=5, skip
		RETFIE

	; every 5ms
		CLRF	count			; reset counter to zero

		BTFSC	adcmode,0
		GOTO	decode			; Call decode if ADC mode is 1; happens every other time (every 10ms)

		CALL	startadc		; Start the ADC conversion (should call this only every other time too??)

		CALL 	buttonproc

		MOVFW	PORTE		; update bitsta port E bits...
		MOVWF	butsta
		BTFSC	PORTA,5		; ... and port A bit
		BSF		butsta,3
		BTFSS	PORTA,5
		BCF		butsta,3

		CALL 	buzzproc
		CALL 	beepproc

		BTFSC	umode,0		; UGH - these two lines are terrible
		CALL	dispalm	

		DECFSZ	aledtim,F
		RETFIE
		MOVLW	.32
		MOVWF	aledtim
		
		RETFIE

decode
		CALL	tryadcread		; read from the ADC

		BTFSC	signal,0		; internal signal LED
		BSF		PORTA,2
		BTFSS	signal,0
		BCF		PORTA,2	

		BTFSC	mode,0			; internal mode LED
		BSF		PORTA,3
		BTFSS	mode,0
		BCF		PORTA,3

		BTFSC	mode,0			; if we've already waited for the minute marker, move on
		GOTO	mm

		BTFSS	signal,0		; if the signal is off, we're still waiting: return
		RETFIE		
								
		CLRF	sigclk			; if the signal is on, it could be the minute marker - start timing
		BSF		mode,0			; set flag to move on next time

		BTFSS	sync,0			; if we've been in sync before, update minute display now
		RETFIE


		CLRF	milsec			; clear subsecond timers
		CLRF	censec
		CLRF	decsec

		MOVFW	minm			; copy data from read arrays to storage arrays
		MOVWF	cminm
		MOVFW	minl
		MOVWF	cminl
		MOVFW	hourm
		MOVWF	chourm
		MOVFW	hourl
		MOVWF	chourl
		MOVFW	dayomm
		MOVWF	cdayomm
		MOVFW	dayoml
		MOVWF	cdayoml
		MOVFW	monthm
		MOVWF	cmonthm
		MOVFW	monthl
		MOVWF	cmonthl
		MOVFW	yearm
		MOVWF	cyearm
		MOVFW	yearl
		MOVWF	cyearl

		MOVF	cminm,1
		BTFSS	STATUS,Z
		GOTO 	skiplongpip
		MOVF	cminl,1
		BTFSS	STATUS,Z
		GOTO 	skiplongpip
		MOVLW	.50
		CALL	beep
skiplongpip:

		MOVF	umode,F			; if in clock mode, update the minute display
		BTFSS	STATUS,Z
		RETFIE

		CALL	disprightdt		; display time/date
		CALL	checkalarm
		RETFIE

; CHUNK 2 start
mm
		BTFSC	mode,1			; if we've already found the mm, move on
		GOTO	decodemin
;		RETFIE					; tmp retfie. uncomment the goto and delete the retfie for normal usage	

		INCF	sigclk,F			; increment timer
		BTFSS	signal,0		
		GOTO	mmoff			; if signal has turned off, go to mmoff
		RETFIE

mmoff
		MOVLW	.40				; 40 * 10ms ish
		SUBWF	sigclk,W
		BTFSS	STATUS,0
		GOTO	mmfail			; if we've been waiting <400ms, goto mmfail, otherwise goto mmpass
		GOTO	mmpass
		RETFIE

mmfail
		BCF		mode,0			; back to waiting for minute marker
		RETFIE

mmpass
		; Here are things that can happen at any time during the first second of the minute
		; TODO: BST indicator 
		CLRF	cursec			; clear all variables
		CLRF	secm			; new data is read in for every minute.
		CLRF	secl
		CLRF	sigclk			
		CLRF	dut
		CLRF	minm
		CLRF	minl
		CLRF	hourm
		CLRF	hourl
		CLRF	dayomm
		CLRF	dayoml
		CLRF	monthm
		CLRF	monthl
		CLRF	yearm
		CLRF	yearl
		CLRF	dayow
		CLRF	bst

		BSF		mode,1			; can move on to standard decoding routine
		RETFIE

; CHUNK 3 start
decodemin
		BTFSC	mode,2			; we're not currently waiting for the next second, so move on
		GOTO	decodebits
		
		BTFSC	signal,0		
		GOTO	bitsstart		; if signal has turned on, go to bitsstart
		RETFIE					; otherwise the next second has not yet arrived so return

bitsstart
; do all the stuff thats needed at the beginning of a second here
		INCF	cursec,F			; increase binary seconds
		CALL	incrsec			; increase BCD seconds
		CLRF	sigclk

		CLRF	milsec			; clear subsecond timers
		CLRF	censec
		CLRF	decsec

		BSF		mode,2
		BTFSS	sync,0			; if in sync
		RETFIE

		MOVF	umode,F			; if in clock mode, update the second
		BTFSC	STATUS,Z
		CALL	disprightse

		
		MOVF	cminm,0	; if current minute is not 59, return
		SUBLW	.5
		BTFSS	STATUS,Z
		RETFIE
		MOVF	cminl,0	
		SUBLW	.9
		BTFSS	STATUS,Z
		RETFIE
	
		MOVF	cursec,0	; if current second is not >54, return
		SUBLW	.54
		BTFSC	STATUS,C
		RETFIE

		MOVLW	.10		; short pips beep
		CALL	beep
		RETFIE

; CHUNK 4 start
decodebits
		BTFSC	mode,3			; we're not decoding bits - we've finished
		GOTO	process

		INCF	sigclk
		MOVLW	.17				; at 170ms check bit A
		SUBWF	sigclk,W
		BTFSC	STATUS,Z
		CALL	getbita

		MOVLW	.27				; at 270ms check bit B
		SUBWF	sigclk,W
		BTFSC	STATUS,Z
		CALL	getbitb			; getbitb sets mode bit 3 flag

		MOVLW	.75				; at 750ms everything is definitely off
		SUBWF	sigclk,W
		BTFSC	STATUS,Z
		BSF		mode,3		; now finished getting data
		RETFIE

; CHUNK 5 start
process
		MOVFW	cursec
		MOVWF	tmpsec

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec01

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec02

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec03

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec04

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec05

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec06

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec07

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec08

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec09

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec10

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec11

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec12

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec13

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec14

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec15

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec16

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec17

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec18

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec19

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec20

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec21

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec22

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec23

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec24

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec25

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec26

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec27

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec28

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec29

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec30

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec31

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec32

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec33

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec34

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec35

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec36

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec37

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec38

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec39

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec40

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec41

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec42

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec43

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec44

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec45

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec46

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec47

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec48

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec49

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec50

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec51

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec52

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec53

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec54

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec55

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec56

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec57

		DECF	tmpsec
		BTFSC	STATUS,Z
		CALL	procsec58

		BCF		mode,3			; finished this second so
		BCF		mode,2			; go back to waiting for next second

		MOVLW	.59				; if its the 59th second...
		SUBWF	cursec,W			
		BTFSS	STATUS,Z
		RETFIE
		CLRF	mode			; clear mode
		BSF		sync,0			; clock is in sync
		RETFIE



getbita
		MOVFW	signal
		MOVWF	bita
		RETURN



getbitb
		MOVFW	signal
		MOVWF	bitb
		RETURN



procsec01
		CLRF	dut
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec02
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec03
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec04
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec05
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec06
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec07
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec08
		BTFSC	bitb,0
		INCF	dut
		RETURN
procsec09
		BTFSC	bitb,0
		DECF	dut
		RETURN
procsec10
		BTFSC	bitb,0
		DECF	dut
		RETURN
		RETURN
procsec11
		BTFSC	bitb,0
		DECF	dut
		RETURN
		RETURN
procsec12
		BTFSC	bitb,0
		DECF	dut
		RETURN
		RETURN
procsec13
		BTFSC	bitb,0
		DECF	dut
		RETURN
		RETURN
procsec14
		BTFSC	bitb,0
		DECF	dut
		RETURN
		RETURN
procsec15
		BTFSC	bitb,0
		DECF	dut
		RETURN
		RETURN
procsec16
		BTFSC	bitb,0
		DECF	dut
		RETURN
		RETURN
procsec17
		BTFSC	bita,0
		BSF		yearm,3
		RETURN
procsec18
		BTFSC	bita,0
		BSF		yearm,2
		RETURN
procsec19
		BTFSC	bita,0
		BSF		yearm,1
		RETURN
procsec20
		BTFSC	bita,0
		BSF		yearm,0
		RETURN
procsec21
		BTFSC	bita,0
		BSF		yearl,3
		RETURN
procsec22
		BTFSC	bita,0
		BSF		yearl,2
		RETURN
procsec23
		BTFSC	bita,0
		BSF		yearl,1
		RETURN
procsec24
		BTFSC	bita,0
		BSF		yearl,0
		RETURN
procsec25
		BTFSC	bita,0
		BSF		monthm,0
		RETURN
procsec26
		BTFSC	bita,0
		BSF		monthl,3
		RETURN
procsec27
		BTFSC	bita,0
		BSF		monthl,2
		RETURN
procsec28
		BTFSC	bita,0
		BSF		monthl,1
		RETURN
procsec29
		BTFSC	bita,0
		BSF		monthl,0
		RETURN
procsec30
		BTFSC	bita,0
		BSF		dayomm,1
		RETURN
procsec31
		BTFSC	bita,0
		BSF		dayomm,0
		RETURN
procsec32
		BTFSC	bita,0
		BSF		dayoml,3
		RETURN
procsec33
		BTFSC	bita,0
		BSF		dayoml,2
		RETURN
procsec34
		BTFSC	bita,0
		BSF		dayoml,1
		RETURN
procsec35
		BTFSC	bita,0
		BSF		dayoml,0
		RETURN
procsec36
		BTFSC	bita,0
		BSF		dayow,2
		RETURN
procsec37
		BTFSC	bita,0
		BSF		dayow,1
		RETURN
procsec38
		BTFSC	bita,0
		BSF		dayow,0
		RETURN
procsec39
		BTFSC	bita,0
		BSF		hourm,1
		RETURN
procsec40
		BTFSC	bita,0
		BSF		hourm,0
		RETURN
procsec41
		BTFSC	bita,0
		BSF		hourl,3
		RETURN
procsec42
		BTFSC	bita,0
		BSF		hourl,2
		RETURN
procsec43
		BTFSC	bita,0
		BSF		hourl,1
		RETURN
procsec44
		BTFSC	bita,0
		BSF		hourl,0
		RETURN
procsec45
		BTFSC	bita,0
		BSF		minm,2
		RETURN
procsec46
		BTFSC	bita,0
		BSF		minm,1
		RETURN
procsec47
		BTFSC	bita,0
		BSF		minm,0
		RETURN
procsec48
		BTFSC	bita,0
		BSF		minl,3
		RETURN
procsec49
		BTFSC	bita,0
		BSF		minl,2
		RETURN
procsec50
		BTFSC	bita,0
		BSF		minl,1
		RETURN
procsec51
		BTFSC	bita,0
		BSF		minl,0
		RETURN
procsec52
		RETURN
procsec53
		RETURN
procsec54
		RETURN
procsec55
		RETURN
procsec56
		RETURN
procsec57
		RETURN
procsec58
		BTFSC	bitb,.0
		BSF		bst,.0
		RETURN


startadc
		BSF		ADCON0,GO		; set ADC going
		BSF		adcmode,0		; set ADC mode flag
		RETURN
		



; -----------------------------------------------------------------------------------
; Try ADC read
;	Sets 'signal' to all ones if the ADC has read >32 (1/4 of full voltage?), or all zeros if not 
;	Clears the ADC mode flag
tryadcread
		BTFSC	ADCON0,NOT_DONE	; skip return if NOT_DONE false, i.e. continue if conversion is finished
		RETURN

		MOVFW	ADRESH
		MOVWF	adval
	
		BCF		adcmode,0		; clear ACD mode flag
		MOVLW	.32
		SUBWF	ADRESH,W
		BTFSC	STATUS,0
		GOTO	sigoff
		MOVLW	B'11111111'
		MOVWF	signal
		RETURN
sigoff
		MOVLW	.0
		MOVWF	signal
		RETURN



incrsec
		INCF	secl
		MOVLW	.10
		SUBWF	secl,W
		BTFSS	STATUS,Z
		RETURN
		CLRF	secl
		CALL	incrsec2
		RETURN




incrsec2
		INCF	secm
		MOVLW	.7
		SUBWF	secm,W
		BTFSS	STATUS,Z
		RETURN
		CLRF	secm
		RETURN




; -----------------------------------------------------------------------------------
; Display time and date - datefmt=0
;	Moves currently stored date,hour,min to display in HH MM SS / DD MM YY format
;   Displays 0 for seconds
disptd1

		MOVFW	cyearl
		MOVWF	lcddat+.11
		MOVFW	cyearm
		MOVWF	lcddat+.10
		MOVFW	cmonthl			; move BCD data read during the previous minute to display
		MOVWF	lcddat+.9
		MOVFW	cmonthm
		MOVWF	lcddat+.8
		MOVFW	cdayoml
		MOVWF	lcddat+.7
		MOVFW	cdayomm
		MOVWF	lcddat+.6
		MOVLW	0				; force display of 00 for seconds
		MOVWF	lcddat+.5
		MOVLW	0
		MOVWF	lcddat+.4
		MOVFW	cminl
		MOVWF	lcddat+.3
		MOVFW	cminm
		MOVWF	lcddat+.2
		MOVFW	chourl
		MOVWF	lcddat+.1
		MOVFW	chourm
		MOVWF	lcddat
		BSF		lcddat+.9,5	; shift 32 chars along to get decimal point
		BSF		lcddat+.7,5
		BSF		lcddat+.1,5
		BSF		lcddat+.3,5
		RETURN



; -----------------------------------------------------------------------------------
; Display time and date - datefmt=1
;	Moves currently stored date,hour,min to display in YY MM DD / HH MM SS format
;   Displays 0 for seconds
disptd2
		MOVFW	cyearl			; move BCD data read during the previous minute to display
		MOVWF	lcddat+.1

		MOVFW	cyearm
		MOVWF	lcddat

		MOVFW	cmonthl
		MOVWF	lcddat+.3

		MOVFW	cmonthm
		MOVWF	lcddat+.2

		MOVFW	cdayoml			
		MOVWF	lcddat+.5

		MOVFW	cdayomm
		MOVWF	lcddat+.4

		MOVLW	0				; force display of 00 for seconds
		MOVWF	lcddat+.11
		MOVLW	0
		MOVWF	lcddat+.10

		MOVFW	cminl
		MOVWF	lcddat+.9

		MOVFW	cminm
		MOVWF	lcddat+.8

		MOVFW	chourl
		MOVWF	lcddat+.7

		MOVFW	chourm
		MOVWF	lcddat+.6

		BSF		lcddat+.9,5	; shift 32 chars along to get decimal point
		BSF		lcddat+.7,5
		BSF		lcddat+.1,5
		BSF		lcddat+.3,5
		RETURN



; -----------------------------------------------------------------------------------
; Display time and date - datefmt=2
;	Moves currently stored hour,min to display in HH MM format
disptd3		
		MOVFW	cminl
		MOVWF	lcddat+.3
		MOVFW	cminm
		MOVWF	lcddat+.2
		MOVFW	chourl
		MOVWF	lcddat+.1

		MOVFW	chourm		; if hour 10s digit is not zero, skip setting it to blank
		BTFSC	STATUS,Z
		MOVLW	B'00010000'
		MOVWF	lcddat

		BSF		lcddat+.1,5
		MOVLW	B'00010000'
		MOVWF	lcddat+.4	; turn the rest of the display off
		MOVWF	lcddat+.5
		MOVWF	lcddat+.6
		MOVWF	lcddat+.7
		MOVWF	lcddat+.8
		MOVWF	lcddat+.9
		MOVWF	lcddat+.10
		MOVWF	lcddat+.11
		RETURN

; -----------------------------------------------------------------------------------
; Display time and date - datefmt=3
;	Moves currently stored hour,min to display in HH MM SS TH
disptd4		
		MOVFW	cminl
		MOVWF	lcddat+.3
		MOVFW	cminm
		MOVWF	lcddat+.2
		MOVFW	chourl
		MOVWF	lcddat+.1
		MOVFW	chourm
		MOVWF	lcddat	

		MOVLW	0				; force display of 00 for seconds
		MOVWF	lcddat+.7
		MOVLW	0
		MOVWF	lcddat+.6

		BSF		lcddat+.1,5
		MOVLW	B'00010000'
		MOVWF	lcddat+.4	; turn the rest of the display off
		MOVWF	lcddat+.5
		MOVWF	lcddat+.10
		MOVWF	lcddat+.11
		RETURN



; -----------------------------------------------------------------------------------
; Display seconds - datefmt=0
;	Moves currently stored seconds to display
dispse1
		MOVFW	secl
		MOVWF	lcddat+.5
		MOVFW	secm
		MOVWF	lcddat+.4
		RETURN

; -----------------------------------------------------------------------------------
; Display seconds - datefmt=1
;	Moves currently stored seconds to display
dispse2
		MOVFW	secl
		MOVWF	lcddat+.11
		MOVFW	secm
		MOVWF	lcddat+.10
		RETURN



; -----------------------------------------------------------------------------------
; Display seconds - datefmt=2
;	Flashes decimal point every other second in this format
dispse3
		MOVFW	lcddat+.1
		XORLW	B'00100000'
		MOVWF	lcddat+.1
		RETURN

; -----------------------------------------------------------------------------------
; Display seconds - datefmt=3
;	Moves currently stored seconds to display
dispse4
		MOVFW	secl
		MOVWF	lcddat+.7
		MOVFW	secm
		MOVWF	lcddat+.6
		RETURN


; -----------------------------------------------------------------------------------
; Display subseconds - datefmt=3
;	Moves currently stored 10th and 100th second digits to display
;	No dispsubse# for 1-3 since no subsecond display in these modes
dispsubse4						
		MOVFW	censec
		MOVWF	lcddat+.9
		MOVFW	decsec
		MOVWF	lcddat+.8
		RETURN


; -----------------------------------------------------------------------------------
; Display time and date
;	Calls the appropriate display routine depending on what display format is set in datefmt 
;	These routines all copy the date (if displayed), hour and minute to the display.
;	Seconds are dealt with by the dispse routines
;	Subseconds are dealt with by the dispsubse routines
disprightdt
		MOVF	datefmt,F		; does nothing, but sets Z bit in status
		BTFSC	STATUS,Z		; dispdate if datefmt=0
		CALL	disptd1			; normal display

		MOVLW	.1
		SUBWF	datefmt,W
		BTFSC	STATUS,Z		; dispdate if datefmt=1
		CALL	disptd2			; display YYMMDDHHMMSS format

		MOVLW	.2
		SUBWF	datefmt,W
		BTFSC	STATUS,Z		; dispdate if datefmt=2
		CALL	disptd3			; display small (HHMM) format

		MOVLW	.3
		SUBWF	datefmt,W
		BTFSC	STATUS,Z		; dispdate if datefmt=3
		CALL	disptd4			; display (HHMM/SSTH) format
		RETURN




; -----------------------------------------------------------------------------------
; Display seconds
;	Calls the appropriate display routine depending on what display format is set in datefmt 
;	These routines all copy the seconds to the display.
disprightse

		MOVF	datefmt,F		; does nothing, but sets Z bit in status
		BTFSC	STATUS,Z		; dispdate if datefmt=0
		CALL	dispse1			; normal display

		MOVLW	.1
		SUBWF	datefmt,W
		BTFSC	STATUS,Z		; dispdate if datefmt=1
		CALL	dispse2			; display YYMMDDHHMMSS format

		MOVLW	.2
		SUBWF	datefmt,W
		BTFSC	STATUS,Z		; dispdate if datefmt=2
		CALL	dispse3			; display small (HHMM) format


		MOVLW	.3
		SUBWF	datefmt,W
		BTFSC	STATUS,Z		; dispdate if datefmt=2
		CALL	dispse4			; display (HHMM/SSTH) format
		RETURN

; -----------------------------------------------------------------------------------
; Display subeconds
;	Calls the appropriate display routine depending on what display format is set in datefmt 
;	(Currently subseconds are displayed only in one mode)
disprightsubse
		MOVLW	.3
		SUBWF	datefmt,W
		BTFSC	STATUS,Z		; dispdate if datefmt=3
		CALL	dispsubse4		; display (HHMM/SSTH) format
		RETURN


dispalm		; alarm
		MOVLW	.3
		SUBWF	alcured,W
		BTFSS	STATUS,Z
		GOTO	dispalm1
		MOVLW	.16
		SUBWF	aledtim,W
		BTFSC	STATUS,0
		GOTO	dispalm1
		MOVLW	B'00010000'
		MOVWF	lcddat
		GOTO	dispalm1a
dispalm1
		MOVFW	alhrm
		MOVWF	lcddat
dispalm1a

		MOVLW	.2
		SUBWF	alcured,W
		BTFSS	STATUS,Z
		GOTO	dispalm2
		MOVLW	.16
		SUBWF	aledtim,W
		BTFSC	STATUS,0
		GOTO	dispalm2
		MOVLW	B'00010000'
		MOVWF	lcddat+.1
		GOTO	dispalm2a
dispalm2
		MOVFW	alhrl
		MOVWF	lcddat+.1
dispalm2a

		MOVLW	.1
		SUBWF	alcured,W
		BTFSS	STATUS,Z
		GOTO 	dispalm3
		MOVLW	.16
		SUBWF	aledtim,W
		BTFSC	STATUS,C
		GOTO	dispalm3
		MOVLW	B'00010000'
		MOVWF	lcddat+.2
		GOTO	dispalm3a
dispalm3
		MOVFW	alminm
		MOVWF	lcddat+.2
dispalm3a

		MOVLW	.0
		SUBWF	alcured,W
		BTFSS	STATUS,Z
		GOTO	dispalm4
		MOVLW	.16
		SUBWF	aledtim,W
		BTFSC	STATUS,C
		GOTO	dispalm4
		MOVLW	B'00010000'
		MOVWF	lcddat+.3
		GOTO	dispalm4a
dispalm4
		MOVFW	alminl
		MOVWF	lcddat+.3
dispalm4a


		BSF		lcddat+.1,5

		MOVLW	B'00010000'
		MOVWF	lcddat+.4	; turn the rest of the display off
		MOVWF	lcddat+.5
		MOVWF	lcddat+.6
		MOVWF	lcddat+.7
		MOVWF	lcddat+.8
		MOVWF	lcddat+.9
		MOVWF	lcddat+.10
		MOVWF	lcddat+.11

		RETURN




; -----------------------------------------------------------------------------------
; Buzz routine (alarm buzzer)
; 	When called with a number in W, will start a buzz for the duration W*5ms
buzz
		MOVWF	buzlen
		CLRF	buztim
		BSF		PORTA,1
		RETURN

; -----------------------------------------------------------------------------------
; Buzz timing routine
; 	Called every 5ms by the ISR. 
buzzproc
		MOVF	buzlen,F		; if buzzlen (the length of the buzz we desire) is zero
		BTFSC	STATUS,Z		; 
		RETURN					; then return immidiately

		INCF	buztim,F		; increment buzztim which times how long the current buzz has been on

		MOVFW	buzlen			; if buztim = buzlen
		SUBWF	buztim,W		;
		BTFSS	STATUS,Z		;
		RETURN					;
		BCF		PORTA,1			; turn off buzz and clear desired beep length to 0
		CLRF	buzlen			;
		RETURN




; -----------------------------------------------------------------------------------
; Beep routine (piezo sounder for button presses)
; 	When called with a number in W, will start a beep for the duration W*10ms (or is it 5ms??)
beep
		MOVWF	beeplen
		CLRF	beeptim
		BSF		beepon,0
		RETURN

; -----------------------------------------------------------------------------------
; Beep timing routine
; 	Called every 5ms by the ISR. 
beepproc
		MOVF	beeplen,F		; if beeplen (the length of the beep we desire) is zero
		BTFSC	STATUS,Z		; 
		RETURN					; then return immidiately

		INCF	beeptim,F		; increment beeptim which times how long the current beep has been on

		MOVFW	beeplen			; if beeptim = beeplen,
		SUBWF	beeptim,W		;
		BTFSS	STATUS,Z		;
		RETURN					;
		BCF		beepon,0		; turn off beep and clear desired beep length to 0
		CLRF	beeplen			;
		RETURN



; -----------------------------------------------------------------------------------
; Button procedure
; 	Called every 5ms
; 	
buttonproc
	; BUTTON 0
		BTFSS	PORTE,0			; if the button is not being pressed, skip
		GOTO	b1start	

		BTFSC	butsta,0
		RETURN					; if the button was pressed last time, skip
	
		BCF		PORTA,1			; turn off the alarm

		MOVF	umode,F			; if in clock mode
		BTFSS	STATUS,Z
		GOTO	b0ninclock

		BTFSS	sync,0			; if clock is in sync
		RETURN

		MOVLW	.3				; beep for 15ms
		CALL	beep

		INCF	datefmt			; increment datefmt
		MOVLW	.4				; and wrap to zero if necessary
		SUBWF	datefmt,W
		BTFSC	STATUS,Z
		CLRF	datefmt
		
		CALL	disprightdt		; Update the date, hour, minute
		CALL	disprightse		; and seconds of the display, since display mode has changed

b0ninclock
		MOVLW 	.1				; leave if mode != 1 (which it won't be)
		SUBWF	umode,W
		BTFSS	STATUS,Z
		GOTO	b1start	

		MOVLW	.3				; beep for 15ms
		CALL	beep

		INCF	alcured,F			; cycle currently editable digit through 0,1,2,3
		MOVLW	.4
		SUBWF	alcured,W
		BTFSS	STATUS,Z
		RETURN
		CLRF	alcured

b1start
		; BUTTON 1
		BTFSS	PORTE,1			; if the button is not being pressed, skip
		GOTO 	b2start

		BTFSC	butsta,1
		RETURN					; if the button was pressed last time, skip

		BCF		PORTA,1			; turn off the alarm

		MOVLW 	.1				; leave if mode != 1
		SUBWF	umode,W
		BTFSS	STATUS,Z
		RETURN

		MOVLW	.2				; beep for 5ms
		CALL	beep

		MOVLW	.3
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 3
		GOTO	b1ard0
		MOVLW	.3
		MOVWF	cycllim
		MOVLW	alhrm
		MOVWF	dispdig
		CALL	incrdig

b1ard0
		MOVLW	.2
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 2
		GOTO	b1ard1
		MOVLW	.10
		MOVWF	cycllim
		MOVLW	alhrl
		MOVWF	dispdig
		CALL	incrdig

b1ard1
		MOVLW	.1
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 1
		GOTO	b1ard2
		MOVLW	.6
		MOVWF	cycllim
		MOVLW	alminm
		MOVWF	dispdig
		CALL	incrdig

b1ard2
		MOVLW	.0
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 0
		GOTO	b1ard3
		MOVLW	.10
		MOVWF	cycllim
		MOVLW	alminl
		MOVWF	dispdig
		CALL	incrdig
b1ard3

b2start
		; BUTTON 2
		BTFSS	PORTA,5			; if the button is not being pressed, skip
		GOTO	b3start

		BTFSC	butsta,3
		RETURN					; if the button was pressed last time, skip

		BCF		PORTA,1			; turn off the alarm

		MOVLW 	.1				; leave if mode != 1
		SUBWF	umode,W
		BTFSS	STATUS,Z
		RETURN

		MOVLW	.2				; beep for 10ms
		CALL	beep

		MOVLW	.3
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 3
		GOTO	b2ard0
		MOVLW	.3
		MOVWF	cycllim
		MOVLW	alhrm
		MOVWF	dispdig
		CALL	decrdig

b2ard0
		MOVLW	.2
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 2
		GOTO	b2ard1
		MOVLW	.10
		MOVWF	cycllim
		MOVLW	alhrl
		MOVWF	dispdig
		CALL	decrdig

b2ard1
		MOVLW	.1
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 1
		GOTO	b2ard2
		MOVLW	.6
		MOVWF	cycllim
		MOVLW	alminm
		MOVWF	dispdig
		CALL	decrdig

b2ard2
		MOVLW	.0
		SUBWF	alcured,W
		BTFSS	STATUS,Z	; if current editable digit = 0
		GOTO	b2ard3
		MOVLW	.10
		MOVWF	cycllim
		MOVLW	alminl
		MOVWF	dispdig
		CALL	decrdig
b2ard3
		CALL dispalm
b3start
		; BUTTON 3
		BTFSS	PORTE,2			; if the button is not being pressed, skip
		RETURN

		BTFSC	butsta,2
		RETURN					; if the button was pressed last time, skip

		BCF		PORTA,1			; turn off the alarm
	
		MOVLW	.3				; beep for 15ms
		CALL	beep

		INCF	umode,F			; cycle umode through 0,1
		MOVLW	.2
		SUBWF	umode,W
		BTFSS	STATUS,Z
		GOTO	b3mid
		CLRF	umode
b3mid
		BTFSC	umode,0		; if mode 1, dispalm
		CALL	dispalm
		BTFSC	umode,0		; and return
		RETURN
		CALL	disprightdt	; else display clock
		CALL	disprightse
		RETURN				; and return



incrdig
		MOVFW	dispdig
		MOVWF	FSR
		INCF	INDF,F
		
		MOVFW	cycllim		; if incremented version = cycllim, zero out
		SUBWF	INDF,W
		BTFSC	STATUS,Z
		CLRF	INDF
		RETURN




decrdig
		MOVFW	dispdig
		MOVWF	FSR
		MOVF	INDF,F			; if current version = 0, set to cycllim-1
		BTFSC	STATUS,Z
		GOTO	decrdigrst
		DECF	INDF,F
		RETURN
decrdigrst
		DECF	cycllim,W
		MOVWF	INDF
		RETURN


checkalarm
		MOVFW	alminm
		SUBWF	cminm,W
		BTFSS	STATUS,Z
		GOTO	turnalmoff
		MOVFW	alminl
		SUBWF	cminl,W
		BTFSS	STATUS,Z
		GOTO	turnalmoff
		MOVFW	alhrm
		SUBWF	chourm,W
		BTFSS	STATUS,Z
		GOTO	turnalmoff
		MOVFW	alhrl
		SUBWF	chourl,W
		BTFSS	STATUS,Z
		GOTO	turnalmoff

		BSF		PORTA,1
		RETURN
turnalmoff
		BCF		PORTA,1
		RETURN



; -----------------------------------------------------------------------------------
; DEBUGGING FUNCTION ONLY (should be commented out)
display
		MOVFW	dispdig
		ADDWF	dispdig,W
		ADDLW	lcddat
		MOVWF	disptmp
		INCF	disptmp,W		
		MOVWF	FSR				; put lcddat+2*dispdig+1 into FSR
		
		MOVFW	dispval
		MOVWF	disptmp
		MOVLW	B'00001111'
		ANDWF	disptmp,F
		MOVFW	disptmp
		MOVWF	INDF			; move dispval to disptmp, AND with mask, and move to INDF

		DECF	FSR,F			; move to 16s digit

		MOVFW	dispval
		MOVWF	disptmp
		MOVLW	B'11110000'
		ANDWF	disptmp,F
		SWAPF	disptmp
		MOVFW	disptmp
		MOVWF	INDF			; move dispval to disptmp, AND with mask, swap nibbles, and move to INDF
		RETURN


; -----------------------------------------------------------------------------------
; LED Update. (called LCD?!)
; 	Called at the start of the interrupt service routine
; 	Illuminates one (of the 12) 7-segment display by sending correct pattern to PORTB and
;	  correct enable signal to PORTC/PORTD. Each subsequent call illuminates the next digit
;	Also generates 1khz tone for piezo beep
lcdupdate
		CLRF	PORTC			; turn all off
		CLRF	PORTD
		
		MOVLW	lcddat			; movLw - move address of lcddat to W
		ADDWF	lcdct,W			; add counter to get current LED to be updated
		MOVWF	FSR				; move address of data needed to FSR
		
		MOVLW	HIGH lcdpattern
		MOVWF	PCLATH
		MOVFW	INDF			; moves data needed to W
		CALL	lcdpattern		; convert this data from BCD to 7-seg format
		MOVWF	PORTB			; ...and send to display.

		MOVLW	HIGH lcdselectdigc
		MOVWF	PCLATH
		MOVFW	lcdct			; get current digit
		CALL	lcdselectdigc	; convert to PORTC pattern
		MOVWF	PORTC			; send out to PORTC
		
		MOVLW	HIGH lcdselectdigd
		MOVWF	PCLATH
		MOVFW	lcdct			; get current digit
		CALL	lcdselectdigd	; convert to PORTD pattern
		MOVWF	PORTD			; send out to PORTD
		
		CLRF	PCLATH			; load PCLATH with data
								; to avoid messing up the next GOTO

		BTFSS	beepon,0
		GOTO	restofloop
		MOVFW	PORTD			; piezo driving current
		XORLW	B'10000000'
		MOVWF	PORTD
restofloop

		INCF	lcdct,F			; increment lcd count
		MOVLW	.12				
		SUBWF	lcdct,W			; compute count - 12
		BTFSS	STATUS,Z		; if result is zero, skip
		RETURN
		CLRF	lcdct			; reset counter to zero
		RETURN




		ORG	0x0800				; put LCD functions at the start of a page
								; to ensure no page-wrapping occurs (0x0800 = 2048 lines)

; -----------------------------------------------------------------------------------
; LED pattern. (called LCD?!)
; 	When called with a binary number in W, 
;	returns the corresponding 7-segment display pattern in W, to send to PORTB
lcdpattern
		ADDWF	PCL,F
		RETLW	B'01110111'		; 0 
		RETLW	B'00010010'		; 1 
		RETLW	B'11010101'		; 2 
		RETLW	B'11010011'		; 3 
		RETLW	B'10110010'		; 4 
		RETLW	B'11100011'		; 5 
		RETLW	B'11100111'		; 6 
		RETLW	B'00010011'		; 7 
		RETLW	B'11110111'		; 8 
		RETLW	B'11110011'		; 9 
		RETLW	B'10110111'		; A
		RETLW	B'11100110'		; b 
		RETLW	B'01100101'		; c 
		RETLW	B'11010110'		; d 
		RETLW	B'11100101'		; E 
		RETLW	B'10100101'		; F 
		RETLW	B'00000000'		; digit off
		RETLW	B'10000000'		; hyphen
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'00000000'		; digit off
		RETLW	B'01111111'		; 0. 
		RETLW	B'00011010'		; 1. 
		RETLW	B'11011101'		; 2. 
		RETLW	B'11011011'		; 3. 
		RETLW	B'10111010'		; 4. 
		RETLW	B'11101011'		; 5. 
		RETLW	B'11101111'		; 6. 
		RETLW	B'00011011'		; 7. 
		RETLW	B'11111111'		; 8. 
		RETLW	B'11111011'		; 9. 
		RETLW	B'10111111'		; A.
		RETLW	B'11101110'		; b. 
		RETLW	B'01101101'		; c. 
		RETLW	B'11011110'		; d. 
		RETLW	B'11101101'		; E. 
		RETLW	B'10101101'		; F. 
		RETLW	B'00001000'		; digit off with dot

; -----------------------------------------------------------------------------------
; LED select line for PORTC. (called LCD?!)
; 	When called with a binary number in W from 0 to 11, corresponding to one of the 
;		digits on the display that should be illuminated, 
;	returns the corresponding pattern for PORTC to illuminate that digit (nb some
;   digit enable transistors are connected to PORTD, so PORTC will be all zeros for these
lcdselectdigc
		ADDWF	PCL,F
		RETLW	B'00001000'
		RETLW	B'00000100'
		RETLW	B'00000010'
		RETLW	B'00000001'
		RETLW	B'10000000'
		RETLW	B'01000000'
		RETLW	B'00000000'
		RETLW	B'00000000'
		RETLW	B'00100000'
		RETLW	B'00010000'
		RETLW	B'00000000'
		RETLW	B'00000000'

; -----------------------------------------------------------------------------------
; LED select line for PORTD. (called LCD?!)
; 	When called with a binary number in W from 0 to 11, corresponding to one of the 
;		digits on the display that should be illuminated, 
;	returns the corresponding pattern for PORTD to illuminate that digit (nb most
;   digit enable transistors are connected to PORTC, so PORTD will be all zeros for these
lcdselectdigd
		ADDWF	PCL,F
		RETLW	B'00000000'
		RETLW	B'00000000'
		RETLW	B'00000000'
		RETLW	B'00000000'
		RETLW	B'00000000'
		RETLW	B'00000000'
		RETLW	B'00000010'
		RETLW	B'00000001'
		RETLW	B'00000000'
		RETLW	B'00000000'
		RETLW	B'00001000'
		RETLW	B'00000100'

		END




;		states:
;
;		1 - waiting for long pulse to signify minute start
;		2 - holding on long pulse (-> 3 or -> 1)
;		3 - watiting for new second marker
;		4 - sampling bits
;		5 - decoding (->3 or ->1)

;		1-8		increment dut1 on B
;		9-16	decrement dut1 on B
;		17-20	copy A to year 10s digit
;		21-24	copy A to year 1s digit
;		25		copy A to month 10s digit
;		26-29	copy A to month 1s digit
;		30-31	copy A to days 10s digit
;		32-35	copy A to days 1s digit
;		36-38	copy A to day-of-week
;		39-40	copy A to hour 10s digit
;		41-44	copy A to hour 1s digit
;		45-46	copy A to minute 10s digit
;		47-50	copy A to minute 1s digit
;		58		B is BST indicator

;	 
;	B7	Middle bar
;	B6	Bottom bar
;	B5	Top left
;	B4	Top right
;	B3	DP
;	B2	Bottom left
;	B1	Bottom right
;	B0	Top bar
;
;
;	D0	Bottom 2	
;	D1	Bottom 1
;	D2	Bottom 6
;	D3	Bottom 5
;	C0	Top 4
;	C1	Top 3
;	C2	Top 2
;	C3	Top 1
;	C4	Bottom 4
;	C5	Bottom 3
;	C6	Top 6
;	C7	Top 5




;;		DEBUGGING to diplay time of signal on/off
;		BTFSC	tmp1,0
;		GOTO	turnon
;
;		BTFSC	signal,0		; if the signal is on, move to stillon
;		GOTO	stillon
;
;		MOVFW	sigclk
;		MOVWF	dispval
;		MOVLW	.3
;		MOVWF	dispdig

;		CALL	display
;
;		BSF		tmp1,0
;		GOTO	stillon
;
;turnon
;		BTFSC	tmp1,1
;		GOTO	turnoff
;
;		BTFSS	signal,0		; if the signal is off, move to stillon
;		GOTO	stillon
;
;		MOVFW	sigclk
;		MOVWF	dispval
;		MOVLW	.4
;		MOVWF	dispdig
;		CALL	display
;
;		BSF		tmp1,1
;		GOTO	stillon
;
;turnoff
;		BTFSC	tmp1,2
;		GOTO	stillon
;
;		BTFSC	signal,0		; if the signal is on, move to stillon
;		GOTO	stillon
;
;		MOVFW	sigclk
;		MOVWF	dispval
;		MOVLW	.5
;		MOVWF	dispdig
;		CALL	display
;
;		BSF		tmp1,2
;		GOTO	stillon
;
;
;stillon
;
;;		END OF DEBUGGING




;		MOVFW	cursec			; debugging
;		MOVWF	lcddat+.11
;		MOVLW	B'00001111'
;		ANDWF	lcddat+.11,F

;		MOVFW	cursec
;		MOVWF	lcddat+.10
;		MOVLW	B'11110000'
;		ANDWF	lcddat+.10,F
;		SWAPF	lcddat+.10

;		MOVFW	sigclk
;		MOVWF	lcddat+.9
;		MOVLW	B'00001111'
;		ANDWF	lcddat+.9,F

;		MOVFW	sigclk
;		MOVWF	lcddat+.8
;		MOVLW	B'11110000'
;		ANDWF	lcddat+.8,F
;		SWAPF	lcddat+.8

;		MOVFW	mode
;		MOVWF	lcddat+.6
;		MOVLW	B'00001111'
;		ANDWF	lcddat+.6,F
