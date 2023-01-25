
;  Copyright 2021, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


          ; Include BIOS and kernal API entry points

            #include include/bios.inc
            #include include/kernel.inc


          ; Define non-published API elements

d_ideread:  equ   0447h
d_idewrite: equ   044ah


          ; Executable program header

            org   2000h - 6
            dw    start
            dw    end-start
            dw    start

start:      org   2000h
            br    main

          ; Build information

            db    1+80h              ; month
            db    13                 ; day
            dw    2023               ; year
            dw    1                  ; build

            db    'See github.com/dmadole/Elfos-format for more info',0

          ; Main program


main:       ghi   ra
            phi   rf
            glo   ra
            plo   rf

skipsp1:    lda   rf
            lbz   missopt
            sdi   ' '
            lbdf  skipsp1

            sdi   ' '-'/'
            lbnz  missopt

            lda   rf
            smi   '/'
            lbnz  missopt

            sep   scall
            dw    f_atoi
            lbdf  missopt

            lda   rf
            lbz   startit

            smi   '/'
            lbnz  missopt

skipsp2:    lda   rf
            lbz   startit
            sdi   ' '
            lbdf  skipsp2

missopt:    sep   scall
            dw    o_inmsg
            db    'Usage: format //drive',13,10,0

            sep   sret

startit:    glo   rd
            ori   0e0h
            phi   r8

            ldi   buffer.1
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall
            dw    f_uintout

            ldi   '!' 
            str   rf
            inc   rf

            ldi   0
            str   rf

            sep   scall                 ; send warning
            dw    o_inmsg
            db    "PROCEEDING WILL OVERWRITE THE CONTENTS OF DISK ",0

            ldi   buffer.1
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall
            dw    o_msg

yousure:    sep   scall                 ; prompt for confirmation
            dw    o_inmsg
            db    13,10,"Type YES to continue or ^C to abort: ",0

            ldi   buffer.1              ; buffer for input string
            phi   rf
            ldi   buffer.0
            plo   rf

            ldi   3.1                   ; only accept up to 3 bytes
            phi   rc
            ldi   3.0
            plo   rc

            sep   scall                 ; get input, if control-c then abort
            dw    o_inputl
            lbnf  proceed

            sep   scall                 ; acknowledge control-c typed
            dw    o_inmsg
            db    "^C",13,10,0

            sep   sret                  ; return

          ; Check the input string to make sure it's exactly "YES", if
          ; it's not then send the confirmation prompt again.

proceed:    ldi   buffer.1              ; pointer to buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            lda   rf                    ; first character
            xri   'Y'
            lbnz  yousure

            lda   rf                    ; second character
            xri   'E'
            lbnz  yousure

            lda   rf                    ; last character
            xri   'S'
            lbnz  yousure

            lda   rf                    ; terminating zero
            lbnz  yousure

            sep   scall                 ; echo return from input
            dw    o_inmsg
            db    13,10,0


          ; Get the size of the source disk so we know how many allocation
          ; units we need to consider copying.

            ldi   0
            plo   r8
            phi   r7
            plo   r7

            plo   rb
            phi   rb
            ldi   4
            plo   rc

trysize:    sep   scall
            dw    xorsize

            ldi   sector.1
            phi   rf
            ldi   sector.0
            plo   rf

            sep   scall
            dw    d_ideread

            lbnf  yessize

            sep   scall
            dw    xorsize

yessize:    glo   rc
            shr
            plo   rc
            ghi   rb
            shrc
            phi   rb
            glo   rb
            shrc
            plo   rb

            lbnf  trysize

            inc   r7                    ; add one to change to total sectors

            glo   r7
            lbnz  notover
            ghi   r7
            lbnz  notover
            inc   r8


notover:    glo   r8                    ; is disk the maximum size
            smi   8
            lbnz  notmaxi

            dec   r7
            dec   r8




notmaxi:    glo   r7                    ; make integral number of aus
            ani   255-7
            plo   r7



            glo   r8                    ; save sector count
            plo   ra
            ghi   r7
            phi   r9
            glo   r7
            plo   r9



            glo   r8                    ; get number of aus
            shr
            plo   re
            ghi   r7
            shrc
            phi   rb
            glo   r7
            shrc
            plo   rb

            glo   re
            shr
            plo   re
            ghi   rb
            shrc
            phi   rb
            glo   rb
            shrc
            plo   rb

            glo   re
            shr
            plo   re
            ghi   rb
            shrc
            phi   rb
            glo   rb
            shrc
            plo   rb





            ldi   0
            phi   rd
            ghi   rb
            plo   rd

            ldi   buffer.1              ; pointer to buffer for sector
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall
            dw    f_uintout

            ldi   0
            str   rf

            ldi   buffer.1              ; pointer to buffer for sector
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall
            dw    o_inmsg
            db    "Disk is ",0

            sep   scall
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    " MB, ",0




            ghi   rb
            phi   rd
            glo   rb
            plo   rd

            ldi   buffer.1              ; pointer to buffer for converston
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall
            dw    f_uintout

            ldi   0
            str   rf

            ldi   buffer.1              ; pointer to buffer for output
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    " AU, ",0


            glo   rb                    ; needs to be at least four aus
            smi   4
            ghi   rb
            smbi  0
            lbdf  format

            sep   scall
            dw    o_inmsg
            db    'Must be at least 4 AU.',13,10
            db    'ERROR: Cannot create filesystem.',13,10,0
            sep   sret



format:     sep   scall
            dw    o_inmsg
            db    "fast formatting... ",0


          ; Get number of sectors that will be used for the LAT table to 
          ; hold the AU usage information. There are 256 entries per sector.

            ldi   0                     ; divide number of aus by 256
            phi   rc
            ghi   rb
            plo   rc

            glo   rb                    ; if there is a fraction, round up
            lbz   evenaus
            inc   rc


          ; Calculate the sector that the master directory should be put
          ; into. This will be the first allocation until following the
          ; LAT table.

evenaus:    glo   rc                    ; sector just past last au sector
            adi   17
            plo   rd
            ghi   rc
            adci  0
            phi   rd

            glo   rd                    ; does it fall on an au boundary
            ani   7
            lbz   noround

            glo   rd                    ; round up to first sector of next au
            ani   255-7                 ;  if not
            adi   8
            plo   rd
            ghi   rd
            adci  0
            phi   rd


          ; The first page of the boot sector is reserved for the boot loader
          ; code which we will not install, so just fill with zeroes. The
          ; sys program, which installs the kernel, has been updated to also
          ; install the boot loader code.

noround:    ldi   sector.1              ; point to start of sector
            phi   rf
            ldi   sector.0
            plo   rf

loader:     ldi   0                     ; fill with zeroes
            str   rf
            inc   rf

            glo   rf                    ; until one page is filled
            xri   sector.0
            lbnz  loader


          ; The second page of the boot sector contains disk information
          ; including size and location of the root directory. Create
          ; the basic descriptive information next.

            ldi   0                     ; number of sectors on device
            str   rf
            inc   rf
            glo   ra
            str   rf
            inc   rf
            ghi   r9
            str   rf
            inc   rf
            glo   r9
            str   rf
            inc   rf
           
            ldi   1                     ; filesystem type 1
            str   rf
            inc   rf

            ghi   rd                    ; sector of master directory
            str   rf
            inc   rf
            glo   rd
            str   rf
            inc   rf

            ldi   0                     ; reserved
            str   rf
            inc   rf
            str   rf
            inc   rf
            str   rf
            inc   rf

            ldi   8                     ; sectors per lump, which is fixed
            str   rf
            inc   rf

            ghi   rb                    ; total usable aus on disk
            str   rf
            inc   rf
            glo   rb
            str   rf
            inc   rf

mdfills:    ldi   0                     ; fill empty space with zeroes
            str   rf
            inc   rf

            glo   rf                    ; go until 12ch where the master
            xri   (sector+12ch).0       ;  directory entry starts
            lbnz  mdfills


          ; Now create the master directory entry, which is just like any
          ; other directory entry, but for the root directory, and stored
          ; in the boot sector.

            ghi   rd                    ; get au of master directory by
            shr                         ;  dividing sector by eight
            phi   rd
            glo   rd
            shrc
            plo   rd

            glo   rd                    ; after the first shift, the 
            shrc                        ;  high byte will always be zero
            plo   rd
            glo   rd
            shrc
            plo   rd


            ldi   0                     ; au of the master directory
            str   rf
            inc   rf
            str   rf
            inc   rf
            ghi   rd
            str   rf
            inc   rf
            glo   rd
            str   rf
            inc   rf

            ldi   0                     ; directory file length is zero
            str   rf
            inc   rf
            str   rf
            inc   rf
 
            ldi   1                     ; set directory bit in flags
            str   rf
            inc   rf

            ldi   0                     ; zero the date and time for now,
            str   rf                    ;  there is nothing that shows this
            inc   rf
            str   rf
            inc   rf
            str   rf
            inc   rf
            str   rf
            inc   rf


          ; Lastly, fill out the remainder of the sector with zeroes and
          ; write it to disk in the master sector.

padfill:    ldi   0                     ; fill with zeros
            str   rf
            inc   rf

            glo   rf                    ; until end of sector buffer
            xri   sector.0
            lbnz  padfill

            plo   r8                    ; write to sector zero
            phi   r7
            plo   r7

            ldi   sector.1              ; get pointer to start of sector
            phi   rf
            ldi   sector.0
            plo   rf

            sep   scall                 ; write sector to disk
            dw    d_idewrite

            inc   r7                    ; move to next sector


          ; Fill the reserved kernel area with zeroed blocks. This will halt
          ; the system cleanly if the media is booted without every having
          ; a kernel written, and is also neater than having random garbage
          ; after the end of the kernel (which gets loaded to memory also).

            ldi   sector.1              ; get pointer to buffer
            phi   rf
            ldi   sector.0
            plo   rf

            ldi   0                     ; fill sector buffer
            plo   r9

zerfill:    ldi   0                     ; fill with zeroes
            str   rf
            inc   rf
            str   rf
            inc   rf

            glo   r9                    ; continue until done
            dec   r9
            lbnz  zerfill

kernel0:    ldi   sector.1              ; reset sector buffer pointer
            phi   rf
            ldi   sector.0
            plo   rf

            sep   scall                 ; write sector
            dw    d_idewrite

            inc   r7                    ; move to next, stop before we get
            glo   r7                    ;  to start of lat table
            xri   17
            lbnz  kernel0


          ; Next we need to write the LAT table used to track the AU usage
          ; starting at sector 17 on disk. Each usable AU needs to be 
          ; marked as 0000 and each unusable as FFFF. As special cases, we
          ; also need to mark the roto directory file as the last AU in
          ; the file with FEFE, and need to mark the special marker AU 
          ; value which is FEFE as unsuable so it's never allocated.

            ldi   0                     ; used to count up aus as they are
            plo   ra                    ;  are marked in table
            phi   ra

            ldi   sector.1              ; set sector buffer pointer
            phi   rf
            ldi   sector.0
            plo   rf


          ; Create the first sector of the LAT table by marking the AUs
          ; unavailable from the start of the disk up until just before the
          ; AU that contains the root directory. Then mark the root directory
          ; file AU as the last in the file. Next mark the free AUs through
          ; the last usable AUs. If this does not fill the sector, lastly
          ; mark the remaining entries as unusable.

markuse:    ldi   0ffh                  ; mark used aus with 0ffffh
            str   rf
            inc   rf
            str   rf
            inc   rf

            inc   ra                    ; count up entries in sector,
            dec   rb                    ;   count down all aus written

            dec   rd                    ; keep writing until just before
            glo   rd                    ;  the root directory au
            lbnz  markuse

            ldi   0feh                  ; mark the root directory au as the
            str   rf                    ;  last au in the file
            inc   rf
            str   rf
            inc   rf

            inc   ra                    ; count up entries in sector,
            dec   rb                    ;   count down all aus written

markfre:    ldi   0                     ; mark unused aus with 0000h
            str   rf
            inc   rf
            str   rf
            inc   rf

            inc   ra                    ; count up entries in sector,
            dec   rb                    ;   count down all aus written

            glo   ra                    ; stop if we reached end of sector
            lbz   donesec

            glo   rb                    ; otherwise go until all usable
            lbnz  markfre               ;  aus are accounted for
            ghi   rb
            lbnz  markfre

markpad:    ldi   0ffh                  ; if all aus marked free and still
            str   rf                    ;  not at end of sector, mark the
            inc   rf                    ;  rest as unavailable
            str   rf
            inc   rf

            inc   ra                    ; keep marking until end of sector
            glo   ra
            lbnz  markpad

donesec:    sep   scall                 ; write the sector
            dw    writesec


          ; If there are enough usable AUs still to mark that we will have
          ; entire sectors worth, then special case those here since they
          ; will all be all zeroes so we can reuse the same buffer and only
          ; count whole sectors worth, which will be much faster.

            ghi   rb                    ; is there less than a full sector
            lbz   partial               ;  of free entries left to write?

            ldi   0                     ; count 256 entries in a sector
            plo   r9

fillfre:    ldi   0                     ; mark entries as available
            str   rf
            inc   rf
            str   rf
            inc   rf

            dec   r9                    ; continue until sector is filled
            glo   r9
            lbnz  fillfre

writfre:    ghi   ra                    ; increment current au by a whole
            adi   1                     ;  sector worth
            phi   ra

            ghi   rb                    ; decrement usable au count by a
            smi   1                     ;  whole sector also
            phi   rb

            sep   scall                 ; write the sector
            dw    writesec

            ghi   rb                    ; continue as long as there are whole
            lbnz  writfre               ;  sectors of zeroes to write


          ; Now we may have a partial sector with some free AUs at the start
          ; and then switching to unavailable AUs at the end.

partial:    glo   rb                    ; if there are no usable aus left
            lbz   padrest               ;  then just straight to fast fill

lastfre:    ldi   0                     ; mark available aus with 0000
            str   rf
            inc   rf
            str   rf
            inc   rf

            inc   ra                    ; increment current at

            dec   rb                    ; continue until all available aus
            glo   rb                    ;  have been marked
            lbnz  lastfre

unavail:    ldi   0ffh                  ; mark the rest of the aus in the
            str   rf                    ;  sector as unavailable with ffff
            inc   rf
            str   rf
            inc   rf

            inc   ra                    ; continue until end of sector
            glo   ra
            lbnz  unavail

            sep   scall                 ; write the sector
            dw    writesec


            ; Now there may be some full sectors of unusable AU's that we
            ; can fast fill with FF's up through the end of the allocation
            ; unit just before the root directory file.

padrest:    glo   r7                    ; see if we are at the start of an
            ani   7                     ;  au, if so, we are done
            lbz   finished

            ldi   0                     ; otherwise fill sector
            plo   r9

fillpad:    ldi   0ffh                  ; mark all aus as unavailable
            str   rf
            inc   rf
            str   rf
            inc   rf

            dec   r9                    ; continue until sector filled
            glo   r9
            lbnz  fillpad

            sep   scall                 ; write the sector
            dw    writesec

            lbr   padrest               ; continue until end of au

 
finished:   sep   scall                 ; declare success
            dw    o_inmsg
            db    "Done.",13,10,0

            sep   sret                  ; return


          ; Subroutine used to write out LAT sectors. This takes care of
          ; resetting the buffer pointer, incrementing the sector pointer,
          ; and also looks for the block containing the entry of the special
          ; AU FEFE which needs to be marked unavailable. 

writesec:   ghi   ra                    ; does buffer contain fexx entries?
            smi   0ffh
            lbnz  notfefe

            ldi   (sector+2*0feh).1     ; get pointer to fefe entry
            phi   rf
            ldi   (sector+2*0feh).0
            plo   rf

            ldi   0ffh                  ; mark as unavailable
            str   rf
            inc   rf
            str   rf

notfefe:    ldi   sector.1              ; get pointer to start of buffer
            phi   rf
            ldi   sector.0
            plo   rf

            sep   scall                 ; write out buffer
            dw    d_idewrite

            inc   r7                    ; increment sector pointer

            ldi   sector.1              ; reset pointer to start of buffer
            phi   rf
            ldi   sector.0
            plo   rf

            sep   sret                  ; return



xorsize:    glo   rc
            str   r2
            glo   r8
            xor
            plo   r8

            ghi   rb
            str   r2
            ghi   r7
            xor
            phi   r7

            glo   rb
            str   r2
            glo   r7
            xor
            plo   r7

            sep   sret


buffer:    ds      10                   ; work space for number conversions
sector:    ds      512                  ; buffer to hold each disk sector

end:       ; That's all, folks!

