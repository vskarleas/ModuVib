# Versions

* V1 : First itteration of the UI of the App. Now we will work on the wireless module connection with the ESP32 micro-controller.
* V2.1 : This versions implements databse support with FaceID and TouchID option. The required bluetooth services were created and connected with the ui.

## TO-DO

* [X] I have to recompile everything in order to refresh the build/ folder. This will allow also to undersatnd the architecture of the app
* [X] Understand the code and its structure
* [X] Update the manual screen
* [X] Write the code for the ESP32 in order to communicate under the name ModuVib

## Notes

* Firebase is used as our databse provider. The sessions of the user are saved on the databse. This includes that start and stop time, as well as the mean of the vibrations amplitude.
* The bluetooth has a service and a protocol.
  * Protocol has all the motors details and hard coded options like the proposed aplitudes fo rthe programmes page
  * Servic eis for all teh communication part. There is battery module that allows to simply reccurently to check the current that is available on the batetry. And also has all the callbacks and connection requests to the ESP32 module using the UUID that were hardcoded using the Arduino IDE.
* Teh user can now sign up with their email and then he is asked for their phone number. Then he can use either the phone numer of the password/email method. FaceID can be an option as well
