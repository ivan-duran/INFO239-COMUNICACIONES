#include <VirtualWire.h>
#include <CRC.h>
#include <LiquidCrystal_I2C.h>
LiquidCrystal_I2C lcd(0x27, 16, 2);

// RECEPTOR
unsigned long inicio = 0;
unsigned long fin = 0;

// CRC8
CRC8 crc;

// Pines LED RGB
const int pinRojo = 9;
const int pinVerde = 11;
const int pinAzul = 10;

// Clave cesar
const uint8_t CLAVE_CESAR = 78;

// Configuración de recepción
const uint8_t ID_ESPERADO = 0x02;
#define TOTAL_PAQUETES 43

// Matriz para reconstruir la imagen y control de recepción
uint8_t imagenReconstruida[TOTAL_PAQUETES][3];
bool recibido[TOTAL_PAQUETES] = {false};
int recibidosTotales = 0;
int recibidosEfectivos = 0;

// Matriz de imagen reconstruida
void encenderColor(bool r, bool g, bool b) {
  digitalWrite(pinRojo, r ? HIGH : LOW);
  digitalWrite(pinVerde, g ? HIGH : LOW);
  digitalWrite(pinAzul, b ? HIGH : LOW);
}

void imprimirImagen() {
  int bitIndex = 0;

  for (int fila = 0; fila < 32; fila++) {
    for (int col = 0; col < 32; col++) {
      int filaOriginal = bitIndex / 24;
      int byte = (bitIndex % 24) / 8;
      int bit = 7 - (bitIndex % 8);

      bool pixel = (imagenReconstruida[filaOriginal][byte] >> bit) & 0x01;
      Serial.print(pixel ? "█" : " ");
      bitIndex++;
    }
    Serial.println();
  }
}

uint8_t descifrarCesar(uint8_t byte, uint8_t clave) {
  return byte - clave;
}

void setup(){
    Serial.begin(9600);
    Serial.println(F("Configurando Recepcion"));

    pinMode(pinRojo, OUTPUT);
    pinMode(pinVerde, OUTPUT);
    pinMode(pinAzul, OUTPUT);

    lcd.init();
    lcd.backlight();
    lcd.setCursor(0, 0);
    lcd.print(F("Esperando datos"));

    vw_set_ptt_inverted(true);
    vw_setup(2000);
    vw_set_rx_pin(2);
    vw_rx_start();

    inicio = millis();
}

void loop(){
    uint8_t buf[VW_MAX_MESSAGE_LEN];
    uint8_t buflen = VW_MAX_MESSAGE_LEN;

    if (vw_get_message(buf, &buflen)) {
      if (buflen != 7){
        Serial.println(F("Otro paquete nada que ver"));
        encenderColor(true, false, false); // rojo
        delay(100);
        encenderColor(false, false, false); // apagar
        recibidosTotales++;
        return;
      }

    byte secuencia = buf[0];

    // Verifica que el ID receptor coincida
    if (buf[2] != ID_ESPERADO) {
      Serial.println(F("ID receptor no coincide"));
      encenderColor(true, false, false); // rojo
      delay(100);
      encenderColor(false, false, false); // apagar
      recibidosTotales++;
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
      recibidosTotales++;
      return;
    }

    if (secuencia >= TOTAL_PAQUETES) {
      Serial.println("Cabecera fuera de rango");
      encenderColor(true, false, false); //rojo
      delay(100);
      encenderColor(false, false, false);
      recibidosTotales++;
      return;
    }

    if (!recibido[secuencia]) {
      imagenReconstruida[secuencia][0] = descifrarCesar(buf[3], CLAVE_CESAR);
      imagenReconstruida[secuencia][1] = descifrarCesar(buf[4], CLAVE_CESAR);
      imagenReconstruida[secuencia][2] = descifrarCesar(buf[5], CLAVE_CESAR);
      recibido[secuencia] = true;
      recibidosTotales++;
      recibidosEfectivos++;

      // Indicador visual
      int faltan = TOTAL_PAQUETES - recibidosEfectivos;
      Serial.print("Paquete recibido! Faltan: ");
      Serial.println(faltan);

      // Actualiza el LCD
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Faltan:");
      lcd.setCursor(8, 0);
      lcd.print(faltan);
      
      encenderColor(false, true, false); // verde
      delay(100);
      encenderColor(false, false, false); // apagar
    }

    // Cuando se hayan recibido todos
    if (recibidosEfectivos == TOTAL_PAQUETES) {
        // Metricas de rendimiento
        fin = millis();
        float transcurrido = (fin - inicio)/1000;
        float velocidad_paquetes = recibidosTotales / transcurrido;
        float eficiencia = (float)recibidosEfectivos / recibidosTotales;
        float bitrate_efectivo = (recibidosEfectivos * 3 * 8) / transcurrido;  // bits/s

        // Mostrar imagen
        imprimirImagen();

        // Mostrar informacion en el lcd
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("Velocidad Canal:");
        lcd.setCursor(0, 1);
        lcd.print(velocidad_paquetes);
        lcd.setCursor(5, 1);
        lcd.print("P/s");

        // Mostrar informacion en el rgb
        encenderColor(false, true, false);
        // Mostrar metricas en pantalla
        Serial.println(F("Imagen completa."));
        Serial.print(F("Velocidad en Paquetes por segundo: "));
        Serial.print(velocidad_paquetes); Serial.println(F(" P/s"));
        Serial.print(F("Tasa de paquete recibidos correctamente: "));
        Serial.print(eficiencia*100); Serial.println("%");
        Serial.print(F("BitRate efectivo")); Serial.print(bitrate_efectivo);
        Serial.println(F("Bits/s"));
        while (1);  // Detener loop
    }
  }
}
