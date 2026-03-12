#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// UUIDs BLE - a faire correspondre avec Flutter
#define SERVICE_UUID      "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define COMMAND_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define STATUS_CHAR_UUID  "beb5483e-36e1-4688-b7f5-ea07361b26a9"

// Protocole 3 octets [CMD, TARGET, VALUE]
#define CMD_MOTOR            0x01
#define CMD_PATTERN          0x02
#define CMD_STOP             0x03
#define CMD_MASTER_INTENSITY 0x04
#define CMD_PING             0x05
#define CMD_BATTERY_REQUEST  0x06

#define PATTERN_WAVE   0x01
#define PATTERN_RAIN   0x02
#define PATTERN_PULSE  0x03
#define PATTERN_CIRCLE 0x04

BLEServer* pServer = nullptr;
BLECharacteristic* pCommandChar = nullptr;
BLECharacteristic* pStatusChar = nullptr;

bool deviceConnected = false;

// Envoie un petit message texte en notification
void sendStatus(const char* msg) {
  if (!deviceConnected || pStatusChar == nullptr) return;
  pStatusChar->setValue((uint8_t*)msg, strlen(msg));
  pStatusChar->notify();
}

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("[BLE] Application connectee");
    sendStatus("CONNECTED");
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("[BLE] Application deconnectee");
    BLEDevice::startAdvertising();
    Serial.println("[BLE] Advertising relance");
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    String value = pChar->getValue();

    Serial.print("[BLE] Taille recue = ");
    Serial.println(value.length());

    if (value.length() != 3) {
      Serial.println("[ERREUR] Format invalide : on attend exactement 3 octets");
      sendStatus("ERR_LEN");
      return;
    }

    uint8_t cmd    = (uint8_t)value[0];
    uint8_t target = (uint8_t)value[1];
    uint8_t data   = (uint8_t)value[2];

    Serial.println("------ COMMANDE RECUE ------");
    Serial.print("CMD    = 0x");
    Serial.println(cmd, HEX);
    Serial.print("TARGET = ");
    Serial.println(target);
    Serial.print("VALUE  = ");
    Serial.println(data);

    switch (cmd) {
      case CMD_MOTOR:
        if (data > 0) {
          Serial.printf("Moteur %d active avec intensite %d\n", target, data);
          char msg[32];
          snprintf(msg, sizeof(msg), "MOTOR_%d_ON", target);
          sendStatus(msg);
        } else {
          Serial.printf("Moteur %d desactive\n", target);
          char msg[32];
          snprintf(msg, sizeof(msg), "MOTOR_%d_OFF", target);
          sendStatus(msg);
        }
        break;

      case CMD_PATTERN:
        switch (target) {
          case PATTERN_WAVE:
            Serial.printf("Pattern VAGUE lance a %d\n", data);
            sendStatus("PATTERN_WAVE");
            break;
          case PATTERN_RAIN:
            Serial.printf("Pattern PLUIE lance a %d\n", data);
            sendStatus("PATTERN_RAIN");
            break;
          case PATTERN_PULSE:
            Serial.printf("Pattern IMPULSION lance a %d\n", data);
            sendStatus("PATTERN_PULSE");
            break;
          case PATTERN_CIRCLE:
            Serial.printf("Pattern CERCLE lance a %d\n", data);
            sendStatus("PATTERN_CIRCLE");
            break;
          default:
            Serial.printf("Pattern inconnu : %d\n", target);
            sendStatus("PATTERN_UNKNOWN");
            break;
        }
        break;

      case CMD_STOP:
        Serial.println("ARRET D'URGENCE recu");
        sendStatus("STOP");
        break;

      case CMD_MASTER_INTENSITY:
        Serial.printf("Intensite globale fixee a %d\n", data);
        sendStatus("MASTER_SET");
        break;

      case CMD_PING:
        Serial.println("PING recu");
        sendStatus("PONG");
        break;

      case CMD_BATTERY_REQUEST:
        Serial.println("Demande batterie recue");
        sendStatus("BAT_84");
        break;

      default:
        Serial.printf("Commande inconnue : 0x%02X\n", cmd);
        sendStatus("UNKNOWN_CMD");
        break;
    }

    Serial.println("----------------------------");
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("[ModuVib] Demarrage XIAO ESP32C3...");
  BLEDevice::init("ModuVib-XIAO");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Characteristic d'entree : l'app ecrit ici
  pCommandChar = pService->createCharacteristic(
    COMMAND_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  pCommandChar->setCallbacks(new CommandCallbacks());

  // Characteristic de retour : la carte notifie ici
  pStatusChar = pService->createCharacteristic(
    STATUS_CHAR_UUID,
    BLECharacteristic::PROPERTY_NOTIFY | BLECharacteristic::PROPERTY_READ
  );
  pStatusChar->addDescriptor(new BLE2902());
  pStatusChar->setValue("READY");

  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.println("[ModuVib] BLE pret - nom: ModuVib-XIAO");
  Serial.println("[ModuVib] En attente de l'application...");
}

void loop() {
  delay(10);
}