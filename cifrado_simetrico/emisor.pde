#include <VirtualWire.h>
#include <CRC.h>

// EMISOR
const byte CABECERA = 0xAA;
const byte ID_EMISOR = 0x01;
const byte ID_RECEPTOR = 0x02;
const uint8_t CLAVE_CESAR = 78;  // Debe ser igual al del emisor


// CRC8
CRC8 crc;

#define TOTAL_PAQUETES 43
const uint8_t imagenYinYang[43][3] = {
  {0b00000000, 0b00000000, 0b00000000},
  {0b00000000, 0b00000000, 0b00000000},
  {0b00000000, 0b00000000, 0b00000000},
  {0b00000000, 0b00000000, 0b00000000},
  {0b00000000, 0b00111111, 0b11111100},
  {0b00000000, 0b00000000, 0b00111111},
  {0b11111100, 0b00000000, 0b00000011},
  {0b11111111, 0b11111111, 0b11000000},
  {0b00001111, 0b11111111, 0b11111111},
  {0b11110000, 0b00001111, 0b11111111},
  {0b11111111, 0b11110000, 0b00111111},
  {0b11110000, 0b11111111, 0b00001100},
  {0b00111111, 0b11110000, 0b11111111},
  {0b00001100, 0b00111111, 0b11110000},
  {0b11111111, 0b00001100, 0b11111111},
  {0b11111111, 0b11111111, 0b00000011},
  {0b11111111, 0b11111111, 0b11111111},
  {0b00000011, 0b11111111, 0b11111111},
  {0b11111100, 0b00000011, 0b11111111},
  {0b11111111, 0b11110000, 0b00000011},
  {0b11111111, 0b11111111, 0b11110000},
  {0b00000011, 0b11111111, 0b11111111},
  {0b11000000, 0b00000011, 0b11111111},
  {0b11111111, 0b11000000, 0b00000011},
  {0b11111111, 0b11000000, 0b00000000},
  {0b00000011, 0b11111111, 0b00000000},
  {0b00000000, 0b00000011, 0b11111111},
  {0b00000000, 0b00000000, 0b00000011},
  {0b00111111, 0b00000000, 0b11110000},
  {0b00000100, 0b00111111, 0b00000000},
  {0b11110000, 0b00001100, 0b00111111},
  {0b00000000, 0b11110000, 0b00011100},
  {0b00001111, 0b11000000, 0b00000000},
  {0b00110000, 0b00001111, 0b11000000},
  {0b00000000, 0b11110000, 0b00000011},
  {0b11111100, 0b00000011, 0b11000000},
  {0b00000000, 0b00111111, 0b11111100},
  {0b00000000, 0b00000000, 0b00111111},
  {0b11111100, 0b00000000, 0b00000000},
  {0b00000000, 0b00000000, 0b00000000},
  {0b00000000, 0b00000000, 0b00000000},
  {0b00000000, 0b00000000, 0b00000000},
  {0b00000000, 0b00000000, 0b00000000},
};

// Cifrado César (adelanta cada byte 'clave' posiciones)
uint8_t cifrarCesar(uint8_t byte, uint8_t clave) {
  return byte + clave; //le sumamos la clave al byte, uint8 manejar desbordamiento automaticamente
}

void imprimirImagen() {
  int bitIndex = 0;

  for (int fila = 0; fila < 32; fila++) {
    for (int col = 0; col < 32; col++) {
      int filaOriginal = bitIndex / 24;
      int byte = (bitIndex % 24) / 8;
      int bit = 7 - (bitIndex % 8);

      bool pixel = (imagenYinYang[filaOriginal][byte] >> bit) & 0x01;
      Serial.print(pixel ? "█" : " ");
      bitIndex++;
    }
    Serial.println();
  }
}

void setup(){
    vw_set_ptt_inverted(true);
    vw_setup(2000);
    vw_set_tx_pin(2);    
    Serial.begin(9600);
    Serial.println("configurando envio");
}
void loop() {
  imprimirImagen();
  
  while (true) {
    for (int i = 0; i < TOTAL_PAQUETES; i++) {
      byte paquete[7];

      paquete[0] = 0x00 + i;
      paquete[1] = ID_EMISOR;
      paquete[2] = ID_RECEPTOR;
      paquete[3] = cifrarCesar(imagenYinYang[i][0], CLAVE_CESAR);
      paquete[4] = cifrarCesar(imagenYinYang[i][1], CLAVE_CESAR);
      paquete[5] = cifrarCesar(imagenYinYang[i][2], CLAVE_CESAR);

      crc.restart();
      for (int j = 0; j < 6; j++) {
        crc.add(paquete[j]);
      }
      paquete[6] = crc.getCRC();

      vw_send(paquete, sizeof(paquete));
      vw_wait_tx();

      Serial.print("Paquete ");
      Serial.print(i);
      Serial.println(" enviado");

      delay(100);
    }

    Serial.println("Transmisión finalizada.");
  }
}
