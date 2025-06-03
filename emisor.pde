#include <VirtualWire.h>

// EMISOR
const byte CABECERA = 0xAA;
const byte ID_EMISOR = 0x01;
const byte ID_RECEPTOR = 0x02;
uint8_t imagenFinal[32][32];  // Matriz binaria: 1 = negro, 0 = blanco


#define TOTAL_PAQUETES 43
const uint8_t imagenYinYang[TOTAL_PAQUETES][3] = {
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
    {0b00000000, 0b00000000, 0b00000000},
    {0b00000000, 0b00111111, 0b11110000},
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
    {0b00001100, 0b00000000, 0b00000000},
    {0b00000000, 0b00000000, 0b00111111},
    {0b00000000, 0b11110000, 0b00111100},
    {0b00001111, 0b11000000, 0b00000000},
    {0b11110000, 0b00001111, 0b11000000},
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



void convertirA32x32() {
  int bitIndex = 0;

  for (int fila = 0; fila < TOTAL_PAQUETES && bitIndex < 1024; fila++) {
    for (int byte = 0; byte < 3; byte++) {
      for (int bit = 7; bit >= 0; bit--) {
        if (bitIndex >= 1024) break;

        bool pixel = (imagenYinYang[fila][byte] >> bit) & 0x01;

        int fila32 = bitIndex / 32;
        int col32 = bitIndex % 32;

        imagenFinal[fila32][col32] = pixel;
        bitIndex++;
      }
    }
  }
}

void imprimirImagen() {
  for (int i = 0; i < 32; i++) {
    for (int j = 0; j < 32; j++) {
      Serial.print(imagenFinal[i][j] ? "█" : " ");
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
  // Mostrar la imagen reconstruida en consola (opcional)
  convertirA32x32();
  imprimirImagen();
  while(true){

  
    for (int i = 0; i < TOTAL_PAQUETES; i++) {
      byte paquete[7];

      paquete[0] = 0x00 + i;  // aumentamos en 1 la cabecera cada vez
      paquete[1] = ID_EMISOR;
      paquete[2] = ID_RECEPTOR;
      paquete[3] = imagenYinYang[i][0];
      paquete[4] = imagenYinYang[i][1];
      paquete[5] = imagenYinYang[i][2];

      // Checksum
      byte checksum = 0;
      for (int j = 0; j < 6; j++) {
        checksum += paquete[j];
      }
      paquete[6] = checksum % 256;

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