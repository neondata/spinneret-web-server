{{
───────────────────────────────────────────────── 
Copyright (c) 2011 AgaveRobotics LLC.
See end of file for terms of use.

File....... StringMethods.spin 
Author..... Mike Gebhard
Company.... Agave Robotics LLC
Email...... mailto:mike.gebhard@agaverobotics.com
Started.... 11/01/2010
Updated.... 07/16/2011        
───────────────────────────────────────────────── 
}}

{
About:
  StringMethods contains 3 methods; ToInteger, ToString, and, MatchPattern   

Usage:
  StringMethods is designed to be started in a top level object
  but can be invoked from any child object through pointers to the DAT block.

  StringMethods returns the address of @command on Start. 

Change Log:
 
}

DAT
  cog         long      $00
  command     long      $00
  output      long      $FFFF_FFFF
  source      long      $00
  destination long      $00
  offset      long      $00
  binary      long      $00
  buffer      byte      $0[7]

'1 = ParseInteger(string)
'2 = IntegerToAsCII(integer)
'3 = Match Pattern
PUB Start '| strt, eol, count
  cog := cognew(@entry, @command) + 1
  return @command


PUB ToInteger(stringToConvert)
'' Converts an ASCII string to an integer
'' stringToConvert = pointer to the source string

  ' Init
  source := stringToConvert
  output := -1
  
  command := $01
  
  ' Wait until the command finishes
  ' and return the result
  repeat until command == $00
  
  return output


PUB ToString(integerToConvert, destinationPointer)
'' Converts an integer to an ASCII string
'' 655,359 is the largest interger to ascii conversion due to PASM division.
'' integerToConvert = pointer to the source integer
'' destinationPointer = pointer to result location

  destination := destinationPointer
  source := integerToConvert
  command := $02
  
  ' Wait until the command finishes
  ' and return a pointer to the result
  repeat until command == $00
  return destination
  

PUB MatchPattern(sourcePointer, patternPointer, offsetValue, caseSensitive)
'' Match a pattern of bytes in memory
'' sourcePointer = Start of memory block to query
'' patternPointer = Pattern to find
'' offsetValue  = offset from the sourcePointer 
'' caseSensitive = true - case sensitive; flase - not case sensitive
''
  source := sourcePointer
  destination := patternPointer
  offset := offsetValue
  binary := caseSensitive

  command := $03
  
  ' Wait until the command finishes
  ' and return a pointer to the result
  repeat until command == $00
  return output


PUB stop
  if Cog
    cogstop(Cog~ -  1)


DAT
                        org     0
entry
 init                   mov     t1, par                 ' points to command
                        mov     cmdptr, t1              ' save pointer to command
                        add     t1, #4
                        mov     rsltptr, t1             ' save result pointer
                        add     t1, #4
                        mov     parmptr, t1             ' save parameter pointer
  
getcmd                  rdlong  cmd, cmdptr     wz      ' Wait until the command is not zero
                        '***debug result *****
                        'rdlong  rslt, rsltptr           ' testing
                        '***debug result ***** 
        if_z            jmp     #getcmd

switch_cmd              cmp     cmd, #1         wz
        if_e            jmp     #intparse
                        cmp     cmd, #2         wz
        if_e            jmp     #toascii
                        cmp     cmd, #3         wz
        if_e            jmp     #match         
                        jmp     #getcmd                 ' default jump

'-------------------------------------------------------------------------
' ASCII to integer
' Max number is 32 bit.
'-------------------------------------------------------------------------
intparse                mov     t1, parmptr
                        'add     t1, #4                  ' next hub long
                        rdlong  srcptr, t1              ' source string pointer

                        add     t1, #4                  ' next hub long 
                        rdlong  dstptr, t1              ' destination string pointer

                        mov     i, #0                   ' init counter
                        mov     t1, #0                  ' init t1


:_main                  movd    :buffer, #workspace     ' initialize destination (buffer) address

:loop                   rdbyte  srcobj, srcptr          ' get the ascii char
                        cmp     srcobj, #0      wz      ' found zero terminator?
        if_e            jmp     #process                ' true = process; false = get next
                        sub     srcobj, #$30            ' ascii char to integer
:buffer                 mov     0-0, srcobj             ' save integer in the cog buffer
                        add     srcptr, #1              ' incr source pointer
                        add     i, #1                   ' incr counter
                        add     :buffer, incr           ' incr buffer pointer
                        jmp     #:loop                  ' loop
               
process                 sub     i, #1
                        movs    :readbuff, #workspace   ' set the source pointer
:loop                   mov     j, i                    ' save counter
:readbuff               mov     x, 0-0                  ' get a byte from the buffer
:mult                   call    #multiply10             ' mutiple by integer position
                        djnz    j, $-1                  ' decr j and; jump to current minus 1
                        add     t1, x                   ' running total
                        add     :readbuff, #1           ' increment buffer pointer
                        djnz    i, #:loop               ' loop until we're at the ones position

                        movs    :last, :readbuff        ' updated source address
                        wrlong  zero, cmdptr            ' clear command (time to clear pipeline)
:last                   mov     x, 0-0                  ' Read last integer
                        add     t1, x                   ' final total
                        
:rtn                    wrlong  t1, rsltptr             ' write result to hub                      
                        jmp     #getcmd                 ' reset                                          

'--- Functions -----
'Mutiply x by 10
'x contains the result
multiply10              mov     y, x                    ' y = x
                        shl     y, #3                   ' y * 8
                        shl     x, #1                   ' x * 8
                        add     x, y                    ' x + y = 10x
multiply10_ret          ret

'-------------------------------------------------------------------------
' Integer to ASCII
' 655,359 is the largest interger to ascii conversion due to the division
' function
'-------------------------------------------------------------------------
toascii                 mov     t1, parmptr
                        'add     t1, #4                  ' next hub long
                        rdlong  srcptr, t1              ' source string pointer
                        mov     i, #0                   ' init counter
                        rdlong  srcobj, srcptr          ' grab the number to convert

                        add     t1, #4                  ' next hub long 
                        rdlong  dstptr, t1              ' destination string pointer

:_main                  movd    :buffer, #workspace     ' initialize destination (buffer) address
                        mov     x, srcobj               ' get source number to convert
                        
:loop                   mov     y, #10                  ' set divisor = 10
                        call    #divide                 ' divide routine
                        mov     t1, x                   ' save remainder[31..16] and quotient[15..0]
                        shr     t1, #16                 ' shift the remainder to [15..0]
                        shl     x, #16                  ' get quotient by shifting out the remainder
                        shr     x, #16                  ' shift back to [15..0]
                     
                        add     t1, #$30                ' convert the remainder to an ascii char
:buffer                 mov     0-0, t1                 ' stick the char in the cog buffer
                        add     :buffer, incr           ' increment the buffer pointer
                        add     i, #1                   ' count the items in the buffer

                        cmp     x, #0           wz      ' are we done?
        if_ne           jmp     #:loop                  ' no = loop; yes = finish conversion
        
                        mov     t1, #workspace          ' set up the cog buffer pointer
                        add     t1, i                   ' go to the end of the buffer
                        sub     t1, #1                  ' note: the chars are in reversed in the buffer

write_to_hub              
                        movs    :readbuff, t1           ' set the source pointer
:loop                   sub     i, #1                   ' decr buffer item counter
:readbuff               mov     t1, 0-0                 ' get a byte from the buffer
                        wrbyte  t1, dstptr              ' write the byte to hub memory
                        add     dstptr, #1              ' increment hub memory pointer
                        sub     :readbuff, #1           ' decrement cog pointer
                        cmp     i, #0           wz      ' are we done?
        if_ne           jmp     #:loop                  ' false = get next; true = finish up
        
:done                   mov     dstobj, #0              ' get terminating zero (0)
                        wrbyte  dstobj, dstptr          ' write 0 to hub memory 

:rtn                    wrlong  i, rsltptr              ' write result to hub
                        wrlong  zero, cmdptr            ' clear command                           
                        jmp     #getcmd                 ' reset                     

'--- Functions -----
' Divide x[31..0] by y[15..0] (y[16] must be 0)
' on exit, quotient is in x[15..0] and remainder is in x[31..16]
' This code is from the Propeller Manual Appendix B
divide                  shl     y,#15                   'get divisor into y[30..15]
                        mov     t,#16                   'ready for 16 quotient bits
:loop                   cmpsub  x,y              wc     'y =< x? Subtract it, quotient bit in c
                        rcl     x,#1                    'rotate c into quotient, shift dividend
                        djnz    t,#:loop                'loop until done
divide_ret              ret                             'quotient in x[15..0],
                                                        'remainder in x[31..16]
                                 
'-------------------------------------------------------------------------
' Match Pattern Method
'-------------------------------------------------------------------------
                        ' Initialize pointers
                        ' Load initial chars to compare
match                   mov     t1, parmptr
                        'add     t1, #4                 ' next hub long
                        rdlong  srcptr, t1              ' source string pointer
                        mov     i, #1                   ' initialize char counter to base 1 (7-22 hub)           
                        rdbyte  srcobj, srcptr          ' grab the first source char

                        mov     maxcnt, maxbuff

                        add     t1, #4                  ' next hub long 
                        rdlong  patptr, t1              ' pattern string pointer
                        mov     t2, patptr              ' save pattern start address (7-22 hub)
                        rdbyte  patchr, patptr          ' grab first pattern char
                        
:get_args               add     t1, #4                  ' next hub long 
                        rdlong  offst, t1               ' get offset argument
                        add     t1, #4                  ' next hub long 
                        rdlong  binry, t1               ' get binary match argument
                        
                        add     srcptr, offst           ' add source string pointer offset
                        sub     maxcnt, offst   wc      ' we only parse 2k of memory
                        mov     j, #1                   ' init pattern string length counter
'
' Compare
'
compare                 cmp     srcobj, patchr  wz      ' does source char == pattern char?
              if_e      jmp     #:next                  ' if yes; jump to next chars
                        cmps    binry,#0        wc      ' is match case true?
              if_c      jmp     #:rst_patptr            ' if match case == true; no match; reset and continue
    
                        mov     t3, patchr              ' |x| = pattern char - source char 
                        sub     t3, srcobj
                        abs     t4, t3
                        cmp     t4, #32         wz      ' |x| == 32? true = match; false = no match
              if_ne     jmp     #:rst_patptr      
                        

:next                   add     patptr, #1              ' + 1 hub byte
                        rdbyte  patchr, patptr  wz      ' read byte; is byte == 0?
              if_z      jmp     #:done                  ' if byte == 0; return -> we're done!
              
                        add     srcptr, #1              ' + 1 hub byte
                        rdbyte  srcobj, srcptr          ' read byte
                        
                        add     i, #1                   ' update # of chars compared
                        add     j, #1                   ' update # of pattern chars 
                        jmp     #compare                ' compare the next set of chars
                        
:rst_patptr             cmps    maxcnt, #0      wc      ' is maxcnt < 0?
              if_c      jmp     #:err_exit              ' true ?  then the offset is probably > 2k
                        cmp     i, maxcnt       wc      ' is i < 2048-offset?
              if_nc     jmp     #:err_exit

                        mov     patptr, t2              ' reset pattern pointer
                        rdbyte  patchr, patptr          ' read first byte
                        
                        cmp     j, #1           wz
              if_ne     jmp     #:no_incr 
                        add     srcptr, #1               
                        rdbyte  srcobj, srcptr
                        add     i, #1
:no_incr                mov     j, #1
              if_c      jmp     #compare                
              
:err_exit               mov     t3, #1                  ' put a -2 in i 
                        neg     i, t3
                        jmp     #:rtn
'                            
' Return
'
:done                   mov     t3, i                   ' get offset to the first char in the source 
                        sub     i, j
                        add     i, offst       
:rtn                    wrlong  i, rsltptr              ' write result to hub
                        wrlong  zero, cmdptr            ' clear command                           
                        jmp     #getcmd                 ' Reset                         
'                        
' Variables
'
maxbuff                 long    $800
incr                    long    1<<9
negone                  long    $FFFF_FFFF
'---------
t1                      long    0
t2                      long    0
t3                      long    0
t4                      long    0
parmptr                 long    0
zero                    long    0
'---------
i                       long    0
j                       long    0
'---------
cmdptr                  long    0
srcptr                  long    0
patptr                  long    0
dstptr                  long    0
'---------  
cmd                     long    0
srcobj                  long    0
patchr                  long    0
dstobj                  long    0
'----------
rslt                    long    0
rsltptr                 long    0
'----------
offst                   long    0
maxcnt                  long    0
binry                   long    0
'----------
x                       long    0
y                       long    0
t                       long    0
'----------
workspace               res     16


                       fit

{{
  For testing
  
  pst.start(115_200)
  waitcnt((clkfreq / 1_000 * 1000) + cnt) 

  pst.dec(ToInteger(eprom.PtrAsciiNum))
  pst.char(13)

  pst.str(string("Here we go",13))
  pst.str(ToString(eprom.PtrNum, @buffer))
  pst.char(13)
  

  pst.dec(MatchPattern(eprom.getIndex, string("HTTP/"), 0, true))
  pst.char(13)
  
 
  repeat count from 0 to 5000
    strt := MatchPattern(eprom.getStyle, string("/"), 0, true)
    eol := MatchPattern(eprom.getStyle, string("/"), 9, true)
    '
    pst.str(string(13,"--------------------------------",13))
    pst.str(string("Count : "))
    pst.dec(count)
    pst.char(13)
    pst.str(string("Start : "))
    pst.dec(strt)
    pst.char(13)
    pst.str(string("Eol   : "))
    pst.dec(eol)
    pst.char(13)
    if((strt == -1) OR (strt > eol))
      pst.str(string(13,"******** Error *************",13))
      return
  
}}
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial ions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}