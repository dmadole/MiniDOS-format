
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

            db    9+80h                 ; month
            db    20                    ; day
            dw    2023                  ; year
            dw    2                     ; build

            db    'See github.com/dmadole/Elfos-format for more info',0

          ; Main program


main:       glo   r6                    ; we could use one extra register
            stxd
            ghi   r6
            stxd

            ldi   0                     ; clear manual size
            phi   r6
            plo   r6

            ghi   ra                    ; move input pointer to rf
            phi   rf
            glo   ra
            plo   rf

skipsp1:    lda   rf                    ; skip any leading spaces
            lbz   dousage
            sdi   ' '
            lbdf  skipsp1

moreopt:    sdi   ' '-'-'               ; is there an option
            lbnz  notopts

            lda   rf                    ; if a option for au size
            smi   'a'
            lbnz   notaopt

skipsp2:    lda   rf                    ; skip any intervening spaces
            lbz   dousage
            sdi   ' '
            lbdf  skipsp2

            dec   rf                    ; back up to argument

            sep   scall                 ; get numeric argument
            dw    f_atoi
            lbdf  dousage

            ghi   rd                    ; save size in au
            phi   r6
            glo   rd
            plo   r6

            lbr   optdone

notaopt:    smi   'm'-'a'               ; if m option for megabyte size
            lbnz  dousage

skipsp3:    lda   rf                    ; skip any intervening spaces
            lbz   dousage
            sdi   ' '
            lbdf  skipsp3

            dec   rf                    ; back up to argument

            sep   scall                 ; get numeric argument
            dw    f_atoi
            lbdf  dousage

            glo   rd                    ; multiply by 256 for au size
            phi   r6
            ldi   0
            plo   r6

            ghi   rd                    ; error if more than 256
            sdi   1
            lbnf  dousage
            lbnz  optdone

            dec   r6                    ; if 256 then make au 65535

optdone:    lda   rf                    ; needs to be a space
            sdi   ' '
            lbnf  dousage

skipsp4:    lda   rf                    ; skip any intervening spaces
            lbz   dousage
            sdi   ' '
            lbdf  skipsp4

            lbr   moreopt               ; see if there are more options

notopts:    sdi   '/'-'-'               ; if not a slash, then error
            lbnz  dousage

            lda   rf                    ; if not a slash, then error
            smi   '/'
            lbnz  dousage

            sep   scall                 ; get drive number
            dw    f_atoi
            lbdf  dousage

            glo   rd                    ; fail if too large
            smi   32
            ghi   rd
            smbi  0
            lbdf  dousage

            glo   rd                    ; make into drive specifier
            ori   0e0h
            phi   r8

skipsp5:    lda   rf                    ; skip any trailing spaces
            lbz   getsize
            sdi   ' '
            lbdf  skipsp5

dousage:    sep   scall                 ; if not end of line
            dw    o_inmsg
            db    'USAGE: format [-a ausize] [-m mbsize] //drive',13,10,0

            lbr   return                ; return


          ; Get the size of the target disk so we know how big of a file-
          ; system to make. Since the standard BIOS API doesn't include a
          ; way to get this, we simply search to find the last readable
          ; sector on the disk with a successive approximate algorithm.

getsize:    ldi   0                     ; clear sector registers
            plo   r8
            phi   r7
            plo   r7

            plo   rb                    ; half the maximum as first step
            phi   rb
            ldi   4
            plo   rc

trysize:    sep   scall                 ; xor the location with the step
            dw    xorsize

            ldi   sector.1              ; sector buffer to read into
            phi   rf
            ldi   sector.0
            plo   rf

            sep   scall                 ; read the sector
            dw    d_ideread

            lbnf  yessize               ; check if successful

            sep   scall                 ; if not, remove the trial step
            dw    xorsize

yessize:    glo   rc                    ; halve the step size each time
            shr
            plo   rc
            ghi   rb
            shrc
            phi   rb
            glo   rb
            shrc
            plo   rb

            lbnf  trysize               ; if any steps left, loop back


          ; If the result is zero, then the disk doesn't exist.

            glo   r7
            lbnz  notzero
            ghi   r7
            lbnz  notzero
            glo   r8
            lbnz  notzero

            sep   scall                 ; display too small error
            dw    o_inmsg
            db    'ERROR: Specified disk does not exist.',13,10,0

            lbr   return                ; return


          ; We now have the address of the last readable sector on the disk,
          ; but what we need is the size of the disk, so add one to it.

notzero:    inc   r7                    ; turn last sector to total count

            glo   r7                    ; if zero then there is overflow
            lbnz  notover
            ghi   r7
            lbnz  notover

            inc   r8                    ; add overflow into r7

          ; The maximum size of a filesystem is 65535 AUs, so if this disk
          ; is 65536 then reduce it. And either way, make the filesystem size
          ; a multiple of 8 so it's an even number of AUs.

notover:    glo   r8                    ; check if the maximum size
            smi   8
            lbnz  notmaxi

            dec   r7                    ; if so, reduce slightly
            dec   r8

notmaxi:    glo   r7                    ; make integral number of au
            ani   255-7
            plo   r7


          ; Turn the sector size of the filesystem into an AU size by
          ; dividing by eight by right-shifting three times.

            glo   r8                    ; move count to ra:r9 to keep,
            plo   ra                    ;  to rc:rb for au calculation
            plo   rc
            ghi   r7
            phi   r9
            phi   rb
            glo   r7
            plo   r9

            ori   4                     ; to mark end of three shifts
            plo   rb

divby8:     glo   rc                    ; sector count into au count
            shr
            plo   rc
            ghi   rb
            shrc
            phi   rb
            glo   rb
            shrc
            plo   rb

            lbnf  divby8                ; shift until one comes out


          ; Now that we have the disk size, display it to the user.

            sep   scall                 ; display megabytes size
            dw    o_inmsg
            db    "Disk is ",0

            ghi   rb                    ; get allocation units
            phi   rd
            glo   rb
            plo   rd

            sep   scall                 ; display disk size
            dw    dissize


          ; If a size was requested, display that too, and check that it's
          ; not larger than the size of the disk.

            ghi   r6                    ; if r6 not zero then manual size
            lbnz  chksize
            glo   r6
            lbz   minsize

chksize:    sep   scall                 ; display megabytes size
            dw    o_inmsg
            db    "Filesystem is ",0

            ghi   r6                    ; get allocation units
            phi   rd
            glo   r6
            plo   rd

            sep   scall                 ; display filesystem size
            dw    dissize

            glo   rb                    ; compare request to size
            str   r2
            glo   r6
            sd
            ghi   rb
            str   r2
            ghi   r6
            sdb

            lbdf  setsize               ; request ok if less or equal

            sep   scall                 ; display too small error
            dw    o_inmsg
            db    'ERROR: requested size larger than disk.',13,10,0

            lbr   return                ; return




setsize:    ghi   r6                    ; copy manual size into au
            phi   r9
            phi   rb
            glo   r6
            plo   r9
            plo   rb

            ldi   32                    ; flag bit for three shift
            plo   ra

mulby8:     glo   r9                    ; au count into sector count
            shl
            plo   r9
            ghi   r9
            shlc
            phi   r9
            glo   ra
            shlc
            plo   ra

            lbnf  mulby8                ; shift until one comes out


          ; Check that the disk is big enough. The absolute minimum size
          ; would be four AUs, which is two for the reserved area, one for
          ; LAT table, and one for the master directory. Note that it will
          ; not be possible to create even a single file on this though!

minsize:    glo   rb                    ; needs to be at least four aus
            smi   5
            ghi   rb
            smbi  0
            lbdf  warning

            sep   scall                 ; display too small error
            dw    o_inmsg
            db    'ERROR: Filesystem must be at least 5 AU.',13,10,0

            lbr   return                ; return


          ; Now that we know what we are going to do and have displayed
          ; it, also display a warning message confirming the drive.

warning:    sep   scall                 ; warning message
            dw    o_inmsg
            db    "PROCEEDING WILL OVERWRITE THE CONTENTS OF DISK!",0

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

            lbr   return                ; return


          ; Check the input string to make sure it's exactly "YES", if
          ; it's not then send the confirmation prompt again.

proceed:    ldi   buffer.1              ; pointer to buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            ldi   yesresp.1
            phi   rd
            ldi   yesresp.0
            plo   rd

            sep   scall
            dw    f_strcmp
            lbnz  yousure

            sep   scall                 ; echo return from input
            dw    o_inmsg
            db    13,10,0


          ; Now we are ready to start actually making the filesystem.

            sep   scall
            dw    o_inmsg
            db    "Fast formatting... ",0


          ; Get number of sectors that will be used for the LAT table to 
          ; hold the AU usage information. There are 256 entries per sector.

            ldi   0                     ; divide number of aus by 256
            phi   rc
            ghi   rb
            plo   rc

            glo   rb                    ; if there is a fraction, round up
            lbz   placemd
            inc   rc


          ; Calculate the sector that the master directory should be put
          ; into. This will be the first allocation until following the
          ; LAT table.

placemd:    glo   rc                    ; sector just past last au sector
            adi   17
            plo   rd
            ghi   rc
            adci  0
            phi   rd

            glo   rd                    ; does it fall on an au boundary
            ani   7
            lbz   zerboot

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

zerboot:    ldi   sector.1              ; point to start of sector
            phi   rf
            ldi   sector.0
            plo   rf

zerloop:    ldi   0                     ; fill with zeroes
            str   rf
            inc   rf

            glo   rf                    ; until one page is filled
            xri   sector.0
            lbnz  zerloop


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

padmast:    ldi   0                     ; fill empty space with zeroes
            str   rf
            inc   rf

            glo   rf                    ; go until 12ch where the master
            xri   (sector+12ch).0       ;  directory entry starts
            lbnz  padmast


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
          ; the system cleanly if the media is booted without ever having
          ; a kernel written, and is also neater than having random garbage
          ; after the end of the kernel (which gets loaded to memory also).

            ldi   sector.1              ; get pointer to buffer
            phi   rf
            ldi   sector.0
            plo   rf

            ldi   0                     ; fill sector buffer
            plo   r9

zerfill:    ldi   0                     ; zero, loop unrolled twice
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
          ; also need to mark the root directory file as the last AU in
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

            inc   ra                    ; increment current au

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

return:     irx                         ; restore return address
            ldxa
            phi   r6
            ldx
            plo   r6

            sep   sret                  ; return to monitor


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


          ; XOR the 24 bits in R8.0:R7 with those in RC.0:RB. This is used
          ; by the binary search algorithm to find the size of the disk.

xorsize:    glo   rc                    ; xor the msb
            str   r2
            glo   r8
            xor
            plo   r8

            ghi   rb                    ; and the middle
            str   r2
            ghi   r7
            xor
            phi   r7

            glo   rb                    ; and the lsb
            str   r2
            glo   r7
            xor
            plo   r7

            sep   sret                  ; and return


          ; Display a size in RD as megabytes and allocation units. Used
          ; to output both the disk and filesystem size, depending.

dissize:    glo   rd                    ; save the starting value
            stxd
            ghi   rd
            stxd

            glo   rd                    ; divide by 256 but round up
            adi   128                   ;  for size in mb
            ghi   rd
            adci  0
            plo   rd
            ldi   0
            shlc
            phi   rd

            ldi   buffer.1              ; pointer to buffer for sector
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; convert to string
            dw    f_uintout

            ldi   0                     ; zero terminate
            str   rf

            ldi   buffer.1              ; pointer to buffer for sector
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; number part
            dw    o_msg

            sep   scall                 ; units part
            dw    o_inmsg
            db    " megabytes, ",0

            irx                         ; recover size in au
            ldxa
            phi   rd
            ldx
            plo   rd

            ldi   buffer.1              ; pointer to buffer for converston
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; convert to string
            dw    f_uintout

            ldi   0                     ; zero terminate
            str   rf

            ldi   buffer.1              ; pointer to buffer for output
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; display number part
            dw    o_msg

            sep   scall                 ; display units
            dw    o_inmsg
            db    " allocation units.",13,10,0

            sep   sret


yesresp:    db    'YES',0               ; prompt comparison string

buffer:     ds    6                     ; work space for number conversions
sector:     ds    512                   ; buffer to hold each disk sector

end:       ; That's all, folks!

