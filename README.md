# RPIKiosk
Raspberry Pi Kiosk with Splash Screen

## Day of Setup
1. Setup the FTC Scoring System. Ensure it is powered on, connected to the network, and the software is running.
2. Run Power and Ethernet to the Raspberry Pi
3. Configure the DIP Switches per the configuration guide
4. Power on the Raspberry Pi

## Basic Installation Instructions
1. Raspberry Pi Imager
2. Raspberry Pi OS (Legacy) Lite
3. Configuration to create an account
4. Name: pi
5. Password: mushroom

By default the kiosk assumes the IP of the FTC Scorekeeper software is 192.168.1.101

### Configurations
Changes can be made by modifying /home/pi/.config/openbox/environment
* FTCEVENTSERVER_EVENTCODE - The eventcode for the event. Refer to the FTC scoring system for this value. _NOTE:_ When manually entering an event code you still have to use the DIP Switches to configure the MODE and FIELD.
* FTCEVENTSERVER_IP - IP Address of the FTC server running the scorekeeping software.
* KIOSKURL - URL you would like to display instead of the FTC scoring system (e.g. Twitch Feed)

### Troubleshooting

#### Black Screen
If you receive just a black screen
1. Check the last entries in the log file at /home/pi/RPIKiosk.log.
2. If the log file has not updated recently run the following command to fix the line endings in autostart and reboot.
```sudo dos2unix /etc/xdg/openbox/autostart```
