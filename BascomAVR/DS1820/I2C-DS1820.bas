'*****************************************************************************
' Brewing Chip
' ------------
' - I2C to 1-Wire bridge for DS18B20
' - I2C controlled relais
'
' This code works only for a single DS18B20 connected to the ATTiny45
' You really the need "B" version, so make sure to use the DS18 _B_ 20
'
' Author: Stefan Heesch, HB9TWS
'
'*****************************************************************************
$prog &HFF , &HE2 , &HDF , &HFF                             ' fuse bytes

$regfile = "attiny45.dat"

$crystal = 8000000
$hwstack = 40
$swstack = 16
$framesize = 24


' Pinout:
' ------
'
' Reset      on PORTB.5
'
' SDA        on PORTB.0
' SCL        on PORTB.2
'
' 1Wire      on PORTB.1
'
' Relais     on PORTB.3
'
' Status LED on PORTB.4


Config 1wire = Portb.1

Relais Alias Portb.3
Led Alias Portb.4


' Bascom uses 8 bit i2c address (7 bit shifted to the left with one bit
'
' Example: &H48 is used by Bascom for I2C address &H24
'
Config Usi = Twislave , Address = &H48

Config Relais = Output
Config Led = Output


'*****************************************************************************
' Declaration of variables and procedures
'*****************************************************************************
DIM Scratchpad(9) as Byte
DIM Command as Byte
DIM Ready as Byte
DIM i as Byte



Declare Function GetResolution (info as Byte) as Byte

Declare Sub Startmeasurement
Declare Sub Ismeasurementready
Declare Sub Readtemperature

'*****************************************************************************
' Initialize
'*****************************************************************************

' Switch off relais
Reset Relais


' Turn off LED indicating measurement
Reset Led


' Enable interrups for I2C
Enable Interrupts


'*****************************************************************************
' Main loop - we do nothing here, everything is done in interrupt service
' routines.
'*****************************************************************************
Do
   !  nop
Loop

' --== The END ==--

'*****************************************************************************
'the following labels are called from the library
'*****************************************************************************

' master sent stop or repeated start
Twi_stop_rstart_received:
Return

' master sent our slave address and will now send data
Twi_addressed_goread:
Return

' this label is called when the master sends data and the slave has received
' the byte the variable TWI holds the received value
Twi_gotdata:

   ' Command is expected in the first byte

   Select Case Twi_btw
     Case 1 : Command = Twi
     Case 2 : If Command = 8 Then
                 ' Switch relais
                 '
                 If Twi = 0 Then
                   Reset Relais
                 Else
                   Set Relais
                 End If
              End If
   End Select


   ' Handle commands without parameters immeddiately
   Select Case Command
     Case 1 : Startmeasurement
     Case 2 : Ismeasurementready
     Case 4 : Readtemperature
     Case 8 : ! Nop                                         ' just remember the command
     Case Else Command = 0
   End Select

Return



' master sent our slave address and will now read data
Twi_addressed_gowrite:
Return

' master read data, number of needed byte is in Twi_btr
Twi_master_needs_byte:

   Select Case Twi_btr
      Case 1 : Twi = Ready
      Case 2 : Twi = Scratchpad(1)
      Case 3 : Twi = Scratchpad(2)
      Case 4 : Twi = GetResolution( Scratchpad(5) )
   End Select

Return


'*****************************************************************************
' Functions for starting temperature measurement and reading the temperature
'*****************************************************************************
Sub Startmeasurement

   ' Indicate start of measurement
   Set Led
   Ready = 0

   for i = 1 to 9
     Scratchpad(i) = 0
   next

   ' Trigger measurement on DS18B20
   1wreset
   1wwrite &HCC ' Skip ROM command
   1wwrite &H44 ' Start temperature conversion

End Sub



Sub Ismeasurementready

   1wreset
   1wwrite &HCC                  ' Skip ROM command
   1wwrite &HBE                  ' Command to read scratchpad

   for i=1 to 9
      Scratchpad(i) = 1wread()   ' Read scratchpad from DS18B20 into array variable
   next

   if Scratchpad(9) = Crc8(Scratchpad(1), 8 ) then
      Ready = 1
      Reset Led
   else

      Ready = 0
   end if

End Sub



Sub Readtemperature

   ' If not yet done, get scratchpad from DS18B20 and determine measurement state
   if Ready <> 1 then IsMeasurementready

End Sub


Function GetResolution (info as Byte) as Byte

   DIM tmp as Byte

   Select Case info

      Case &B00011111: tmp = 9
      Case &B00111111: tmp = 10
      Case &B01011111: tmp = 11
      Case &B01111111: tmp = 12

   end select

   GetResolution = tmp

End Function
