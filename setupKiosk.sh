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
# Raspberry Pi PIN Configurations
# PIN 33/13 = FIELD 3
# PIN 35/19 = FIELD 2
# PIN 37/26 = FIELD 1
# PIN 36/16 = INSPECTIONS Status
# PIN 38/20 = PIT Display
# PIN 40/21 = Audiance
# None = None (Drops you to Event page)
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
sed -i 's/"exited_cleanly":false/"exited_cleanly":true' ~/.config/chromium/'Local State'
sed -i 's/"exited_cleanly":false/"exited_cleanly":true; s/"exit_type":"[^"]\+"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences

if [ -z "$FTCEVENTSERVER_IP" ] ; then
    FTCEVENTSERVER_IP="192.168.1.101"
fi

if [ -z "$FTCEVENTSERVER_EVENTCODE" ] ; then
    FTCEVENTSERVER_EVENTS=$(curl -s -L -X GET http://${FTCEVENTSERVER_IP}/api/v1/events)

    numFTCEVENTSERVER_EVENTS=$(echo $FTCEVENTSERVER_EVENTS | jq -r ".eventCodes" | jq length)

    if [ $numFTCEVENTSERVER_EVENTS = 1 ] ; then
        FTCEVENTSERVER_EVENTCODE=$(echo $FTCEVENTSERVER_EVENTS | jq -r ".eventCodes[]")
    else 
        KIOSKURL="http://${FTCEVENTSERVER_IP}/"
    fi
fi

if [ -z "$KIOSKURL" ] ; then
    # Pin Setup
    # https://learn.sparkfun.com/tutorials/raspberry-gpio/gpio-pinout
    # PIN 33/13 = FIELD 3
    # PIN 35/19 = FIELD 2
    # PIN 37/26 = FIELD 1
    # PIN 36/16 = INSPECTIONS Status
    # PIN 38/20 = PIT Display
    # PIN 40/21 = Audiance
    # None = None (Drops you to Event page)

    echo "26" > /sys/class/gpio/export
    echo "in" > /sys/class/gpio/gpio26/direction

    echo "19" > /sys/class/gpio/export
    echo "in" > /sys/class/gpio/gpio19/direction

    echo "13" > /sys/class/gpio/export
    echo "in" > /sys/class/gpio/gpio13/direction

    echo "21" > /sys/class/gpio/export
    echo "in" > /sys/class/gpio/gpio21/direction

    echo "20" > /sys/class/gpio/export
    echo "in" > /sys/class/gpio/gpio20/direction

    echo "16" > /sys/class/gpio/export
    echo "in" > /sys/class/gpio/gpio16/direction

    FIELD1=$(cat /sys/class/gpio/gpio26/value)
    FIELD2=$(cat /sys/class/gpio/gpio19/value)
    FIELD3=$(cat /sys/class/gpio/gpio13/value)

    PIT=$(cat /sys/class/gpio/gpio20/value)
    INSPECTIONS=$(cat /sys/class/gpio/gpio16/value)

    AUDIANCE=$(cat /sys/class/gpio/gpio21/value)

    if [ $FIELD1 = 1 ] ; then
        KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=field&bindToField=1&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=true&muteRandomizationResults=false&fieldStyleTimer=true&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=false&showMeetRankings=false&rankingsAllTeams=true"
    elif [ $FIELD2 = 1 ] ; then
        KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=field&bindToField=2&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=true&muteRandomizationResults=false&fieldStyleTimer=true&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=false&showMeetRankings=false&rankingsAllTeams=true"
    elif [ $FIELD3 = 1 ] ; then
        KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=field&bindToField=3&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=true&muteRandomizationResults=false&fieldStyleTimer=true&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=false&showMeetRankings=false&rankingsAllTeams=true"
    elif [ $PIT = 1 ] ; then
        KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=pit&bindToField=all&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=false&muteRandomizationResults=false&fieldStyleTimer=false&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=true&showMeetRankings=false&rankingsAllTeams=true"
    elif [ $INSPECTIONS = 1 ] ; then
        KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/status/proj/3/"
    elif [ $AUDIANCE = 1 ] ; then
        KIOSKURL="http://${FTCEVENTSERVER_IP}/event/${FTCEVENTSERVER_EVENTCODE}/display/?type=audience&bindToField=all&scoringBarLocation=bottom&allianceOrientation=standard&liveScores=true&mute=true&muteRandomizationResults=false&fieldStyleTimer=false&overlay=false&overlayColor=%2300FF00&allianceSelectionStyle=classic&awardsStyle=overlay&previewStyle=overlay&randomStyle=overlay&dualDivisionRankingStyle=sideBySide&rankingsFontSize=larger&rankingsShowQR=false&showMeetRankings=false&rankingsAllTeams=true"
    else
        KIOSKURL="http://${FTCEVENTSERVER_IP}/"
    fi

    echo "26" > /sys/class/gpio/unexport
    echo "19" > /sys/class/gpio/unexport
    echo "13" > /sys/class/gpio/unexport
    echo "21" > /sys/class/gpio/unexport
    echo "20" > /sys/class/gpio/unexport
    echo "16" > /sys/class/gpio/unexport
fi

#Debugging
#echo "$(date) : FIELD1 = $FIELD1" >> /home/pi/openbox.log
#echo "$(date) : FIELD2 = $FIELD2" >> /home/pi/openbox.log
#echo "$(date) : FIELD3 = $FIELD3" >> /home/pi/openbox.log
#echo "$(date) : PIT = $PIT" >> /home/pi/openbox.log
#echo "$(date) : INSPECTIONS = $INSPECTIONS" >> /home/pi/openbox.log
#echo "$(date) : AUDIANCE = $AUDIANCE" >> /home/pi/openbox.log
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

# Configure Boort overlay
# Source: https://www.stderr.nl/Blog/Hardware/RaspberryPi/PowerButton.html
echo "dtoverlay=gpio-shutdown,gpio_pin=3" >> /boot/config.txt

#DONE. Reboot the system
reboot now

EOF
