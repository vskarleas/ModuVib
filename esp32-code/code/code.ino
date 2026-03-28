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
#define TEST_MODE false

// ══════════════════════════════════════════════════════════════
// CONFIGURATION 
// ══════════════════════════════════════════════════════════════


// motorState est une image qui montre l'etat On ou OFF d'un moteur specific. Par 
// exemple, si motorState = 0x0005 (binaire 0000 0000 0000 0101), cela signifie que 
// les moteurs M1 et M3 sont allumés (bits 0 et 2 à 1), tandis que les autres moteurs 
//sont éteints (bits à 0). Lorsque motorState est envoyé aux shift registers, chaque 
// bit contrôle l'état d'un moteur spécifique : bit 0 pour M1, bit 1 pour M2, ..., bit 14 
//pour M15.

// Dans ce cadre la nous avons les methodes suivantes pour controler les moteurs :
// 1. setMotor(motorId, intensity) : pour controler un moteur individuel
// 2. setAllMotors(intensity) : pour controler tous les moteurs en même temps
// 3. updatePattern() : pour animer des patterns predefinis qui activent/désactivent les moteurs de manière dynamique (ex: vague, pluie, impulsion, cercle)
// 4. updateIntensity(intensity) : pour controler l'intensité globale via PWM sur G des I2C
// 5. stopAllMotors() : pour couper tous les moteurs (sécurité) qui fait appel à setAllMotors(0) avec une intensité de 0
// (SOS) 6. updateShiftRegisters() : pour envoyer l'état actuel de motorState aux shift registers (TPIC6C595) afin de refléter les changements d'état des moteurs sur le hardware



//   ESP32S3 GPIO -> TPIC6C595
//   SR_DATA  -> SER IN (pin 2 TPIC6C595)  chip 1
//   SR_CLOCK -> SRCK (pin 15 TPIC6C595) des deux chips
//   SR_LATCH -> RCK (pin 10 TPIC6C595) des deux chips
//   SR_OE    -> G (pin 8 TPIC6C595)  des deux chips avec PWM pour intensité
//   CLR (pin 7 TPIC6C595) à VCC sur les deux chips
//   SER OUT (pin 9 TPIC6C595) chip 1 -> SER IN (pin 2 TPIC6C595) chip 2


#define NUM_MOTORS 15

// Position physique des moteurs
// Equatiom : value = (chip_number - 1) * 8 + drain_number
#define M1   0
#define M2   1
#define M3   2
#define M4   3
#define M5   4
#define M6   5
#define M7   6
#define M8   7
#define M9   8
#define M10  9
#define M11  10
#define M12  11
#define M13  12
#define M14  13
#define M15  14

// Mapping logique -> physique : reference les defines ci-dessus dans l'ordre M1..M15
static const uint8_t motorMap[NUM_MOTORS] = {
  M1, M2, M3, M4, M5, M6, M7, M8, M9, M10, M11, M12, M13, M14, M15
};

// Declaration des Pins XIAO ESP32C3
#define SR_DATA   10 // SER IN du premier TPIC6C595
#define SR_CLOCK   9 // SRCK (horloge shift) — commun aux deux chips
#define SR_LATCH   20 // RCK  (horloge latch) — commun aux deux chips
#define SR_OE     8 // G actif bas PWM pour l'intensite !

// Bitmask : bit N = moteur N+1 (bit 0 = M1, bit 14 = M15)
uint16_t motorState = 0x0000;

// Intensité globale courante (0-255) appliquée via PWM sur G
uint8_t currentIntensity = 0;

// Intensité master globale (0-255), appliquée par CMD_MASTER_INTENSITY
uint8_t masterIntensity = 0;
bool masterActive = false;


// ══════════════════════════════════════════════════════════════
// PATTERN
// ══════════════════════════════════════════════════════════════

// Grille dorsale variable : 3, 4, 3, 2, 3 le nb des moteurs par ligne
// Rangée 0 : [1] M1  M2  M3
// Rangée 1 : [4] M4  M5  M6  M7
// Rangée 2 : [8] M8  M9  M10
// Rangée 3 : [11] M11 M12
// Rangée 4 : [13] M13 M14 M15
#define NUM_ROWS 5
static const uint8_t rowStart[] = {1, 4, 8, 11, 13};
static const uint8_t rowLen[]   = {3, 4, 3, 2,  3};


uint8_t activePattern = 0; // par defaut aucun pattern
uint8_t patternIntensity = 0;
unsigned long patternStepTime = 0; // temps pour le pattern

int patternStep = 0; 

// ══════════════════════════════════════════════════════════════
// BLUETOOTH
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
// SHIFT REGISTER
// ══════════════════════════════════════════════════════════════

/// Pousse les 16 bits de motorState vers les registres
void updateShiftRegisters() {
  if (TEST_MODE) {
    Serial.printf("  [SR] motorState=0x%04X  intensity=%d\n", motorState, currentIntensity);
    return;
  }

  // Source 16 bits division en deux 8 bits : https://forum.arduino.cc/t/changing-a-16bit-binary-number-into-two-8-bit-byte/44940/2
  // Source ShiftOut : https://docs.arduino.cc/language-reference/en/functions/advanced-io/shiftOut/
  digitalWrite(SR_LATCH, LOW); // pour que les I2Cs recois de donnent en sync avec l'horloge

  // division du motorState xxxx xxxx xxxx xxxx en deux octets
  shiftOut(SR_DATA, SR_CLOCK, MSBFIRST, (motorState >> 8));  // chip 2 recoit avec un shift de 8 bits (car chip 2 bits 8-15)
  shiftOut(SR_DATA, SR_CLOCK, MSBFIRST, (motorState & 0xFF)); // chip 1 bits 0-7

  digitalWrite(SR_LATCH, HIGH); // plus besoin d'ecouter
}

/// intensite via PWM sur le pin G (actif bas)
void updateIntensity(uint8_t intensity) {
  currentIntensity = intensity;
  if (TEST_MODE) return;

  analogWrite(SR_OE, 255 - intensity); // G est actif bas : 0 = sorties actives à 100%, 255 = sorties désactivées
  
}

// ══════════════════════════════════════════════════════════════
// CONTRÔLE MOTEURS
// ══════════════════════════════════════════════════════════════

/// Active/désactive un moteur individuel (motorId 1-15)

// intensity > 0 -> bit ON + intensité globale mise à jour
// intensity = 0 -> bit OFF
void setMotor(uint8_t motorId, uint8_t intensity) {
  if (motorId < 1 || motorId > NUM_MOTORS) return;
  if (intensity > 0) 
  {
    motorState |= (1 << motorMap[motorId - 1]);   // allumer ce moteur via le mapping logique->physique

    // Petit example. Soit motorId = 5:
    //
    // 1 << (5-1) = 1 << 4 = 0000 0000 0001 0000 (ce qui permet de creer la masque necessaire)
    //
    // motorState before:     0000 0000 0010 0100  (motors 3 and 6 already actif)
    // mask:                  0000 0000 0001 0000  (motor 5)
    // ───────────────────────────────────────────
    // motorState after |=:   0000 0000 0011 0100  (motors 3, 5, and 6 actif grace a l'operation OR)

    updateIntensity(intensity);  // mettre à jour l'intensité globale
  } 
  else 
  {
    motorState &= ~(1 << motorMap[motorId - 1]);  // éteindre ce moteur via le mapping logique->physique
  }
  updateShiftRegisters();
}

/// Active/désactive tous les moteurs
void setAllMotors(uint8_t intensity) {
  if (intensity > 0) 
  {
    motorState = 0x7FFF;  // car 7fff en binaire est 0111 1111 1111 1111, ce qui correspond à tous les moteurs ON (bits 0-14 à 1)
    updateIntensity(intensity);
  } 
  else // rester desactivé sinon
  {
    motorState = 0x0000; // tous les moteurs en tant que desactive
    updateIntensity(0);
  }
  updateShiftRegisters();

  Serial.printf("[All motors] motorState=0x%04X\n", motorState);
}

/// Coupe tous les moteurs
void stopAllMotors() {
  setAllMotors(0);
  masterActive = false;
  activePattern = 0;
}

// ══════════════════════════════════════════════════════════════
// PATTERNS (à verifier)
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
    motorState |= (1 << motorMap[motorId - 1]);
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
    motorState |= (1 << motorMap[motorId - 1]);
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
  motorState |= (1 << motorMap[perimeterIds[idx] - 1]);
  motorState |= (1 << motorMap[perimeterIds[prevIdx] - 1]);

  updateIntensity(patternIntensity);
  updateShiftRegisters();
  patternStep++;
}

/// Chosoir le bon pattern parmi les fonctions predefinies
void updatePattern() 
{
  if (activePattern == 0) return;

  switch (activePattern) {
    case PATTERN_WAVE:   patternWaveTick();   break;
    case PATTERN_RAIN:   patternRainTick();   break;
    case PATTERN_PULSE:  patternPulseTick();  break;
    case PATTERN_CIRCLE: patternCircleTick(); break;
  }
}

// ══════════════════════════════════════════════════════════════
//  CALLBACKS
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

    // Au debut tout éteint
    digitalWrite(SR_LATCH, LOW);
    digitalWrite(SR_CLOCK, LOW);
    analogWrite(SR_OE, 255);  // G haut = sorties désactivées !! (car G est actif bas)
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