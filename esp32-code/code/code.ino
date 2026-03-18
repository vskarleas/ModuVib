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
// MODE TEST
// ══════════════════════════════════════════════════════════════
#define TEST_MODE true

// ══════════════════════════════════════════════════════════════
// CONFIGURATION SHIFT REGISTERS — 2× TPIC6C595
// ══════════════════════════════════════════════════════════════
// 2 registres en daisy-chain = 16 sorties (15 utilisées pour moteurs)
// Moteur ID 0x01..0x0F → bit 0..14 dans motorState
//
// Câblage :
//   ESP32 GPIO → TPIC6C595
//   SR_DATA    → SER IN  (pin 3)  du chip 1
//   SR_CLOCK   → SRCK    (pin 13) des deux chips (liés)
//   SR_LATCH   → RCK     (pin 12) des deux chips (liés)
//   SR_OE      → G       (pin 9)  des deux chips (liés) — PWM intensité
//   Tirer SRCLR (pin 8) à VCC sur les deux chips
//
// Daisy-chain : SER OUT (pin 18) chip 1 → SER IN (pin 3) chip 2

#define NUM_MOTORS 15

// Pins pour XIAO ESP32C3
#define SR_DATA   2   // SER IN du premier TPIC6C595
#define SR_CLOCK  3   // SRCK (horloge shift) — commun aux deux chips
#define SR_LATCH  4   // RCK  (horloge latch) — commun aux deux chips
#define SR_OE     5   // G (Output Enable, actif bas) — PWM intensité globale

// Bitmask : bit N = moteur N+1 (bit 0 = M1, bit 14 = M15)
uint16_t motorState = 0x0000;

// Intensité globale courante (0-255) appliquée via PWM sur G
uint8_t currentIntensity = 0;

// Intensité master globale (0-255), appliquée par CMD_MASTER_INTENSITY
uint8_t masterIntensity = 0;
bool masterActive = false;

// Grille dorsale variable : 3, 4, 3, 2, 3 moteurs par rangée
// Rangée 0 : [1] M1  M2  M3
// Rangée 1 : [4] M4  M5  M6  M7
// Rangée 2 : [8] M8  M9  M10
// Rangée 3 : [11] M11 M12
// Rangée 4 : [13] M13 M14 M15
#define NUM_ROWS 5
static const uint8_t rowStart[] = {1, 4, 8, 11, 13};
static const uint8_t rowLen[]   = {3, 4, 3, 2,  3};

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
// SHIFT REGISTER — envoi des 16 bits aux deux TPIC6C595
// ══════════════════════════════════════════════════════════════

/// Pousse les 16 bits de motorState vers les registres
void updateShiftRegisters() {
  if (TEST_MODE) {
    Serial.printf("  [SR] motorState=0x%04X  intensity=%d\n", motorState, currentIntensity);
    return;
  }

  // Le premier octet envoyé traverse chip 1 et finit dans chip 2
  // Le second octet envoyé reste dans chip 1
  digitalWrite(SR_LATCH, LOW);
  shiftOut(SR_DATA, SR_CLOCK, MSBFIRST, (motorState >> 8) & 0xFF);  // chip 2 : bits 8-15
  shiftOut(SR_DATA, SR_CLOCK, MSBFIRST, motorState & 0xFF);          // chip 1 : bits 0-7
  digitalWrite(SR_LATCH, HIGH);
}

/// Met à jour l'intensité globale via PWM sur le pin G (actif bas)
void updateIntensity(uint8_t intensity) {
  currentIntensity = intensity;
  if (TEST_MODE) return;

  // G est actif bas : 0 = sorties actives à 100%, 255 = sorties désactivées
  analogWrite(SR_OE, 255 - intensity);
}

// ══════════════════════════════════════════════════════════════
// CONTRÔLE MOTEURS
// ══════════════════════════════════════════════════════════════

/// Active/désactive un moteur individuel (motorId 1-15)

// intensity > 0 → bit ON + intensité globale mise à jour
// intensity = 0 → bit OFF
void setMotor(uint8_t motorId, uint8_t intensity) {
  if (motorId < 1 || motorId > NUM_MOTORS) return;
  if (intensity > 0) {
    motorState |= (1 << (motorId - 1));   // allumer ce moteur
    updateIntensity(intensity);             // mettre à jour l'intensité globale
  } else {
    motorState &= ~(1 << (motorId - 1));  // éteindre ce moteur
  }
  updateShiftRegisters();
}

/// Active/désactive tous les moteurs
void setAllMotors(uint8_t intensity) {
  if (intensity > 0) {
    motorState = 0x7FFF;  // bits 0-14 à 1 (15 moteurs)
    updateIntensity(intensity);
  } else {
    motorState = 0x0000;
    updateIntensity(0);
  }
  updateShiftRegisters();
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

  // Éteindre tous (garder l'intensité pour la prochaine rangée)
  motorState = 0x0000;

  // Activer la rangée courante (taille variable)
  int row = patternStep % NUM_ROWS;
  for (int col = 0; col < rowLen[row]; col++) {
    uint8_t motorId = rowStart[row] + col;
    motorState |= (1 << (motorId - 1));
  }
  updateIntensity(patternIntensity);
  updateShiftRegisters();
  patternStep++;
}

/// Pluie : active des moteurs aléatoires
void patternRainTick() {
  const unsigned long STEP_MS = 200;
  if (millis() - patternStepTime < STEP_MS) return;
  patternStepTime = millis();

  // Éteindre tous
  motorState = 0x0000;

  // Activer 2-4 moteurs aléatoires
  int count = random(2, 5);
  for (int i = 0; i < count; i++) {
    uint8_t motorId = random(1, NUM_MOTORS + 1);
    motorState |= (1 << (motorId - 1));
  }
  updateIntensity(patternIntensity);
  updateShiftRegisters();
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

// Périmètre adapté à la grille 3,4,3,2,3 :
// M1→M2→M3→M7→M10→M12→M15→M14→M13→M11→M8→M4
void patternCircleTick() {
  const unsigned long STEP_MS = 250;
  if (millis() - patternStepTime < STEP_MS) return;
  patternStepTime = millis();

  static const uint8_t perimeterIds[] = {1, 2, 3, 7, 10, 12, 15, 14, 13, 11, 8, 4};
  static const int perimeterLen = 12;

  motorState = 0x0000;

  // Moteur courant + traînée (moteur précédent)
  int idx = patternStep % perimeterLen;
  int prevIdx = (idx - 1 + perimeterLen) % perimeterLen;
  motorState |= (1 << (perimeterIds[idx] - 1));
  motorState |= (1 << (perimeterIds[prevIdx] - 1));

  updateIntensity(patternIntensity);
  updateShiftRegisters();
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
// SOME CALLBACKS
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

        // stop everything in the begining
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

  // Configurer les pins shift register
  if (!TEST_MODE) {
    pinMode(SR_DATA, OUTPUT);
    pinMode(SR_CLOCK, OUTPUT);
    pinMode(SR_LATCH, OUTPUT);
    pinMode(SR_OE, OUTPUT);

    // État initial : tout éteint
    digitalWrite(SR_LATCH, LOW);
    digitalWrite(SR_CLOCK, LOW);
    analogWrite(SR_OE, 255);  // G haut = sorties désactivées
    motorState = 0x0000;
    updateShiftRegisters();
  }

  Serial.printf("[ModuVib] Mode test : %s\n", TEST_MODE ? "OUI (Serial uniquement)" : "NON (GPIOs actifs)");

  Serial.println("[ModuVib] Demarrage XIAO ESP32C3...");
  Serial.printf("[ModuVib] %d moteurs via 2x TPIC6C595\n", NUM_MOTORS);
  Serial.printf("[ModuVib] Pins: DATA=%d CLOCK=%d LATCH=%d OE=%d\n", SR_DATA, SR_CLOCK, SR_LATCH, SR_OE);

  // Bluetooth service
  BLEDevice::init("ModuVib-4K2A");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Characteristic d'entree : l'app ecrit ici
  pCommandChar = pService->createCharacteristic(
    COMMAND_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );


  // Trigger the commands
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

  Serial.println("[ModuVib] BLE pret - nom: ModuVib-4K2A");
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
