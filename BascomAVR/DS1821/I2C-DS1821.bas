'*****************************************************************************
' Brewing Chip
' ------------
' - I2C to 1-Wire bridge for DS1821
' - I2C controlled relais
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
' Example: &H4A is used by Bascom for I2C address &H25
'
Config Usi = Twislave , Address = &H4A

Config Relais = Output
Config Led = Output


'*****************************************************************************
' Declaration of variables and procedures
'*****************************************************************************
Dim Command As Byte
Dim Done As Byte
Dim Count As Byte
Dim Remainder As Byte
Dim Temperature As Byte

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

' master read data, number of needed byt is in Twi_btr
Twi_master_needs_byte:
   Select Case Twi_btr
      Case 1 : Twi = Done
      Case 2 : Twi = Temperature
      Case 3 : Twi = Count
      Case 4 : Twi = Remainder
   End Select
Return


'*****************************************************************************
' Functions for starting temperature measurement and reading the temperature
'*****************************************************************************
Sub Startmeasurement

  ' Indicate start of measurement
  Set Led
  Done = 0

  ' Trigger measurement on DS1821
  1wreset
  1wwrite &HEE

End Sub


Sub Ismeasurementready

  Dim Tmp As Byte

  1wreset
  1wwrite &HAC
  Tmp = 1wread() And &H80

  If Tmp = &H80 Then
    Done = 1
    Reset Led
  Else
    Done = 0
  End If


End Sub



Sub Readtemperature

  If Done = 1 Then

     1wreset
     1wwrite &HAA
     Temperature = 1wread()
     1wreset
     1wwrite &HA0
     Remainder = 1wread()

     1wreset
     1wwrite &H41

     1wreset
     1wwrite &HA0
     Count = 1wread()

  Else

     Temperature = &HFF
     Remainder = &HFF
     Count = &HFF

  End If


End Sub