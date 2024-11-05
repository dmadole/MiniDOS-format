

loader:    ldi   0ffh
           plo   r2
           ghi   r0
           phi   r2

           phi   r6
           ldi   start
           plo   r6

           lbr   f_initcall

setup:     ldi   0e0h
           phi   r8

           ldi   0
           str   r2
           out   4
           dec   r2

           plo   r7
           phi   r7
           plo   r8

           plo   rf
           ldi   300h.1
           phi   rf

rdloop:    inc   r7

           sep   scall               ; call bios to read sector
           dw    f_ideread
           bdf   $

           glo   r7
           str   r2
           out   4
           dec   r2

           smi   14
           bnz   rdloop

           plo   r0
           ldi   300h.1
           phi   r0

           sep   r0

