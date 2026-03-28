# Versions

* V1 : First itteration of the UI of the App. Now we will work on the wireless module connection with the ESP32 micro-controller.
* V2.1 : This versions implements databse support with FaceID and TouchID option. The required bluetooth services were created and connected with the ui. We also removed any hard coded options.
* V3 : We can choose manualyif we want a specific motor or not from the map page.
* V4.1 : Fixed some communication issues with the ESP32 BLE board
* V4.2 : Fixed ios security issues with continues bluetooth
* V5.0 : Fixed android communication issue with the ESP32 BLE board and some presentatio features on the settings page
* V5.1 : Updated the code.ino for it to work using the OPEN DRAINS where the motors are connected an dudpated the design of the manual page.
* V6.2 :
  * Silhouette dorsale élargie en bas pour que M13 et M15 restent à l'intérieur du contour
  * Correction du conflit de gestes : le glisser-déposer sur la grille ne déclenche plus le changement de page
* V6.1 :
  * Ajout d'un mapping logique→physique des moteurs dans le firmware ESP32 (`#define M1..M15`) permettant de reconfigurer le câblage sans modifier le reste du code
  * Contrôle de l'intensité via PWM sur la broche G (OE) du TPIC6C595 (`analogWrite`)
  * Refonte de l'écran de contrôle manuel : suppression des modes Précision/Dessin Libre, sélection et désélection des moteurs par simple toucher ou glisser-déposer

## TO-DO

* [X] I have to recompile everything in order to refresh the build/ folder. This will allow also to undersatnd the architecture of the app
* [X] Understand the code and its structure
* [X] Update the manual screen
* [X] Write the code for the ESP32 in order to communicate under the name ModuVib
* [X] Fix login issue with phone number. It says on android Error d'autentication (unknown). On Ios it just tcuks
* [X] Integrate the codes found on the notes section that Dounia sent me in the different actiosn of the app.
* [X] Fix rester password functionality
* [X] Integrate pin page with faceid for returing session on thre app
* [X] Add logic on actions triger if the device is not connected -> prevent any message to be sent in that scenario
* [X] Possibility for user to update his account
* [X] Added connect button with logic on the dashboard screen
* [X] We need when we login on existed account to activate biometrique security if it is not set up and set up the pin instead.
* [X] Please note that if the user already signed in once the app, do not send the user to the pin screen authentication or unlocking via faceid. This needs to be fixed !
* [X] Changed the hard coded voltage to something related with the ESP32 chip on the dashboadr page
* [X] Prepare V5.0 that allows to see in details the statistcs and also teh patterns should be capable to send stop command **even if the phone is locked**. And fix the firmware and the a propos at teh settings when the pop up opens from down. I believe the issue is that we have set the background colour to be white. Eventually we want the same idea as the battery pop up but larger on the screen.

## BLE Protocol — Commandes 3 octets `[CMD, TARGET, VALUE]`

Chaque commande envoyée par l'app Flutter au ESP32 est composée de 3 octets.

### Commands

| CMD      | Nom                   | Cible                        | Valeur                               | Exemple                                      | Signification                  |
| -------- | --------------------- | ---------------------------- | ------------------------------------ | -------------------------------------------- | ------------------------------ |
| `0x01` | Moteur individuel     | ID moteur (0x01–0x0F)       | Intensité (0x00=OFF, 0x01–0xFF=ON) | `01 05 FF` → Moteur 5 ON pleine puissance | Contrôle Manuel               |
| `0x02` | Pattern               | ID pattern (voir ci-dessous) | Intensité (0x00–0xFF)              | `02 01 BF` → Vague à 75%                 | Programmes                     |
| `0x03` | Arrêt d'urgence      | `0x00`                     | `0x00`                             | `03 00 00`                                 | Bouton STOP (top bar)          |
| `0x04` | Master (tous moteurs) | `0x00`                     | Intensité (0x00=OFF, 0x01–0xFF=ON) | `04 00 FF` → Tous les moteurs ON          | Dashboard (Activer vibrations) |
| `0x05` | Ping                  | `0x00`                     | `0x00`                             | `05 00 00`                                 | Keep-alive                     |
| `0x06` | Demande batterie      | `0x00`                     | `0x00`                             | `06 00 00`                                 | Polling batterie               |

### Motors ID (5x3)

| Rangée    | Gauche        | Centre        | Droite        |
| ---------- | ------------- | ------------- | ------------- |
| 1 (haut)   | M1 =`0x01`  | M2 =`0x02`  | M3 =`0x03`  |
| 2          | M4 =`0x04`  | M5 =`0x05`  | M6 =`0x06`  |
| 3 (milieu) | M7 =`0x07`  | M8 =`0x08`  | M9 =`0x09`  |
| 4          | M10 =`0x0A` | M11 =`0x0B` | M12 =`0x0C` |
| 5 (bas)    | M13 =`0x0D` | M14 =`0x0E` | M15 =`0x0F` |

### Patterns IDs

| ID       | Nom       | Description                              |
| -------- | --------- | ---------------------------------------- |
| `0x01` | Vague     | Rangées activées de haut en bas        |
| `0x02` | Pluie     | Moteurs aléatoires, intensité variable |
| `0x03` | Impulsion | Tous les moteurs ON/OFF en alternance    |
| `0x04` | Cercle    | Rotation sur le périmètre de la grille |

### Responses from ESP32

| Response              | Description in serialPrint          |
| --------------------- | ----------------------------------- |
| `CONNECTED`         | App connectée                      |
| `MOTOR_X_ON_Y`      | Moteur X activé à intensité Y    |
| `MOTOR_X_OFF`       | Moteur X désactivé                |
| `PATTERN_VAGUE`     | Pattern Vague lancé                |
| `PATTERN_PLUIE`     | Pattern Pluie lancé                |
| `PATTERN_IMPULSION` | Pattern Impulsion lancé            |
| `PATTERN_CERCLE`    | Pattern Cercle lancé               |
| `STOP_OK`           | Arrêt d'urgence exécuté          |
| `MASTER_ON_Y`       | Tous les moteurs ON à intensité Y |
| `MASTER_OFF`        | Tous les moteurs coupés            |
| `PONG`              | Réponse au ping                    |
| `BAT_XX`            | Niveau batterie (XX%)               |
| `ERR_LEN`           | Commande invalide (taille ≠ 3)     |

### Test mode

The  `esp32-code/code.ino` file has a `TEST_MODE`  flga that is set to true. When in test mode no I/O of the carte are used. Instead we do printe everythign via serial communication.

## Notes

* Firebase is used as our databse provider. The sessions of the user are saved on the databse. This includes that start and stop time, as well as the mean of the vibrations amplitude.
* The bluetooth has a service and a protocol.
  * Protocol has all the motors details and hard coded options like the proposed aplitudes fo rthe programmes page
  * Servic eis for all teh communication part. There is battery module that allows to simply reccurently to check the current that is available on the batetry. And also has all the callbacks and connection requests to the ESP32 module using the UUID that were hardcoded using the Arduino IDE.
* Teh user can now sign up with their email and then he is asked for their phone number. Then he can use either the phone numer of the password/email method. FaceID can be an option as well
