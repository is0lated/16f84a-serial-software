;all send signal values have been inverted

;b7 rx
;b6 tx

org 0000h
	goto setup

org 0004h
	movwf	4dh		;save the wreg
	movf	1h, 0	;get tmr0 in case it's the first bit recieved
	btfsc	0bh, 0	;check whether it's a RBIF interrupt
	;btfsc	4fh, 7
	goto	setupRecieve	;if it is set up recieving
timingInterruptCheck
	btfss	4eh, 1	;check whether recieving is currently happening
	goto	sendInterrupt

	btfsc	4eh, 0	;check whether a bit was recieved last interrupt
	goto	sendInterrupt

	goto	recieveInterrupt

setupRecieve
;first check to make sure recieving isn't already happening
	btfsc	4eh, 1
	goto	timingInterruptCheck

;setup the values to preload tmr0 with
	;addlw	0x01
	movwf	47h
	movf	48h, 0
	subwf	47h, 0
	sublw   0xff
	movwf	46h
;hopefully this will fix tmr0 lasting too long
	;movlw	0x01
	;addwf	47h, 1

;turn off RBIE interrupts and clear the flag
	bcf		0bh, 3
	movf	06h, 0
	bcf		0bh, 0

	call	recieveBit

	movf	4dh, 0	;restore wreg
	retfie

sendInterrupt
;preload tmr0
	movf	46h, 0
	movwf	01h

;clear tmr0 interrupt flag
	bcf		0bh, 2

	call	sendBit

;clear the just recieved flag
	bcf		4eh, 0

	movf	4dh, 0	;restore wreg
	retfie

recieveInterrupt
;preload tmr0
	movf	47h, 0
	movwf	01h

;clear tmr0 interrupt flag
	bcf		0bh, 2

	call	recieveBit

	movf	4dh, 0	;restore wreg
	retfie

setup
	clrf	06h		;cler port b
	bcf		06h, 6	;set to ttl default		;inverted

	clrf	01h

;delay just in case the transmit pin was high during power up
startdelay
	movlw	0xff
	movwf	4fh
	movwf	4eh
	movlw	0x01
sdloop1
	subwf	4eh, 1
	btfss	03h, 2
	goto	sdloop1
sdloop2
	subwf	4fh, 1
	btfss	03h, 2
	goto	sdloop1

	clrf	01h

;setup tmr0 delay values
	movlw	0x31
	movwf	46h
	clrf	47h
	movwf	48h

;clear the sending and recieving status bytes
	clrf	49h
	clrf	4bh

	clrf	4eh
	bsf		4eh, 2

	bsf		03h, 5	;change to bank 1

	;set timer prescaler to 1:8 and set it to instruction count
	bcf		81h, 5
	bcf		81h, 3
	bcf		81h, 2
	bsf		81h, 1
	bcf		81h, 0

	;enable interrupts and enable tmr0 overflow and RB0/INT interrupt
	clrf	8bh
	bsf		8bh, 3
	bsf		8bh, 5
	bsf		8bh, 7

	;set the port a tris register
	movlw	0x80
	movwf	86h

	bcf		83h, 5	;change to bank 0

main
mainWaitForRecievedByte
	btfss	4eh, 3	;check whether a byte has been recieved
	goto	mainWaitForRecievedByte

	call	getRecievedByte

mainWaitForClearSend
	call	checkSendClear
	btfsc	4eh, 4	;Check whether checkSendClear succeded
	goto	mainWaitForClearSend

	;movlw	'H'
	call	sendByte
	goto	main

;When calling put the byte for sending in wreg
checkSendClear
;check whether the previous byte has finished sending
	btfss	4eh, 2
	goto	checkSendClearFail
checkSendClearSuccess
	bcf		4eh, 4
	return
checkSendClearFail
	bsf		4eh, 4	;record that this was a failure
	return

sendByte
;temporary test sending
	;movlw	'H'
	movwf	4ah
	bsf		49h, 4	;let the send loop know there's something to send
	bcf		43h, 2	;let the checkSendClear know there's a byte being sent
	return

getRecievedByte
	movf	4ch, 0	;move the recieved byte into wreg
	bcf		4eh, 3
	return

sendBit
	btfss	49h, 4	;check whether there's something to send
	return			;if not, just go back

	btfss	49h, 5	;check whether the start bit has been sent
	goto	sendStartBit	;if it hasn't been sent, send the start bit

	btfsc	49h, 6	;check whether we just sent the stop bit
	goto	sentStopBit	;reset everything

	btfsc	49h, 3	;check whether we've sent 8 bits
	goto	sendStopBit		;if so, send the stop bit

	btfss	4ah, 0
	goto	sendLowBit

sendHighBit
	bcf		06h, 6				;inverted
	movlw	0x01
	addwf	49h, 1
	rrf		4ah, 1
	goto	sendBitEnd

sendLowBit
	bsf		06h, 6				;inverted
	movlw	0x01
	addwf	49h, 1
	rrf		4ah, 1

sendBitEnd
	return

sendStartBit
	bsf		06h, 6				;inverted
	bsf		49h, 5

;clear the send complete bit
	bcf		4eh, 2

	goto	sendBitEnd

sendStopBit
	bcf		06h, 6				;inverted
	bsf		49h, 6

;record that the byte has completed sending
	bsf		4eh, 2
	goto	sendBitEnd

sentStopBit
	clrf	49h
	goto	sendBitEnd
	
recieveBit
;let the interrupt handler know that recieving it happening and this was a recieve interrupt
	bsf		4eh, 0
	bsf		4eh, 1

;check whether this is the first bit recieved (start bit)
	movf	4bh, 1
	btfsc	03h, 2
	goto	recieveStartBit

;check whether 8 bits have already been recieved
	btfsc	4bh, 3
	goto	recieveStopBit

;check whether the bit is high or low
	btfss	06h, 7
	goto	recieveLowBit
recieveHighBit
	bsf		4ch, 0
	rlf		4ch, 1
	movlw	0x01
	addwf	4bh, 1
	goto	recieveBitEnd

recieveLowBit
	bcf		4ch, 0
	rlf		4ch, 1
	movlw	0x01
	addwf	4bh, 1
recieveBitEnd
	return

recieveStartBit
	clrf	4ch

;clear recieve complete bit
	bcf		4eh, 3
;Mark that the start bit was recieved
	bsf		4bh, 5

	goto	recieveBitEnd

recieveStopBit
;reset ntmr0
	movf	48h, 0
	movwf	46h

;tell the interrupt handler that no recieving is happening
	bcf		4eh, 1

;clear the recieving status register
	clrf	4bh

;enable RB0/INT interrupts again
	bsf		0bh, 3

;set recieve complete bit
	bsf		4eh, 3

	goto	recieveBitEnd


;damn picky compilers
	end
