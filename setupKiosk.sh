#!/bin/bash

#
# How to run: wget -O - "https://raw.githubusercontent.com/KingLinkTiger/RPIKiosk/MTI/setupKiosk.sh" | bash
# On EN GB Keyboard:
#	- Right Alt + Shift + ~ Key = |
#	- Shift + 2 = “
#
#	Intall Time: Roughly 22 Minuites
#


#Variables
SPLASHIMAGEURL="https://info.firstinspires.org/hubfs/2022%20Season%20Assets/free-season-assets/first%20forward/firstforward-wallpaper-desktop-3.png"
PIPASSWORD=MTI
ROOTPASSWORD=MTI

KIOSKURL="http://192.168.1.25/login"

#Optional Variables
locale=en_US.UTF-8
layout=us
timezone='US/Eastern'
resolutionGroup=2
resolutionMode=82

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
sudo apt-get -y install --no-install-recommends xserver-xorg x11-xserver-utils xinit openbox chromium-browser fbi

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
chromium-browser --disable-infobars --kiosk '$KIOSKURL'
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

#Set Resolution
#sudo raspi-config nonint do_resolution $resolutionGroup $resolutionMode

#DONE. Reboot the system
reboot now

EOF
