#!/bin/bash

#
# How to run: wget -O - "https://raw.githubusercontent.com/KingLinkTiger/RPIKiosk/CHS/setupKiosk.sh" | bash
# On EN GB Keyboard:
#	- Right Alt + Shift + ~ Key = |
#	- Shift + 2 = “
#
#	Intall Time: Roughly 22 Minuites
#
#
# Script assumes "pi" account is being used
# Customizations go in: /home/pi/.config/openbox/environment
# 
# TODO List
# All fields = Bind to all fields
#
# Raspberry Pi PIN Configurations
# MODE Pins
# PIN 32/12 - FIELD Display
# PIN 36/16 - PIT DISPLAY
# PIN 38/20 - INSPECTIONS DISPLAY
# PIN 40/21 - AUDIANCE DISPLAY
#
# FIELD Pins
# PIN 21/6 = FIELD 1
# PIN 33/13 = FIELD 2
# PIN 35/19 = FIELD 3
# PIN 37/26 = FIELD 4
#
# Reference: https://learn.sparkfun.com/tutorials/raspberry-gpio/gpio-pinout

#Variables
SPLASHIMAGEURL="https://info.firstinspires.org/hubfs/2023%20Season/2023%20season%20assets/first-energize-assets/firstenergize-wallpaper-desktop-1.png"
PIPASSWORD=mushroom
ROOTPASSWORD=mushroom

#Optional Variables
locale=en_US.UTF-8
layout=us
timezone='US/Eastern'

#--------------------------------------------
#SCRIPT BELOW
#--------------------------------------------

#Change pi Password
echo -e "$PIPASSWORD\n$PIPASSWORD" | sudo passwd pi

#Set boot behavior to automatically log in as pi
sudo raspi-config nonint do_boot_behaviour "B2"

#Set audio to force output to 3.5mm jack
sudo raspi-config nonint do_audio "1"

#Set output volume to 100%
amixer set PCM -- 100%

#Apt-get update and upgrade
sudo apt-get update
sudo apt-get -y upgrade

#Install all of the needed apps
#17DEC22 - Added jq requirement
sudo apt-get -y install --no-install-recommends xserver-xorg x11-xserver-utils xinit openbox chromium-browser fbi jq

#Configure Openbox autostart
	#Remove default autostart file
	if [ -f /etc/xdg/openbox/autostart ]; then
		sudo rm /etc/xdg/openbox/autostart
	fi
	
	# Create the openbox folder if it does not exist
	if [ ! -f /etc/xdg/openbox ]; then
		sudo mkdir /etc/xdg/openbox
	fi
	
	#Create a new autostart with the information we want

	sudo sh -c 'cat > /etc/xdg/openbox/autostart' << EOF
#cat <<EOT >>/home/pi/test.txt
#Disable any form of screen saver / screen blanking / power management
xset s off
xset s noblank
xset -dpms

#Allow quitting the X server which CTRL-ALT-BACKSPACE
setxkbmap -option terminate:ctrl_alt_bksp

#Start Chromium in kiosk mode
cat /home/pi/.config/chromium/'Local State' | jq '.user_experience_metrics.stability.exited_cleanly = false' > /home/pi/.config/chromium/tmp_localState && mv /home/pi/.config/chromium/tmp_localState /home/pi/.config/chromium/'Local State'
#sed -i 's/"exited_cleanly":false/"exited_cleanly":true' /home/pi/.config/chromium/'Local State'
#sed -i 's/"exited_cleanly":false/"exited_cleanly":true; s/"exit_type":"[^"]\+"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences

if [ -z "$FTCEVENTSERVER_IP" ] ; then
    FTCEVENTSERVER_IP="192.168.1.101"
fi

# Check if the provided FTC Server is online! If not write an error to the screen and exit!
if [ $(nc -z -w3 $FTCEVENTSERVER_IP 80; echo $?) -ne 0 ]; then
	echo "ERROR: FTC Server ${FTCEVENTSERVER_IP} is NOT online! Please check if the IP is correct or if the server is online/accessible."
    sed -i -e 's/\(<ERRORCODE>\).*\(<\/ERRORCODE>\)/<ERRORCODE>FTC Server '"${FTCEVENTSERVER_IP}"' is NOT online! Please check if the IP is correct or if the server is online\/accessible.<\/ERRORCODE>/g' /home/pi/error.html
    KIOSKURL="file:///home/pi/error.html"
    chromium-browser --disable-infobars --kiosk "$KIOSKURL"
    exit 1;
fi

if [ -z "$FTCEVENTSERVER_EVENTCODE" ] ; then
    FTCEVENTSERVER_EVENTS=$(curl -s -L -X GET http://${FTCEVENTSERVER_IP}/api/v1/events)

    numFTCEVENTSERVER_EVENTS=$(echo $FTCEVENTSERVER_EVENTS | jq -r ".eventCodes" | jq length)

    if [ $numFTCEVENTSERVER_EVENTS -eq 1 ] ; then
        FTCEVENTSERVER_EVENTCODE=$(echo $FTCEVENTSERVER_EVENTS | jq -r ".eventCodes[]")
    else 
        KIOSKURL="http://${FTCEVENTSERVER_IP}/"
    fi
fi

#Get the number of fields for this event
numFTCEVENTSERVERFIELDS=$(curl -s -L -X GET http://${FTCEVENTSERVER_IP}/api/v1/events/${FTCEVENTSERVER_EVENTCODE}/matches/ | jq '([ .[][].field ] | max)')

if [ -z "$KIOSKURL" ] ; then
    # Pin Setup
    # https://learn.sparkfun.com/tutorials/raspberry-gpio/gpio-pinout
    #
    # MODE Pins
    # PIN 32/12 - FIELD Display
    # PIN 36/16 - PIT DISPLAY
    # PIN 38/20 - INSPECTIONS DISPLAY
    # PIN 40/21 - AUDIANCE DISPLAY
    #
    # FIELD Pins
    # PIN 21/6 = FIELD 1
    # PIN 33/13 = FIELD 2
    # PIN 35/19 = FIELD 3
    # PIN 37/26 = FIELD 4
    #

    raspi-gpio set 12 ip pd
    raspi-gpio set 16 ip pd
    raspi-gpio set 20 ip pd
    raspi-gpio set 21 ip pd

    raspi-gpio set 6 ip pd
    raspi-gpio set 13 ip pd
    raspi-gpio set 19 ip pd
    raspi-gpio set 26 ip pd

    MODE_FIELD=$(raspi-gpio get 12 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')
    MODE_PIT=$(raspi-gpio get 16 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')
    MODE_INSPECTIONS=$(raspi-gpio get 20 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')
    MODE_AUDIANCE=$(raspi-gpio get 21 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')

    FIELD1=$(raspi-gpio get 6 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')
    FIELD2=$(raspi-gpio get 13 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')
    FIELD3=$(raspi-gpio get 19 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')
    FIELD4=$(raspi-gpio get 26 | awk '{ delete vars; for(i = 1; i <= NF; ++i) { n = index($i, "="); if(n) { vars[substr($i, 1, n - 1)] = substr($i, n + 1) } } Var = vars["level"] } { print Var }')
    

    if [ $(($MODE_FIELD + $MODE_PIT + $MODE_INSPECTIONS + $MODE_AUDIANCE)) -eq 0 ]; then
        echo "ERROR: No mode selected! Please verify then reboot."
        sed -i -e 's/\(<ERRORCODE>\).*\(<\/ERRORCODE>\)/<ERRORCODE>No mode selected! Please verify then reboot.<\/ERRORCODE>/g' /home/pi/error.html
        KIOSKURL="file:///home/pi/error.html"
        chromium-browser --disable-infobars --kiosk "$KIOSKURL"
        exit 1;
    fi

    if [ $(($MODE_FIELD + $MODE_PIT + $MODE_INSPECTIONS + $MODE_AUDIANCE)) -gt 1 ]; then
        echo "ERROR: More than one MODE has been selected! Please verify then reboot."
        sed -i -e 's/\(<ERRORCODE>\).*\(<\/ERRORCODE>\)/<ERRORCODE>More than one MODE has been selected! Please verify then reboot.<\/ERRORCODE>/g' /home/pi/error.html
        KIOSKURL="file:///home/pi/error.html"
        chromium-browser --disable-infobars --kiosk "$KIOSKURL"
        exit 1;
    fi

    if [ $MODE_FIELD -eq 1 ] ; then

        if [ $FIELD1 -eq 1 ] ; then
            FIELDNUMBER=1
        elif [ $FIELD2 -eq 1 ] ; then
            FIELDNUMBER=2
        elif [ $FIELD3 -eq 1 ] ; then
            FIELDNUMBER=3
        elif [ $FIELD4 -eq 1 ] ; then
            FIELDNUMBER=4
		fi

        # If the field we have selected is higher than the number of fields we have error out!
        if [ $FIELDNUMBER -gt $numFTCEVENTSERVERFIELDS ] ; then
            echo "ERROR: The selected FIELD is incorrect! Please verify then reboot."
            sed -i -e 's/\(<ERRORCODE>\).*\(<\/ERRORCODE>\)/<ERRORCODE>The selected FIELD is incorrect! Please verify then reboot.<\/ERRORCODE>/g' /home/pi/error.html
            KIOSKURL="file:///home/pi/error.html"
        elif [ $(($FIELD1 + $FIELD2 + $FIELD3 + $FIELD4)) -gt 1 ]; then
            # If more than one field is selected: ERROR Out!
            echo "ERROR: More than one FIELD has been selected! Please verify then reboot."
            sed -i -e 's/\(<ERRORCODE>\).*\(<\/ERRORCODE>\)/<ERRORCODE>More than one FIELD has been selected! Please verify then reboot.<\/ERRORCODE>/g' /home/pi/error.html
            KIOSKURL="file:///home/pi/error.html"
        else
            KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=field&bindToField=${FIELDNUMBER}&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=true&muteRandomizationResults=false&fieldStyleTimer=true&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=false&showMeetRankings=false&rankingsAllTeams=true"
        fi
	else
        if [ $MODE_PIT -eq 1 ] ; then
            KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=pit&bindToField=all&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=false&muteRandomizationResults=false&fieldStyleTimer=false&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=true&showMeetRankings=false&rankingsAllTeams=true"
        elif [ $MODE_INSPECTIONS -eq 1 ] ; then
            KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/status/proj/3/"
        elif [ $MODE_AUDIANCE -eq 1 ] ; then
            KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=audience&bindToField=all&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=true&muteRandomizationResults=false&fieldStyleTimer=false&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=false&showMeetRankings=false&rankingsAllTeams=true"
        fi
	fi
fi


#Debugging
#echo "$(date) : MODE_FIELD = $MODE_FIELD" >> /home/pi/openbox.log
#echo "$(date) : FIELD1 = $FIELD1" >> /home/pi/openbox.log
#echo "$(date) : FIELD2 = $FIELD2" >> /home/pi/openbox.log
#cho "$(date) : FIELD3 = $FIELD3" >> /home/pi/openbox.log
#echo "$(date) : FIELD4 = $FIELD4" >> /home/pi/openbox.log
#echo "$(date) : MODE_PIT = $MODE_PIT" >> /home/pi/openbox.log
#echo "$(date) : MODE_INSPECTIONS = $MODE_INSPECTIONS" >> /home/pi/openbox.log
#echo "$(date) : MODE_AUDIANCE = $MODE_AUDIANCE" >> /home/pi/openbox.log
#echo "$(date) : FTCEVENTSERVER_IP = $FTCEVENTSERVER_IP" >> /home/pi/openbox.log
#echo "$(date) : FTCEVENTSERVER_EVENTCODE = $FTCEVENTSERVER_EVENTCODE" >> /home/pi/openbox.log
#echo "$(date) : KIOSKURL = $KIOSKURL" >> /home/pi/openbox.log

chromium-browser --disable-infobars --kiosk "$KIOSKURL"
EOF

#Remove .bash_profile if it exists
if [ -f /home/pi/.bash_profile ]; then
	rm /home/pi/.bash_profile
fi

#Create the .bash_profile
cat <<EOT >> /home/pi/.bash_profile
[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx -- -nocursor
EOT

if grep -Fq "disable_splash" /boot/config.txt
then
	#Disable Splash exists in file. We need to replace the line to order to ensure it's set the way we want
	sudo sed -i 's/disable_splash=.*/disable_splash=1/' /boot/config.txt
	
else
	#Disable Splash does not exist in file. Add it to the end.
	sudo sh -c 'echo "disable_splash=1" >> /boot/config.txt'
fi

#Edit /boot/cmdline.txt in order to supress some items on boot
if ! grep -Fq "logo.nologo consoleblank=0 quiet" /boot/cmdline.txt
then
	#The file is not the way we want it configure so we need to configure it.
	sudo sed -i 's/$/ logo.nologo consoleblank=0 quiet/' /boot/cmdline.txt
fi


#Set Root's password
echo -e "$ROOTPASSWORD\n$ROOTPASSWORD" | sudo passwd root

#Touch Root ENV file
	if [ -f /home/pi/.config/openbox/environment ]; then
		sudo rm /home/pi/.config/openbox/environment
	fi

    if [ ! -d "/home/pi/.config/openbox" ]; then
        mkdir "/home/pi/.config/openbox"
    fi

cat <<EOT >> /home/pi/.config/openbox/environment
export FTCEVENTSERVER_EVENTCODE=""
export FTCEVENTSERVER_IP="192.168.1.101"
expoprt KIOSKURL=""
EOT

#---------------------------------------------------
#THE REST OF THE COMMANDS NEED TO BE DONE AS ROOT
#---------------------------------------------------

#Change user to root
sudo su - <<EOF

#Check if /etc/systemd/system/splashscreen.service does NOT exist then create it
if [ ! -f /etc/systemd/system/splashscreen.service ]; then
	#"File not found"
sudo cat <<EOT >>/etc/systemd/system/splashscreen.service
[Default]
Description=Splash screen
DefaultDependencies=no
After=local-fs.target

[Service]
ExecStart=/usr/bin/fbi -d /dev/fb0 --noverbose -a /opt/splash.jpg
StandardInput=tty
StandardOutput=tty

[Install]
WantedBy=sysinit.target
EOT

fi


#Check if splash image does not exist and download it
if [ ! -f /opt/splash.jpg ]; then
	wget $SPLASHIMAGEURL -O /opt/splash.jpg
fi

#Enable the splash screen service
systemctl enable splashscreen

#Set system TimeZone to user supplied
sudo raspi-config nonint do_change_timezone $timezone

#Set system Local to US and UTF-8 Encoding
sudo raspi-config nonint do_change_locale $locale

#Set keyboard layout to US
sudo raspi-config nonint do_configure_keyboard $layout

#Remove Kiosk setup from cmdline.txt
# 17DEC22 2052 - Does not work
#sudo sed -i 's| systemd.run.*||g' /boot/cmdline.txt

# Configure Reboot Button
    # Configure Reboot Overlay overlay
    # Source: https://www.stderr.nl/Blog/Hardware/RaspberryPi/PowerButton.html
    #echo "dtoverlay=gpio-shutdown,gpio_pin=4" >> /boot/config.txt

    #8JAN22 1031 - Changed to use a Python script from GitHub
    #https://github.com/fire1ce/raspberry-pi-power-button

    #Install Script
    curl https://raw.githubusercontent.com/fire1ce/raspberry-pi-power-button/main/install.sh | bash

    #Use GPIO 4 instead of 3
    sed -i 's/use_button = 3  # pin 5/use_button = 4  # pin 5/' /usr/local/bin/power_button.py

#DONE. Reboot the system
reboot now

EOF
