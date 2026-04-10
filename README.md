# ModuVib

[English](#english) | [Français](#français)

---

# English

## Versions

* V1: First iteration of the app UI. Next step is the wireless module connection with the ESP32 micro-controller.
* V2.1: Implemented database support with FaceID and TouchID options. The required Bluetooth services were created and connected to the UI. All hard-coded options were removed.
* V3: Users can now manually choose whether to enable a specific motor from the map page.
* V4.1: Fixed communication issues with the ESP32 BLE board.
* V4.2: Fixed iOS security issues with continuous Bluetooth.
* V5.0: Fixed Android communication issues with the ESP32 BLE board and some presentation features on the settings page.
* V5.1: Updated `code.ino` to work with the open drains where the motors are connected, and updated the design of the manual page.
* V6.1:
  * Added a logical-to-physical motor mapping in the ESP32 firmware (`#define M1..M15`), allowing rewiring without modifying the rest of the code.
  * Intensity control via PWM on the G (OE) pin of the TPIC6C595 (`analogWrite`).
  * Redesigned the manual control screen: removed Precision/Free Draw modes, motor selection and deselection via simple touch or drag.
* V6.2: Widened the lower part of the back silhouette so that M13 and M15 stay inside the outline. Fixed the gesture conflict: dragging on the grid no longer triggers page changes.
* V6.3: Added intensity slider on the manual control page.

## Compilation

### Prerequisites

* Flutter SDK installed ([flutter.dev](https://flutter.dev/docs/get-started/install))
* For iOS: Xcode installed with a valid Apple Developer account
* For Android: Android Studio with the Android SDK

### Android

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

The generated APKs are located at:

* Debug: `build/app/outputs/flutter-apk/app-debug.apk`
* Release: `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
# Build for a physical device (requires signing)
flutter build ios --release

# Open in Xcode for archiving / TestFlight
open ios/Runner.xcworkspace
```

In Xcode, select **Product > Archive** to create an `.ipa` for distribution via TestFlight or the App Store.

> **Note:** iOS builds can only be compiled on macOS with Xcode.

### ESP32 Firmware

Open `esp32-code/code/code.ino` in the Arduino IDE, select the ESP32 board, and upload. Set the `TEST_MODE` flag to `true` for serial-only debugging (no I/O on the board).

## Releases

Pre-built Android APKs are available on the [GitHub Releases](https://github.com/vskarleas/ModuVib/releases) page. Download the `app-release.apk` file from the latest release to install on an Android device (enable *Install from unknown sources*).

## Project Organisation

```text
.
├── esp32-code/code/code.ino   # ESP32 firmware (Arduino)
├── torso-designer/            # HTML tool for the torso SVG design
├── assets/icon/               # App icon assets
├── lib/
│   ├── main.dart              # App entry point
│   ├── firebase_options.dart  # Firebase configuration (git-ignored)
│   ├── core/
│   │   ├── providers/         # Riverpod providers (app_providers.dart)
│   │   ├── router/            # GoRouter configuration (app_router.dart)
│   │   ├── services/
│   │   │   ├── auth_service.dart            # Firebase authentication
│   │   │   ├── ble_protocol.dart            # BLE command encoding (3-byte protocol)
│   │   │   ├── ble_service.dart             # BLE connection & communication
│   │   │   ├── local_security_service.dart  # PIN / FaceID / TouchID
│   │   │   └── session_service.dart         # Session tracking in Firebase
│   │   └── theme/             # App theme (app_theme.dart)
│   └── presentation/
│       ├── navigation/        # Bottom navigation scaffold
│       ├── widgets/           # Shared widgets (top_bar.dart)
│       └── screens/
│           ├── login_screen.dart            # Email / phone login
│           ├── create_account_screen.dart   # Sign-up flow
│           ├── email_verification_screen.dart
│           ├── security_setup_screen.dart   # Biometric / PIN setup
│           ├── pin_screen.dart              # PIN entry
│           ├── app_lock_screen.dart         # Lock screen (FaceID / PIN)
│           ├── dashboard_screen.dart        # Home – connection status, master control
│           ├── manual_control_screen.dart   # Motor grid with drag selection + intensity
│           ├── patterns_screen.dart         # Pre-defined vibration patterns
│           └── settings_screen.dart         # Account, firmware info, about
├── android/                   # Android platform files
├── ios/                       # iOS platform files
└── pubspec.yaml               # Flutter dependencies
```

## TO-DO

* [X] Recompile everything to refresh the build/ folder and understand the app architecture
* [X] Understand the code and its structure
* [X] Update the manual screen
* [X] Write the ESP32 code to communicate under the name ModuVib
* [X] Fix login issue with phone number (Android showed "Authentication error (unknown)", iOS was stuck)
* [X] Integrate the codes from the notes section that Dounia sent into the different actions of the app
* [X] Fix reset password functionality
* [X] Integrate PIN page with FaceID for returning sessions on the app
* [X] Add logic on action triggers when the device is not connected — prevent any message from being sent in that scenario
* [X] Allow users to update their account
* [X] Added connect button with logic on the dashboard screen
* [X] When logging in to an existing account, activate biometric security if it is not set up, and set up the PIN instead
* [X] If the user has already signed in once, do not redirect to the PIN / FaceID authentication screen
* [X] Changed the hard-coded voltage to a value related to the ESP32 chip on the dashboard page
* [X] Prepare V5.0: detailed statistics view, patterns able to send a stop command even if the phone is locked, fix firmware and "About" section in settings (pop-up opening from the bottom — the issue was a white background colour; we want the same style as the battery pop-up but larger)

## BLE Protocol — 3-byte commands `[CMD, TARGET, VALUE]`

Each command sent by the Flutter app to the ESP32 is composed of 3 bytes.

### Commands

| CMD | Name | Target | Value | Example | Purpose |
| --- | ---- | ------ | ----- | ------- | ------- |
| `0x01` | Individual motor | Motor ID (0x01–0x0F) | Intensity (0x00=OFF, 0x01–0xFF=ON) | `01 05 FF` → Motor 5 ON full power | Manual control |
| `0x02` | Pattern | Pattern ID (see below) | Intensity (0x00–0xFF) | `02 01 BF` → Wave at 75% | Programmes |
| `0x03` | Emergency stop | `0x00` | `0x00` | `03 00 00` | STOP button (top bar) |
| `0x04` | Master (all motors) | `0x00` | Intensity (0x00=OFF, 0x01–0xFF=ON) | `04 00 FF` → All motors ON | Dashboard (Activate vibrations) |
| `0x05` | Ping | `0x00` | `0x00` | `05 00 00` | Keep-alive |
| `0x06` | Battery request | `0x00` | `0x00` | `06 00 00` | Battery polling |

### Motor IDs

| Row | Col 1 | Col 2 | Col 3 | Col 4 |
| --- | ----- | ----- | ----- | ----- |
| 1 (top) | M1 = `0x01` | M2 = `0x02` | M3 = `0x03` | |
| 2 | M4 = `0x04` | M5 = `0x05` | M6 = `0x06` | M7 = `0x07` |
| 3 (middle) | M8 = `0x08` | M9 = `0x09` | M10 = `0x0A` | |
| 4 | M11 = `0x0B` | M12 = `0x0C` | | |
| 5 (bottom) | M13 = `0x0D` | M14 = `0x0E` | M15 = `0x0F` | |

### Pattern IDs

| ID | Name | Description |
| --- | ---- | ----------- |
| `0x01` | Wave | Rows activated from top to bottom |
| `0x02` | Rain | Random motors, variable intensity |
| `0x03` | Pulse | All motors ON/OFF alternating |
| `0x04` | Circle | Rotation around the grid perimeter |

### ESP32 Responses

| Response | Description |
| -------- | ----------- |
| `CONNECTED` | App connected |
| `MOTOR_X_ON_Y` | Motor X activated at intensity Y |
| `MOTOR_X_OFF` | Motor X deactivated |
| `PATTERN_VAGUE` | Wave pattern started |
| `PATTERN_PLUIE` | Rain pattern started |
| `PATTERN_IMPULSION` | Pulse pattern started |
| `PATTERN_CERCLE` | Circle pattern started |
| `STOP_OK` | Emergency stop executed |
| `MASTER_ON_Y` | All motors ON at intensity Y |
| `MASTER_OFF` | All motors off |
| `PONG` | Ping response |
| `BAT_XX` | Battery level (XX%) |
| `ERR_LEN` | Invalid command (length != 3) |

### Test Mode

The `esp32-code/code/code.ino` file has a `TEST_MODE` flag set to `true`. In test mode, no board I/O is used; instead, everything is printed via serial communication.

## Notes

* Firebase is used as the database provider. User sessions are saved in the database, including start and stop times as well as the mean vibration amplitude.
* Bluetooth has a service and a protocol:
  * The protocol contains all the motor details and hard-coded options such as the proposed amplitudes for the programmes page.
  * The service handles all communication. It includes a battery module that periodically checks the available current on the battery, and manages all callbacks and connection requests to the ESP32 module using the UUIDs hard-coded via the Arduino IDE.
* Users can sign up with their email and are then asked for their phone number. They can then log in using either the phone number or the email/password method. FaceID is also available as an option.

---

# Français

## Versions

* V1 : Premiere iteration de l'interface utilisateur de l'application. Prochaine etape : connexion du module sans fil avec le micro-controleur ESP32.
* V2.1 : Implementation du support de la base de donnees avec options FaceID et TouchID. Les services Bluetooth necessaires ont ete crees et connectes a l'interface. Toutes les options codees en dur ont ete supprimees.
* V3 : L'utilisateur peut desormais choisir manuellement s'il souhaite activer un moteur specifique depuis la page de la carte.
* V4.1 : Correction de problemes de communication avec la carte BLE ESP32.
* V4.2 : Correction de problemes de securite iOS lies au Bluetooth continu.
* V5.0 : Correction de problemes de communication Android avec la carte BLE ESP32 et amelioration de la presentation sur la page des parametres.
* V5.1 : Mise a jour de `code.ino` pour fonctionner avec les drains ouverts ou les moteurs sont connectes, et mise a jour du design de la page de controle manuel.
* V6.1 :
  * Ajout d'un mapping logique-physique des moteurs dans le firmware ESP32 (`#define M1..M15`) permettant de reconfigurer le cablage sans modifier le reste du code.
  * Controle de l'intensite via PWM sur la broche G (OE) du TPIC6C595 (`analogWrite`).
  * Refonte de l'ecran de controle manuel : suppression des modes Precision/Dessin Libre, selection et deselection des moteurs par simple toucher ou glisser-deposer.
* V6.2 : Silhouette dorsale elargie en bas pour que M13 et M15 restent a l'interieur du contour. Correction du conflit de gestes : le glisser-deposer sur la grille ne declenche plus le changement de page.
* V6.3 : Ajout d'un curseur d'intensite sur la page de controle manuel.

## Compilation

### Pre-requis

* Flutter SDK installe ([flutter.dev](https://flutter.dev/docs/get-started/install))
* Pour iOS : Xcode installe avec un compte Apple Developer valide
* Pour Android : Android Studio avec le SDK Android

### Android

```bash
# APK de debug
flutter build apk --debug

# APK de release
flutter build apk --release
```

Les APK generes se trouvent dans :

* Debug : `build/app/outputs/flutter-apk/app-debug.apk`
* Release : `build/app/outputs/flutter-apk/app-release.apk`

### iOS

```bash
# Build pour un appareil physique (necessite la signature)
flutter build ios --release

# Ouvrir dans Xcode pour l'archivage / TestFlight
open ios/Runner.xcworkspace
```

Dans Xcode, selectionnez **Product > Archive** pour creer un `.ipa` distribuable via TestFlight ou l'App Store.

> **Note :** Les builds iOS ne peuvent etre compiles que sur macOS avec Xcode.

### Firmware ESP32

Ouvrir `esp32-code/code/code.ino` dans l'Arduino IDE, selectionner la carte ESP32 et telecharger. Mettre le flag `TEST_MODE` a `true` pour le debogage en serie uniquement (pas d'E/S sur la carte).

## Versions publiees

Les APK Android pre-compiles sont disponibles sur la page [GitHub Releases](https://github.com/vskarleas/ModuVib/releases). Telechargez le fichier `app-release.apk` depuis la derniere version pour l'installer sur un appareil Android (activez *Installation depuis des sources inconnues*).

## Organisation du projet

```text
.
├── esp32-code/code/code.ino   # Firmware ESP32 (Arduino)
├── torso-designer/            # Outil HTML pour le design SVG du torse
├── assets/icon/               # Icones de l'application
├── lib/
│   ├── main.dart              # Point d'entree de l'application
│   ├── firebase_options.dart  # Configuration Firebase (ignore par git)
│   ├── core/
│   │   ├── providers/         # Providers Riverpod (app_providers.dart)
│   │   ├── router/            # Configuration GoRouter (app_router.dart)
│   │   ├── services/
│   │   │   ├── auth_service.dart            # Authentification Firebase
│   │   │   ├── ble_protocol.dart            # Encodage des commandes BLE (protocole 3 octets)
│   │   │   ├── ble_service.dart             # Connexion et communication BLE
│   │   │   ├── local_security_service.dart  # PIN / FaceID / TouchID
│   │   │   └── session_service.dart         # Suivi des sessions dans Firebase
│   │   └── theme/             # Theme de l'application (app_theme.dart)
│   └── presentation/
│       ├── navigation/        # Scaffold de navigation inferieure
│       ├── widgets/           # Widgets partages (top_bar.dart)
│       └── screens/
│           ├── login_screen.dart            # Connexion email / telephone
│           ├── create_account_screen.dart   # Inscription
│           ├── email_verification_screen.dart
│           ├── security_setup_screen.dart   # Configuration biometrique / PIN
│           ├── pin_screen.dart              # Saisie du PIN
│           ├── app_lock_screen.dart         # Ecran de verrouillage (FaceID / PIN)
│           ├── dashboard_screen.dart        # Accueil – statut connexion, controle global
│           ├── manual_control_screen.dart   # Grille moteurs avec selection par glissement + intensite
│           ├── patterns_screen.dart         # Programmes de vibration pre-definis
│           └── settings_screen.dart         # Compte, infos firmware, a propos
├── android/                   # Fichiers plateforme Android
├── ios/                       # Fichiers plateforme iOS
└── pubspec.yaml               # Dependances Flutter
```

## A FAIRE

* [X] Recompiler le projet pour rafraichir le dossier build/ et comprendre l'architecture de l'application
* [X] Comprendre le code et sa structure
* [X] Mettre a jour l'ecran de controle manuel
* [X] Ecrire le code ESP32 pour communiquer sous le nom ModuVib
* [X] Corriger le probleme de connexion par numero de telephone (Android affichait « Erreur d'authentification (inconnue) », iOS restait bloque)
* [X] Integrer les codes de la section notes envoyes par Dounia dans les differentes actions de l'application
* [X] Corriger la fonctionnalite de reinitialisation du mot de passe
* [X] Integrer la page PIN avec FaceID pour les sessions de retour sur l'application
* [X] Ajouter une logique sur les declencheurs d'actions lorsque l'appareil n'est pas connecte — empecher l'envoi de tout message dans ce cas
* [X] Permettre aux utilisateurs de mettre a jour leur compte
* [X] Ajout du bouton de connexion avec logique sur le tableau de bord
* [X] Lors de la connexion a un compte existant, activer la securite biometrique si elle n'est pas configuree, et configurer le PIN a la place
* [X] Si l'utilisateur s'est deja connecte une fois, ne pas le rediriger vers l'ecran d'authentification PIN / FaceID
* [X] Remplacement de la tension codee en dur par une valeur liee a la puce ESP32 sur la page du tableau de bord
* [X] Preparer la V5.0 : vue detaillee des statistiques, envoi de la commande stop depuis les patterns meme si le telephone est verrouille, correction du firmware et de la section « A propos » dans les parametres (pop-up s'ouvrant par le bas — le probleme etait la couleur de fond blanche ; meme style que le pop-up batterie mais plus grand)

## Protocole BLE — Commandes 3 octets `[CMD, TARGET, VALUE]`

Chaque commande envoyee par l'application Flutter au ESP32 est composee de 3 octets.

### Commandes

| CMD | Nom | Cible | Valeur | Exemple | Usage |
| --- | --- | ----- | ------ | ------- | ----- |
| `0x01` | Moteur individuel | ID moteur (0x01–0x0F) | Intensite (0x00=OFF, 0x01–0xFF=ON) | `01 05 FF` → Moteur 5 ON pleine puissance | Controle manuel |
| `0x02` | Pattern | ID pattern (voir ci-dessous) | Intensite (0x00–0xFF) | `02 01 BF` → Vague a 75% | Programmes |
| `0x03` | Arret d'urgence | `0x00` | `0x00` | `03 00 00` | Bouton STOP (barre superieure) |
| `0x04` | Master (tous moteurs) | `0x00` | Intensite (0x00=OFF, 0x01–0xFF=ON) | `04 00 FF` → Tous les moteurs ON | Tableau de bord (Activer vibrations) |
| `0x05` | Ping | `0x00` | `0x00` | `05 00 00` | Keep-alive |
| `0x06` | Demande batterie | `0x00` | `0x00` | `06 00 00` | Polling batterie |

### IDs des moteurs

| Rangee | Col 1 | Col 2 | Col 3 | Col 4 |
| ------ | ----- | ----- | ----- | ----- |
| 1 (haut) | M1 = `0x01` | M2 = `0x02` | M3 = `0x03` | |
| 2 | M4 = `0x04` | M5 = `0x05` | M6 = `0x06` | M7 = `0x07` |
| 3 (milieu) | M8 = `0x08` | M9 = `0x09` | M10 = `0x0A` | |
| 4 | M11 = `0x0B` | M12 = `0x0C` | | |
| 5 (bas) | M13 = `0x0D` | M14 = `0x0E` | M15 = `0x0F` | |

### IDs des patterns

| ID | Nom | Description |
| --- | --- | ----------- |
| `0x01` | Vague | Rangees activees de haut en bas |
| `0x02` | Pluie | Moteurs aleatoires, intensite variable |
| `0x03` | Impulsion | Tous les moteurs ON/OFF en alternance |
| `0x04` | Cercle | Rotation sur le perimetre de la grille |

### Reponses du ESP32

| Reponse | Description |
| ------- | ----------- |
| `CONNECTED` | Application connectee |
| `MOTOR_X_ON_Y` | Moteur X active a l'intensite Y |
| `MOTOR_X_OFF` | Moteur X desactive |
| `PATTERN_VAGUE` | Pattern Vague lance |
| `PATTERN_PLUIE` | Pattern Pluie lance |
| `PATTERN_IMPULSION` | Pattern Impulsion lance |
| `PATTERN_CERCLE` | Pattern Cercle lance |
| `STOP_OK` | Arret d'urgence execute |
| `MASTER_ON_Y` | Tous les moteurs ON a l'intensite Y |
| `MASTER_OFF` | Tous les moteurs coupes |
| `PONG` | Reponse au ping |
| `BAT_XX` | Niveau batterie (XX%) |
| `ERR_LEN` | Commande invalide (taille != 3) |

### Mode test

Le fichier `esp32-code/code/code.ino` possede un flag `TEST_MODE` regle sur `true`. En mode test, aucune E/S de la carte n'est utilisee ; tout est affiche via la communication serie.

## Notes

* Firebase est utilise comme fournisseur de base de donnees. Les sessions utilisateur sont sauvegardees dans la base de donnees, incluant les heures de debut et de fin ainsi que la moyenne de l'amplitude des vibrations.
* Le Bluetooth comprend un service et un protocole :
  * Le protocole contient tous les details des moteurs et les options codees en dur, comme les amplitudes proposees pour la page des programmes.
  * Le service gere toute la communication. Il inclut un module batterie qui verifie periodiquement le courant disponible sur la batterie, et gere tous les callbacks et les demandes de connexion au module ESP32 via les UUID codes en dur dans l'Arduino IDE.
* L'utilisateur peut s'inscrire avec son email puis est invite a fournir son numero de telephone. Il peut ensuite se connecter soit par numero de telephone, soit par email/mot de passe. FaceID est egalement disponible en option.
