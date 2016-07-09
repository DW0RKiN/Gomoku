Gomoku
======

Minimalistické piškvorky pod 256 bajtů nepoužívající žádnou ROM rutinu nebo paměť obsahující font. Omezení vyplývá ze zadání:

	Z80 Assembly Programming On The ZX Spectrum
	Adrian Brown
	11 květen · Lewannick, Anglie, Spojené království
	
	COMPO #6 - 256 byte game compo
	DEADLINE: 12:00 GMT 17th June 2016
	1) No ROM routines (else their size will be added on)
	2) No using the ROM as data.
	3) Its whatever you can do in 256 bytes of code / data, basically the binary must be no more than 256 bytes.
	4) HALT may be used to time with IM1, but nothing else such as system variables for keyboard can be used.

Entries should be emailed to adrian zavináč apbcomputerservices.co.uk with the subject "Z80ASM COMPO"
After the deadline anyone can vote, 3 points for their favourite, 2 points for their 2nd and 1 for 3rd (This may change depending on the number of entries). The entry with the most votes wins.
NOTE: This is not a challenge to make it the smallest, its a challenge to make it as good as possible in 256 bytes!

Trošku tvrdé podmínky, zvlášť když jsem ani netušil jak napsat ovladač klávesnice. Na netu jsem nakonec našel, že je klávesnice fyzicky rozdělena na osm částí po pěti klávesách a čtou se:

	LD BC,Port
	IN A,(C)
	
Kde port:

	Port   Binary                               Bity po cteni v registru A
	                                            0     1     2     3     4
	$FEFE  1 1 1 1 1 1 1 0  1 1 1 1 1 1 1 0     Shift Z     X     C     V
	$FDFE  1 1 1 1 1 1 0 1  1 1 1 1 1 1 1 0     A     S     D     F     G
	$FBFE  1 1 1 1 1 0 1 1  1 1 1 1 1 1 1 0     Q     W     E     R     T
	$F7FE  1 1 1 1 0 1 1 1  1 1 1 1 1 1 1 0     1     2     3     4     5
	$EFFE  1 1 1 0 1 1 1 1  1 1 1 1 1 1 1 0     0     9     8     7     6
	$DFFE  1 1 0 1 1 1 1 1  1 1 1 1 1 1 1 0     P     O     I     U     Y
	$BFFE  1 0 1 1 1 1 1 1  1 1 1 1 1 1 1 0     Enter L     K     J     H
	$7FFE  0 1 1 1 1 1 1 1  1 1 1 1 1 1 1 0     Space Sym   M     N     B

Pokud po čtení obsahuje nějaký bit registru A nulu tak to signalizuje stisk klávesy. Pokud se před čtením přidá do vyššího bajtu portu (do registru "B") víc nulovych bitů tak se čte najednou víc částí, ale už nejde rozlišit zda bit 4 signalizuje klávesů V nebo G například.

Později jsem se dozvěděl, že existuje o bajt kratší varianta:

	LD A,HiBytePort
	IN A,(LoBytePort) 

Celý program je samý kompromis vynucený omezenou délkou. Pro ovládání jsem zvolil kombinaci kláves 5 (Fire), 4 (↑), 3 (↓), 2 (→), 1 (←). Které jdou testovat jedním čtením a na které se zároveň mapuje Sinclair 1 (Sinclair left) joystick. Díky tomu lze použít registr A jako parametr funkce MOVE. 

Na jemnou a komplikovanou pixelovou grafiku nebylo místo a tak se používá pouze lineární atributová část paměti na adrese $5800..$5AFF. To znamena že grafika zhrubla na matici 32 x 24 znaků. V párovém registru HL je uložen aktualní lineární index ukazující na aktuální adresu. Funkce MOVE podle invertované hodnoty v registru A posune index tak, aby vytvořil nekonečné pole. Přelezením přes jeden okraj se ukážeme na druhé straně. Nemusí se pak řešit mezní stavy hrací plochy a boj v rozích je jen pro hardcore hráče. .) Pokud není bit 4 (Fire) aktivní tak funkce MOVE nemění jiné registry. 

Jinak "propadává" do hlavní smyčky hledající nejlepší tah. Žádný minimax nebo alfabeta, ale pouze ta nejjednoduší heuristika. Aby se ušetřilo tak si program nikam neukládá hodnoty nejlepších protitahů a neaktulizuje pouze 32 polí v osmiokolí posledního tahu, ale prohledává znovu pokaždé cele hrací pole 32 x 24. Je tak 24x pomalejší než by měl a trvá mu to cca 4 vteřiny než propočítá vše. Zároveň se snaží zjistit zda už neexistuje línie pěti kamenů signalizující konec hry. To má za následek, že když vytvoří pětici hráč tak na ni program přijde hned a když počítač tak až v příštím tahu. Takže existuje remíza a proto počítač začíná jako první.

Základní heuristika je založena na principu, že v testovaném místě prohledá čtyři základní směry. Prvně se přesune index na okraj o 4 kameny a pak prohledává 9 kamenů opačným směrem. Hledá souvislé kameny a je jedno zda hráče nebo počítače. Záleží jen na tom aby byly shodne. A nejlepší řady se snaží prodloužit, pokud jsou jeho a nebo zablokovat pokud jsou soupeře. Nevýhoda toho řešení je u posledních tahů. Může se stát že bude blokovat soupeřovu oboustraně volnou čtyřku, místo toho aby prodloužil svoji z jedné strany volnou čtveřici (která ma nižší ohodnocení) a uhrál remízu. A naopak místo aby zablokoval jednostraně volnou soupeřovu čtyřku, tak vytvoří svoji pětici i když byla z obou stran neblokovaná a tím zbytečně remízuje. Řešení by bylo upřednosťnovat jednostraně volné čveřice před oboustraně volnýma, ale na to není místo...

Aby program nehrál v počátcích úplně náhodně tak upřednostňuje pokud nový kámen bude vedle existujícího a ne úplně v prostoru. Hlavní smyčka je napsána tak, že pokud hráč zahraje pod prvním tahem počítače (středem) a dál od něj, tak počítač bude blokovat jeho tah, takže lze tímto vynutit "zahájení" hry. Pokud to udělá naopak tak daruje tah počítači.
