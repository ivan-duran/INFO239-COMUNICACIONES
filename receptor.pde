#include <VirtualWire.h>
#include <CRC.h>
#include <LiquidCrystal_I2C.h>
LiquidCrystal_I2C lcd(0x27, 16, 2);

// RECEPTOR

#define TOTAL_PAQUETES 43

// CRC8
CRC8 crc;

// Pines LED RGB
const int pinRojo = 9;
const int pinVerde = 11;
const int pinAzul = 10;

// Configuración de recepción
const uint8_t ID_ESPERADO = 0x02;
#define TOTAL_PAQUETES 43

// Matriz para reconstruir la imagen y control de recepción
uint8_t imagenReconstruida[TOTAL_PAQUETES][3];
bool recibido[TOTAL_PAQUETES] = {false};
int recibidosTotales = 0;

// Matriz de imagen reconstruida
bool imagenFinal[32][32];  // Matriz binaria: 1 = negro, 0 = blanco

void convertirA32x32() {
  int bitIndex = 0;  // Contador global de bits

  for (int fila = 0; fila < TOTAL_PAQUETES && bitIndex < 1024; fila++) {
    for (int byte = 0; byte < 3; byte++) {
      for (int bit = 7; bit >= 0; bit--) {
        if (bitIndex >= 1024) break;  // Solo llenar 1024 bits

        // Extrae el bit actual (1 o 0)
        bool pixel = (imagenReconstruida[fila][byte] >> bit) & 0x01;

        // Convierte el índice lineal a coordenadas 2D
        int fila32 = bitIndex / 32;
        int col32 = bitIndex % 32;

        imagenFinal[fila32][col32] = pixel;  // Guarda como 0 o 1
        bitIndex++;
      }
    }
  }
}

void encenderColor(bool r, bool g, bool b) {
  digitalWrite(pinRojo, r ? HIGH : LOW);
  digitalWrite(pinVerde, g ? HIGH : LOW);
  digitalWrite(pinAzul, b ? HIGH : LOW);
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
    Serial.begin(9600);
    Serial.println("Configurando Recepcion");

    pinMode(pinRojo, OUTPUT);
    pinMode(pinVerde, OUTPUT);
    pinMode(pinAzul, OUTPUT);

    lcd.init();
    lcd.backlight();
    lcd.setCursor(0, 0);
    lcd.print("Esperando datos");

    vw_set_ptt_inverted(true);
    vw_setup(2000);
    vw_set_rx_pin(2);
    vw_rx_start();

    int recibidos_totales = 0;
}

void loop(){
    uint8_t buf[VW_MAX_MESSAGE_LEN];
    uint8_t buflen = VW_MAX_MESSAGE_LEN;

    if (vw_get_message(buf, &buflen)) {
        if (buflen != 7){
            Serial.println("Otro paquete nada que ver");
            encenderColor(true, false, false); // rojo
            delay(100);
            encenderColor(false, false, false); // apagar
            return;
        }

        byte secuencia = buf[0];

        // Verifica que el ID receptor coincida
        if (buf[2] != ID_ESPERADO) {
            Serial.println("ID receptor no coincide");
            encenderColor(true, false, false); // rojo
            delay(100);
            encenderColor(false, false, false); // apagar
            return;
        }

        // Verifica checksum
        crc.restart();
        for (int i = 0; i < 6; i++) {
            crc.add(buf[i]);
        }
        uint8_t result = crc.getCRC();

        if (buf[6] != result) {
            Serial.println("Checksum inválido");
            encenderColor(true, false, false); // rojo
            delay(100);
            encenderColor(false, false, false); // apagar
            return;
        }

        if (secuencia >= TOTAL_PAQUETES) {
            Serial.println("Cabecera fuera de rango");
            encenderColor(true, false, false); //rojo
            delay(100);
            encenderColor(false, false, false);
            return;
        }

        if (!recibido[secuencia]) {
            imagenReconstruida[secuencia][0] = buf[3];
            imagenReconstruida[secuencia][1] = buf[4];
            imagenReconstruida[secuencia][2] = buf[5];
            recibido[secuencia] = true;
            recibidosTotales++;

            // Indicador visual
            int faltan = TOTAL_PAQUETES - recibidosTotales;
            Serial.print("Paquete recibido! Faltan: ");
            Serial.println(faltan);

            // Actualiza el LCD
            lcd.clear();
            lcd.setCursor(0, 0);
            lcd.print("Faltan:");
            lcd.setCursor(8, 0);
            lcd.print(faltan);
            
            // Serial.print("Paquete ");
            // Serial.print(secuencia);
            // Serial.println(" recibido!");
            // Serial.print("Faltan: ");
            // Serial.println(TOTAL_PAQUETES - recibidosTotales);
            encenderColor(false, true, false); // verde
            delay(100);
            encenderColor(false, false, false); // apagar
        }

        // Cuando se hayan recibido todos
        if (recibidosTotales == TOTAL_PAQUETES) {
            convertirA32x32();
            imprimirImagen();
            encenderColor(false, true, false);
            Serial.println("Imagen completa.");
            while (1);  // Detener loop
        }
    }
}
