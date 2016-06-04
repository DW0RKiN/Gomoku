;  pasmo -d piskvorky.asm piskvorky.bin > test.asm ; ./bin2tap piskvorky.bin; ls -l piskvorky.bin
 
progStart 		equ	$C400		 ; 50176
org progStart


PLAYER_COLOR	equ	1*8
AI_COLOR		equ	2*8
MASK_COLOR		equ	$38

; Start game from basic
; RANDOMIZE USR 50378 (0xC4CA) = progStart + 202 (+ $00CA)

; ----------------------------------------------------
; Vstup: 	HL XY souradnice
;		A priznaky posunu
; Vystup:	pokud neni stisknuto FIRE tak zmeni jen registry A,HL

;	4	3	2	1	0
;	F(5)	↑(4)	↓(3)	→(2)	←(1)	Sinclair 1 (Sinclair left)
Pohyb:
; p_left:
	push	bc
	push	de
	
	ld	bc,$001f
	ld	d,a				; maska
	
	ld	a,l

	srl	d				; nastavi carry
	sbc	a,b
; p_right:
	srl	d				; nastavi carry
	adc	a,b
	
	and	c				; orezani do 0..31 pokud pretekl/podtekl
	xor	l
	and	c
	xor	l
	ld	l,a

; p_down:
	srl	d
	jr	nc,p_up
	adc	hl,bc
p_up:
	srl	d
	jr	nc,p_fire
	sbc	hl,bc
p_fire:


; 57 0101 0111 +3 -> 5A 0101 1010
; 58 0101 1000
; 59 0101 1001
; 5A 0101 1010
; 5B 0101 1011 -3 -> 58 0101 1000

IF 0
	ld	a,h
	cp	$58
	sbc	a,b				; 57 -> 56 0110
	cp	$5B
	ccf
	adc	a,b				; 5B -> 5C 1100
	and	$03
	or	$58
	ld	h,a
ENDIF

	ld	a,h
	cp	$57
	jr	nz,p_nepodtekl
	ld	h,$5A				; Y max
p_nepodtekl:
	cp	$5B
	jr	nz,p_nepretekl
	ld	h,$58				; Y min
p_nepretekl:
	

	srl	d
	
	pop	de
	pop	bc
	ret	nc				; pokud neni stisknuto FIRE tak zmeni jen registry A,HL

	ld	a,(hl)
	or	a
	ret	nz				; neprepisujeme kameny
	ld	(hl),PLAYER_COLOR		; PLAYER_COLOR = 2

; Zjednodusene nalezeni nejlepsiho tahu
; Find_best:
	ld	hl,$5800
	ld	b,l				; = 0
	ld	c,l				; Existuje_rada_5_kamenu = False
	push	hl				; nejlepsi pozice

brain_loop:
	
; ------------------------------------
; Vystup:	ixh
; Zmeni:	IX, AF, DE
; Count_value:	
	ld	ixh,c				; vynulujeme hodnotu pozice

	ld	de,data_priznak_smeru
cv_loop:
	ld	a,(de)
	ld	(el_selfmodifying+1),a
	inc	de
	ld	a,(de)
	inc	de
	
	push	hl
	exx
	pop	hl				; stinovy hl = normalni hl

; ------------------------------------
; Vstup:	HL = XY
; 		A opacny smer
Explore_line:
; "zpetny chod"
	ld	b,5
	ld	c,a
el_na_okraj:
	ld	a,c				; nastaveni smeru
	call	Pohyb				;
	djnz	el_na_okraj
	

; odted pujdeme na druhou stranu a stale v jednom smeru

; inicializace smycky
	push	hl

	ld	hl,$0010			; hl hodnota souvisle rady, dame bonus pro ; dame bonus pro xxxx_ xxx._ xx.._ x..._
	ld	d,h				; = 0 hodnota linie
	ld	e,h				; = 0 prazdnych
	ld	ixl,b				; = 0 delka rady
	ld	c,b				; = 0 nalezeny kamen
	ld	b,$09				; citac

IF 0
	; inicializace podvrzenim el_ruzne
	ld	a,b				; musi byt nula a nesmi byt nula! ( jakoby hodnota z fce next_step )
	ld	ixl,b				; = delka rady ( cokoliv mensi jak 6 )
	ld	b,$09				; citac a hodnota dalsiho kamene
	ld	c,b				; = nalezeny kamen ( zde cokoliv nenuloveho )
	ld	e,$FF
; 	nastavi podvrzeni
; 	ld	hl,$0010			; hl hodnota souvisle rady, dame bonus pro ; dame bonus pro xxxx_ xxx._ xx.._ x..._
; 	ld	d,h				; = 0 hodnota linie
; 	ld	e,h				; = 0 prazdnych	
ENDIF
	
	
el_loop:
	inc	ixl				; zvedneme delku rady

el_selfmodifying:
	ld	a,0				; nastaveni smeru
	ex	(sp),hl
	call	Pohyb		
	ld	a,(hl)				; 
	and	MASK_COLOR			; chceme jen barvu PAPER
	ex	(sp),hl
	jr	nz,el_nasel_kamen

; ---------------
; el_prazdne:
	
	inc	e				; prodlouzime radu prazdnych
	add	hl,hl				; bonus za stred

	ld	a,b				; 
	cp	5
	jr	z,el_next			;

	add	hl,de				; H = H + D, v L a E (pocet prazdnych) je "smeti" jehoz soucet nikdy nepretece pres bajt. Pokud se sejdou jednickove bity tak je L nizke. 
	ld	d,h
	
	ld	hl,$0010			; dostane bonus i pro priste
	jr	el_next	

; ---------------
el_nasel_kamen:					; A je nenulove
	cp	c				; shodne kameny?
	jr	z,el_shodne

	inc	c
	dec	c				; pokud tam byla 0 mame prvni kamen
	ld	c,a				; ulozime novy kamen
	jr	z,el_shodne			; prvni kamen, jinak by to blblo pri rade ._x. udelalo by to .x.

; ---------------
el_ruzne:
	call	pricti_hodnotu_rady
	
	ld	hl,$0008
	ld	d,h

	inc	e				; 
	ld 	ixl,e				; delka nove rady = prazdnych + 1 kamen
	dec	e
	jr	z,el_shodne
	
	add	hl,hl				; dame bonus 2x protoze zacal prazdnym

; ---------------
el_shodne:

	ld	e,0				; vymazeme radu prazdnych
	add	hl,hl
	add	hl,hl
	
	ld	a,h
	cp	$20
	jr	c,el_next
	
; Nalezena rada 5 kamenu (asi)
	exx
	ld	a,(hl)
	or	a				;
	jr	z,el_prazny
	
	set	6,(hl)				; zesvetlime kamen
	ld	c,$01				; Existuje_rada_5_kamenu = True
el_prazny:
	exx

el_next:
	djnz	el_loop
	
	add	hl,hl				; dame bonus pro _xxxx _.xxx _..xx _...x
	call	pricti_hodnotu_rady
	
	pop	hl

; end Explore_line --------------------------------------------
	exx
	
	ld	a,data_end mod 256
	cp	e
	jr	nz,cv_loop

; end Count_value ----------------------------------------------

	ld	a,(hl)
	or	a
	jr	nz,b_next			; pokud je na pozici kamen tak uz vse ignorujeme a deme dal, test na existenci rady 5 kamenu uz probehl

	ld	a,ixh
	cp	b
	jr	c,b_next			; pokud zname lepsi tak ignorujeme

; aktualne nejlepsi pozice
	pop	de				; vytahneme nejlepsi a zahodime
	push	hl				; ulozime lepsi
	ld	b,a
b_next:
	inc	hl
	ld	a,$5B				; $5800 + 3 * 256 = $5800 + $0300
	cp	h
	jp	nz,brain_loop

; C = 0, 1
	dec	c				; Existuje_rada_5_kamenu == True?
	
	pop	hl				; vytahneme nejlepsi ze zasobniku
	ld	(hl), AI_COLOR			;

	ret	nz				; C = $00, $ff
	ld	(hl),c				; = 0, zmensime pravdepodobnost ze 1/50 vteriny bude videt pixel navic nez smazem obrazovku
; propadnuti na Repeat_game


; --------------------------------
Repeat_game:
	pop	hl				; vytahneme nepouzitou adresu navratu pro ret

New_game:
; clear screen
	ld	hl,$4000			; 3
	ld	a,$5B				; 2
clear_loop:
	ld	(hl),$00			; 2
	inc	hl				; 1
	cp	h				; 1
	jr	nz,clear_loop			; 2

IF 0
; clear screen
	ld	bc,192*32+3*256-1		; 3
	ld	de,$4001			; 3
	ld	hl,$4000			; 3
	ld	(hl),l				; 1 = 0
	ldir					; 2
						; BC = 0
ENDIF

; umistime na stred a polozime kamen AI
	ld	hl,$598F
	ld	(hl),AI_COLOR		
					
Cti_vstup:
	ld	e,(hl)
	ld	(hl),$B8			; 

	ld	bc,0xf7fe			;
	in	a,(c)				;
	cpl
	cp	d
	ld	d,a
	
	ld	(hl),e				; vratim puvodni
	
	call	nz,Pohyb	
	jr	Cti_vstup


; -------------------------------
pricti_hodnotu_rady:

	ld	a,ixl				; delka rady
	cp	$06				; je tam pricten uz i odlisny kamen
	ret	c				; pokud ma rada i s mezerama delku kratsi jak 5 tak nema zadnou hodnotu

	add	hl,de				; H = H + D, v L a E (pocet prazdnych) je "smeti" jehoz soucet nikdy nepretece pres bajt. Pokud se sejdou jednickove bity tak je L nizke. 
	ld	d,h
	add	ix,de				; IXH = IXH + D, IXL si zaneradime souctem puvodni delky rady s poctem jeho prazdnych poli, ale bude se menit

	ret


;	4	3	2	1	0
;	F(5)	↑(4)	↓(3)	→(2)	←(1)	Sinclair 1 (Sinclair left)
data_priznak_smeru:
db	1,2,4,8,5,10,6,9			; 1&2,4&8,5&10,9&6
data_end:
