//
//    FILE: MCP23S17_digitalRead.ino
//  AUTHOR: Rob Tillaart
//    DATE: 2021-12-30
// PUPROSE: test MCP23017 library


#include "MCP23S17.h"
#include "MCP23S08.h"
#include "SPI.h"

// Hardware SPI
MCP23S17 MCP16(10); //select, address
MCP23S08 MCP8(9); //select, address

// Software SPI
//MCP23S17 MCP16(10, 11, 12, 13, 0); //select, dataIn, dataOut, clock, address
//MCP23S08 MCP8(9, 11, 12, 13, 0); //select, dataIn, dataOut, clock, address
int rv = 0;


void setup()
{
  Serial.begin(115200);
  Serial.println();
  Serial.print("MCP23S17_test version: ");
  Serial.println(MCP23S17_LIB_VERSION);
  Serial.print("MCP23S08_test version: ");
  Serial.println(MCP23S08_LIB_VERSION);

  // Reset
  pinMode(8, OUTPUT);
  digitalWrite(8, HIGH);
  
  delay(100);

  // TEST CS
  pinMode(10, OUTPUT);
  digitalWrite(10, LOW);

  delay(5000);

  SPI.begin();
  
  rv = MCP16.begin();
  Serial.print(rv);
  rv = MCP16.pinMode(0, 0xFFFF);   // CHECK
  Serial.print(rv);
  rv = MCP16.pinMode(1, 0xFFFF);
  Serial.println(rv);
  MCP16.setSPIspeed(400000);
  Serial.print("HWSPI(16): ");
  Serial.println(MCP16.usesHWSPI());

  rv = MCP8.begin();
  Serial.print(rv);
  rv = MCP8.pinMode(0, 0xFF);   // CHECK
  Serial.print(rv);
  rv = MCP8.pinMode(1, 0xFF);
  Serial.println(rv);
  MCP8.setSPIspeed(400000);
  Serial.print("HWSPI(8): ");
  Serial.println(MCP8.usesHWSPI());

  Serial.println("TEST digitalRead(pin)");
  for (int pin = 0; pin < 16; pin++)
  {
    int val = MCP16.digitalRead(pin);
    Serial.print(val);
    Serial.print(' ');
    val = MCP8.digitalRead(pin);
    Serial.print(val);
    Serial.print(' ');
    delay(100);
  }
  Serial.println();
}


void loop()
{
  delay(1000);
  Serial.println("TEST digitalRead(pin)");
  for (int pin = 0; pin < 16; pin++)
  {
    int val = MCP16.digitalRead(pin);
    Serial.print(val);
    Serial.print(' ');
    val = MCP8.digitalRead(pin);
    Serial.print(val);
    Serial.print(' ');
    delay(100);
  }
  Serial.println();

}


// -- END OF FILE --
