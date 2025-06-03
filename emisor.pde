#include <VirtualWire.h>

#define TOTAL_PAQUETES 43

// Pines LED RGB
const int pinRojo = 9;
const int pinVerde = 10;
const int pinAzul = 11;

// Configuración de recepción
const byte ID_ESPERADO = 0x02;
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

void imprimirImagen() {
  Serial.println("\nImagen reconstruida:\n");
  int bitsMostrados = 0;

  for (int i = 0; i < TOTAL_PAQUETES && bitsMostrados < 1024; i++) {
    for (int j = 0; j < 3; j++) {
      for (int bit = 7; bit >= 0; bit--) {
        if (bitsMostrados >= 1024) break;

        bool pixel = imagenFinal[i][j];
        Serial.print(pixel ? "█" : " ");

        bitsMostrados++;
        if (bitsMostrados % 32 == 0) Serial.println();  // Nueva línea cada 32 bits
      }
    }
  }
}

void setup(){
    Serial.begin(9600);
    Serial.println("Configurando Recepcion");

    pinMode(pinRojo, OUTPUT);
    pinMode(pinVerde, OUTPUT);
    pinMode(pinAzul, OUTPUT);

    vw_set_ptt_inverted(true);
    vw_setup(2000);
    vw_set_rx_pin(2);
    vw_rx_start();

    int recibidos_totales = 0;
}

void encenderColor(bool r, bool g, bool b) {
  digitalWrite(pinRojo, r ? HIGH : LOW);
  digitalWrite(pinVerde, g ? HIGH : LOW);
  digitalWrite(pinAzul, b ? HIGH : LOW);
}

void loop(){
    uint8_t buf[VW_MAX_MESSAGE_LEN];
    uint8_t buflen = VW_MAX_MESSAGE_LEN;

    if (vw_get_message(buf, &buflen)){
        if (buflen != 7){
          Serial.println("Otro paquete nada que ver");
          encenderColor(true, false, false); // rojo
          delay(100);
          encenderColor(false, false, false); // apagar
          return;
        }
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
    byte checksum = 0;
    for (int i = 0; i < 6; i++) {
        checksum += buf[i];
    }

    if (buf[6] != (checksum % 256)) {
        Serial.println("Checksum inválido");
        encenderColor(false, false, true); // azul
        delay(100);
        encenderColor(false, false, false); // apagar
        return;
    }

    if (secuencia >= TOTAL_PAQUETES) {
      Serial.println("Cabecera fuera de rango");
      encenderColor(false, false, true); delay(100);
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
        encenderColor(false, true, false); // verde
        delay(100);
        encenderColor(false, false, false); // apagar
    }

    // Cuando se hayan recibido todos
    if (recibidosTotales == TOTAL_PAQUETES) {
        convertirA32x32();
        imprimirImagen();
        Serial.println("Imagen completa.");
        while (1);  // Detener loop
    }

}