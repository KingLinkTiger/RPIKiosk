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
sudo apt-get -y install --no-install-recommends xserver-xorg x11-xserver-utils xinit openbox chromium-browser fbi jq git

#Configure Openbox autostart
	#Remove default autostart file
	if [ sudo test -f /etc/xdg/openbox/autostart ]; then
		sudo rm /etc/xdg/openbox/autostart
	fi
	
	# Create the openbox folder if it does not exist
	if [ ! sudo test -f /etc/xdg/openbox ]; then
		sudo mkdir /etc/xdg/openbox
	fi
	
	#Create a new autostart with the information we want
    sudo wget -O /etc/xdg/openbox/autostart "https://raw.githubusercontent.com/KingLinkTiger/RPIKiosk/CHS/autostart"

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

#Touch Root ENV file
	if [ -f /home/pi/.config/openbox/environment ]; then
		sudo rm /home/pi/.config/openbox/environment
	fi

    if [ ! -d "/home/pi/.config/openbox" ]; then
        mkdir "/home/pi/.config/openbox"
    fi

cat > /home/pi/.config/openbox/environment << 'EOF'
export FTCEVENTSERVER_EVENTCODE=""
export FTCEVENTSERVER_IP="192.168.1.101"
expoprt KIOSKURL=""
EOF

#Copy the error.html to /home/pi
sudo wget -O /home/pi/error.html "https://raw.githubusercontent.com/KingLinkTiger/RPIKiosk/CHS/error.html"

#Set Root's password
echo -e "$ROOTPASSWORD\n$ROOTPASSWORD" | sudo passwd root

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
