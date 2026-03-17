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

// ══════════════════════════════════════════════════════════════
// MODE TEST : mettre à true pour uniquement afficher dans Serial
// sans piloter les GPIOs (aucun moteur branché)
// ══════════════════════════════════════════════════════════════
#define TEST_MODE true

// ══════════════════════════════════════════════════════════════
// CONFIGURATION DES PINS MOTEURS (XIAO ESP32C3)
// ══════════════════════════════════════════════════════════════
// Grille dorsale 5 rangées × 3 colonnes = 15 moteurs
// Moteur ID 0x01..0x0F → index 0..14 dans le tableau
// Adapter les pins selon votre câblage réel.

#define NUM_MOTORS 15

// Pins GPIO pour chaque moteur (index 0 = moteur 0x01, etc.)
// Remplacer par vos pins réels
const uint8_t MOTOR_PINS[NUM_MOTORS] = {
  2,   // M1  - Rangée 1
  3,   // M2
  4,   // M3
  5,   // M4  - Rangée 2
  6,   // M5
  7,   // M6
  8,   // M7  - Rangée 3
  9,   // M8
  10,  // M9
  20,  // M10 - Rangée 4
  21,  // M11
  0,   // M12 (attention : GPIO0 peut être boot sur certaines cartes)
  1,   // M13 - Rangée 5
  18,  // M14
  19,  // M15
};

// État courant de chaque moteur (intensité 0-255)
uint8_t motorIntensity[NUM_MOTORS] = {0};

// Intensité master globale (0-255), appliquée par CMD_MASTER_INTENSITY
uint8_t masterIntensity = 0;
bool masterActive = false;

// ══════════════════════════════════════════════════════════════
// PATTERN ENGINE
// ══════════════════════════════════════════════════════════════

uint8_t activePattern = 0;        // 0 = aucun pattern
uint8_t patternIntensity = 0;     // intensité du pattern en cours
unsigned long patternStepTime = 0;
int patternStep = 0;

// ══════════════════════════════════════════════════════════════
// BLE
// ══════════════════════════════════════════════════════════════

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

// ══════════════════════════════════════════════════════════════
// CONTRÔLE MOTEURS
// ══════════════════════════════════════════════════════════════

/// Active un moteur individuel (motorId 1-15, intensity 0-255)
void setMotor(uint8_t motorId, uint8_t intensity) {
  if (motorId < 1 || motorId > NUM_MOTORS) return;
  uint8_t idx = motorId - 1;
  motorIntensity[idx] = intensity;
  if (!TEST_MODE) {
    analogWrite(MOTOR_PINS[idx], intensity);
  }
}

/// Active tous les moteurs à la même intensité
void setAllMotors(uint8_t intensity) {
  for (uint8_t i = 0; i < NUM_MOTORS; i++) {
    motorIntensity[i] = intensity;
    if (!TEST_MODE) {
      analogWrite(MOTOR_PINS[i], intensity);
    }
  }
}

/// Coupe tous les moteurs
void stopAllMotors() {
  setAllMotors(0);
  masterActive = false;
  activePattern = 0;
}

// ══════════════════════════════════════════════════════════════
// PATTERNS — logique exécutée dans loop()
// ══════════════════════════════════════════════════════════════

/// Vague : active les rangées de haut en bas, une par une
void patternWaveTick() {
  const unsigned long STEP_MS = 300;
  if (millis() - patternStepTime < STEP_MS) return;
  patternStepTime = millis();

  // Éteindre tous les moteurs
  setAllMotors(0);

  // Activer la rangée courante (3 moteurs par rangée)
  int row = patternStep % 5;
  for (int col = 0; col < 3; col++) {
    uint8_t motorId = row * 3 + col + 1;
    setMotor(motorId, patternIntensity);
  }
  patternStep++;
}

/// Pluie : active des moteurs aléatoires avec intensité variable
void patternRainTick() {
  const unsigned long STEP_MS = 200;
  if (millis() - patternStepTime < STEP_MS) return;
  patternStepTime = millis();

  // Éteindre tous
  setAllMotors(0);

  // Activer 2-4 moteurs aléatoires
  int count = random(2, 5);
  for (int i = 0; i < count; i++) {
    uint8_t motorId = random(1, NUM_MOTORS + 1);
    uint8_t intensity = random(patternIntensity / 2, patternIntensity + 1);
    setMotor(motorId, intensity);
  }
}

/// Impulsion : tous les moteurs ON/OFF en alternance
void patternPulseTick() {
  const unsigned long STEP_MS = 500;
  if (millis() - patternStepTime < STEP_MS) return;
  patternStepTime = millis();

  if (patternStep % 2 == 0) {
    setAllMotors(patternIntensity);
  } else {
    setAllMotors(0);
  }
  patternStep++;
}

/// Cercle : active les moteurs en rotation (périmètre de la grille)
void patternCircleTick() {
  const unsigned long STEP_MS = 250;
  if (millis() - patternStepTime < STEP_MS) return;
  patternStepTime = millis();

  // Séquence périmètre : M1,M2,M3,M6,M9,M12,M15,M14,M13,M10,M7,M4
  static const uint8_t perimeterIds[] = {1,2,3,6,9,12,15,14,13,10,7,4};
  static const int perimeterLen = 12;

  setAllMotors(0);

  int idx = patternStep % perimeterLen;
  setMotor(perimeterIds[idx], patternIntensity);
  // Ajouter une traînée (moteur précédent à demi-intensité)
  int prevIdx = (idx - 1 + perimeterLen) % perimeterLen;
  setMotor(perimeterIds[prevIdx], patternIntensity / 3);

  patternStep++;
}

/// Appelée dans loop() pour animer le pattern actif
void updatePattern() {
  if (activePattern == 0) return;

  switch (activePattern) {
    case PATTERN_WAVE:   patternWaveTick();   break;
    case PATTERN_RAIN:   patternRainTick();   break;
    case PATTERN_PULSE:  patternPulseTick();  break;
    case PATTERN_CIRCLE: patternCircleTick(); break;
  }
}

// ══════════════════════════════════════════════════════════════
// BLE CALLBACKS
// ══════════════════════════════════════════════════════════════

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("[BLE] Application connectee");
    sendStatus("CONNECTED");
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("[BLE] Application deconnectee");
    // Sécurité : couper les moteurs à la déconnexion
    stopAllMotors();
    BLEDevice::startAdvertising();
    Serial.println("[BLE] Advertising relance");
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pChar) override {
    String value = pChar->getValue();

    if (value.length() != 3) {
      Serial.println("[ERREUR] Format invalide : on attend exactement 3 octets");
      sendStatus("ERR_LEN");
      return;
    }

    uint8_t cmd    = (uint8_t)value[0];
    uint8_t target = (uint8_t)value[1];
    uint8_t data   = (uint8_t)value[2];

    Serial.println("------ COMMANDE RECUE ------");
    Serial.printf("CMD=0x%02X  TARGET=0x%02X  VALUE=0x%02X\n", cmd, target, data);

    switch (cmd) {

      // ── Moteur individuel ────────────────────────────────
      case CMD_MOTOR:
        // Arrêter tout pattern en cours (le contrôle manuel prend la main)
        activePattern = 0;
        masterActive = false;

        if (data > 0) {
          Serial.printf(">> Moteur %d ON (intensite %d)\n", target, data);
          setMotor(target, data);
          char msg[32];
          snprintf(msg, sizeof(msg), "MOTOR_%d_ON_%d", target, data);
          sendStatus(msg);
        } else {
          Serial.printf(">> Moteur %d OFF\n", target);
          setMotor(target, 0);
          char msg[32];
          snprintf(msg, sizeof(msg), "MOTOR_%d_OFF", target);
          sendStatus(msg);
        }
        break;

      // ── Pattern ──────────────────────────────────────────
      case CMD_PATTERN:
        // D'abord tout couper
        setAllMotors(0);

        activePattern = target;
        patternIntensity = data;
        patternStep = 0;
        patternStepTime = millis();
        masterActive = false;

        {
          const char* patternName = "INCONNU";
          switch (target) {
            case PATTERN_WAVE:   patternName = "VAGUE";     break;
            case PATTERN_RAIN:   patternName = "PLUIE";     break;
            case PATTERN_PULSE:  patternName = "IMPULSION"; break;
            case PATTERN_CIRCLE: patternName = "CERCLE";    break;
          }
          Serial.printf(">> Pattern %s lance (intensite %d)\n", patternName, data);
          char msg[32];
          snprintf(msg, sizeof(msg), "PATTERN_%s", patternName);
          sendStatus(msg);
        }
        break;

      // ── Arrêt d'urgence ──────────────────────────────────
      case CMD_STOP:
        Serial.println(">> ARRET D'URGENCE");
        stopAllMotors();
        sendStatus("STOP_OK");
        break;

      // ── Intensité master (tous les moteurs) ──────────────
      case CMD_MASTER_INTENSITY:
        activePattern = 0;  // couper les patterns

        masterIntensity = data;
        if (data > 0) {
          masterActive = true;
          setAllMotors(data);
          Serial.printf(">> MASTER ON : tous les moteurs a %d\n", data);
          char msg[32];
          snprintf(msg, sizeof(msg), "MASTER_ON_%d", data);
          sendStatus(msg);
        } else {
          masterActive = false;
          setAllMotors(0);
          Serial.println(">> MASTER OFF : tous les moteurs coupes");
          sendStatus("MASTER_OFF");
        }
        break;

      // ── Ping ─────────────────────────────────────────────
      case CMD_PING:
        Serial.println(">> PING recu");
        sendStatus("PONG");
        break;

      // ── Demande batterie ─────────────────────────────────
      case CMD_BATTERY_REQUEST: {
        Serial.println(">> Demande batterie");
        // TODO: Lire la vraie tension batterie via ADC
        // Pour l'instant, valeur fixe
        uint8_t batteryLevel = 84;
        char msg[16];
        snprintf(msg, sizeof(msg), "BAT_%d", batteryLevel);
        sendStatus(msg);
        break;
      }

      default:
        Serial.printf(">> Commande inconnue : 0x%02X\n", cmd);
        sendStatus("UNKNOWN_CMD");
        break;
    }

    Serial.println("----------------------------");
  }
};

// ══════════════════════════════════════════════════════════════
// SETUP
// ══════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(115200);
  delay(1000);

  // Configurer les pins moteurs en sortie
  if (!TEST_MODE) {
    for (int i = 0; i < NUM_MOTORS; i++) {
      pinMode(MOTOR_PINS[i], OUTPUT);
      analogWrite(MOTOR_PINS[i], 0);
    }
  }

  Serial.printf("[ModuVib] Mode test : %s\n", TEST_MODE ? "OUI (Serial uniquement)" : "NON (GPIOs actifs)");

  Serial.println("[ModuVib] Demarrage XIAO ESP32C3...");
  Serial.printf("[ModuVib] %d moteurs configures\n", NUM_MOTORS);
  BLEDevice::init("ModuVib-4K2A");

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

// ══════════════════════════════════════════════════════════════
// LOOP
// ══════════════════════════════════════════════════════════════

void loop() {
  // Animer les patterns si un est actif
  updatePattern();
  delay(10);
}
