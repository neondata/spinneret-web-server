{{
───────────────────────────────────────────────── 
Copyright (c) 2011 AgaveRobotics LLC.
See end of file for terms of use.

File....... Response.spin 
Author..... Mike Gebhard
Company.... Agave Robotics LLC
Email...... mailto:mike.gebhard@agaverobotics.com
Started.... 04/01/2010
Updated....         
───────────────────────────────────────────────── 
}}

{
About:
   

Usage:
  Instantiate with Constructor(stringMethods, txbuff). The stringMethods argument is a pointer
  to StringMethods which is running in a COG.  The pointer providers access to the
  execute StringMethods' functions.

  txbuff is a poniter to the Tx Buffer


Change Log:
-----------

 
}
OBJ
  rtc           : "S35390A_RTCEngine.spin"
  
CON
  MATCH_PATTERN                 = $03
  TO_STRING                     = $02
  TO_INTEGER                    = $01
  
  '#1, Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
  '#1, January, February, March, April, May, June, July, August, September, October, November, December
  
DAT
  strParams     long    $0
  txdata        long    $0
  conLen        long    $FFFF_FFFF
  getTime       byte    $1
  hashTable     long    $0[30]
  headerMap     long    $0[30]
  extensions    byte    "htm",0,   "xml",0,  "xsl",0,   "shp",0,   "txt",0,  {
  }                     "pdf",0,   "zip",0,  "jpg",0,   "png",0,   "gif",0,  {
  }                     "css",0,   "js", 0,  "ico",0,   "wmv",0,   "wav",0,  {
  }                     "oct",10
  hearerline    byte    "text/html",0,                "text/xml",0,               "text/xml",0,           "text/html",0,       "text/plain; charset=utf-8",0,{
  }                     "application/pdf",0,          "application/zip",0,        "image/jpeg",0,         "image/png",0,       "image/gif",0,                {
  }                     "text/css",0,                 "application/javascript",0, "image/x-icon",0,        "video/x-ms-wmv",0,  "audio/x-wav",0,             {
  }                     "application/octet-stream",0
  header1       byte    "HTTP/1.1 ",0
  server        byte    "Server: Spinneret/2.1", 13, 10, 0
  cache         byte    "Cache-Control: public", 13, 10, 0
  contenttype   byte    "Content-Type: ",0
  contentlen    byte    "Content-Length: 5",0
  expires       byte    "Expires: Wed, 01 Feb 2000 01:00:00 GMT", 13, 10, 0
  newline       byte    13, 10, 0
  ok            byte    "200 OK" ,13, 10, 0
  notfound      byte    "404 Not Found", 13, 10, 0
  genError      byte    "<html><head><title>General Error</title></head><body><h1 style='color:red;'>General Error</h1><p>File not found?</p></body></html>",0
  tempNum       byte    "0000",0



PUB Constructor(stringMethods, txbuff)
  strParams := stringMethods
  txdata := txbuff
  InitializeHashIndex
  rtc.RTCEngineStart(29, 28, -1)
  

PUB WriteExpireHeader(value)
  getTime := value

PUB SetContentLength(value)
  conLen := value    


PRI FillExpireHeader(cachePage) | ptr, offset, temp
 'ToString(integerToConvert, destinationPointer)
 'Expires: Wed, 01 Feb 2000 01:00:00 GMT
  ptr := @expires + 9 
  rtc.readTime

  offset := -1
  if(cachePage)
    offset := 1  
  
  temp := rtc.getDayString
  bytemove(ptr, temp, strsize(temp))
  ptr += strsize(temp) + 2

  FillTimeHelper(rtc.clockDate, ptr)
  ptr += 3

  temp := rtc.getMonthString
  bytemove(ptr, temp, strsize(temp))
  ptr += strsize(temp) + 1

  FillTimeHelper(rtc.clockYear + offset, ptr)
  ptr += 5

  FillTimeHelper(rtc.clockHour , ptr)
  ptr += 3

  FillTimeHelper(rtc.clockMinute , ptr)
  ptr += 3

  FillTimeHelper(rtc.clockSecond, ptr) 
 
  return @expires


PRI FillTimeHelper(number, ptr) | offset
  offset := 0
  if(number < 10)
    offset := 1
     
  ToString(@number, @tempNum)
  bytemove(ptr+offset, @tempNum, strsize(@tempNum))
    
PUB BuildHeader(extension, statusCode, cachePage) | ptr, idx

  if(getTime)
    FillExpireHeader(cachePage)
  
  ptr := txdata
  'Header Line 1
  bytemove(ptr, @header1, strsize(@header1))
  ptr += strsize(@header1)
   
  'Status code
  if(statusCode == 404)
    bytemove(ptr, @notfound, strsize(@notfound))
    ptr += strsize(@notfound)
  else
    bytemove(ptr, @ok, strsize(@ok))
    ptr += strsize(@ok)

  'Content-Type:   
  bytemove(ptr, @contenttype, strsize(@contenttype))
  ptr += strsize(@contenttype)
  idx :=  GetContentType(extension)
  bytemove(ptr, idx, strsize(idx))
  ptr += strsize(idx)

  'Newline
  bytemove(ptr, @newline, strsize(@newline))
  ptr += strsize(@newline)

  'Server:
  bytemove(ptr, @server, strsize(@server))
  ptr += strsize(@server)

  'Cache
  bytemove(ptr, @cache, strsize(@cache))
  ptr += strsize(@cache)


  'Content-Length:
  if(conLen > -1)
    bytemove(ptr, @contentlen, strsize(@contentlen))
    ptr += strsize(@contentlen)
    ptr += strsize(ToString(@conLen, ptr))
    
    bytemove(ptr, @newline, strsize(@newline))
    ptr += strsize(@newline)
    
  'Expires:
  bytemove(ptr, @expires, strsize(@expires))
  ptr += strsize(@expires)

  'Newline - Newline
  bytemove(ptr, @newline, strsize(@newline))
  ptr += strsize(@newline)

  if(statusCode <> 200)
    bytemove(ptr, @genError, strsize(@genError))
    ptr += strsize(@genError)  
  
  return ptr - txdata
  

PUB GetContentType(ptr) | i, hashcode
  hashcode :=  CreateExtensionHash(ptr)
  
  repeat i from 0 to 30
    if HashTable[i] == hashcode
      return  HeaderMap[i]
  
  return 0
  

PUB CreateExtensionHash(ptr) | char, t1, i
  t1 := i := 0
  repeat until byte[ptr] == 0
    char := byte[ptr++] 
    t1 |= char << (8 * i++)

  return t1
    
  
PUB InitializeHashIndex  | exPtr, headPtr, idx, char, t1, i 
  
  exPtr := @extensions
  headPtr := @hearerline 
  
  idx := 0

  'Create file extension hash
  repeat until byte[exPtr] == 10 or idx > 29
    i := 0
    HashTable[idx] := 0 
    repeat until byte[exPtr] == 0
      char := byte[exPtr++] 
      HashTable[idx] |= char << (8 * i++)
    idx++
    exPtr++

  
  'Map the content-type string to the hash table by index
  i := 0
  HeaderMap[i++] := @hearerline
  repeat idx-1
    headPtr += strsize(headPtr) + 1
    HeaderMap[i++] := headPtr


PRI ToString(integerToConvert, destinationPointer)
  long[strParams][0] := $00
  long[strParams][1] := $FFFF_FFFF
  long[strParams][2] := integerToConvert
  long[strParams][3] := destinationPointer
  long[strParams][4] := $00
  long[strParams][5] := $00

  long[strParams][0] := TO_STRING

  repeat until long[strParams][0] == $00
  return destinationPointer


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