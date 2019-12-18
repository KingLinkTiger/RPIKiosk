#!/bin/bash

#Variables
SPLASHIMAGEURL="https://www.firstinspires.org/sites/default/files/uploads/resource_library/brand/first-rise/wallpaper/FIRST-RISE-wallpaper-night-programs-desktop.jpg"
PIPASSWORD=MDFTC
ROOTPASSWORD=MDFTC

KIOSKURL="http://192.168.1.25/login"

#Optional Variables
locale=en_US.UTF-8
layout=us

#--------------------------------------------
#SCRIPT BELOW
#--------------------------------------------

#Change pi Password
echo -e "$PIPASSWORD\n$PIPASSWORD" | sudo passwd pi

#Set system Local to US and UTF-8 Encoding
sudo raspi-config nonint do_change_locale $locale

#Set keyboard layout to US
sudo raspi-config nonint do_configure_keyboard $layout

#Set boot behavior to automatically log in as pi
sudo raspi-config nonint do_boot_behaviour "B2"

#Set audio to force output to 3.5mm jack
sudo raspi-config nonint do_audio "1"

#Apt-get update and upgrade
sudo apt-get update
sudo apt-get -y upgrade

#Install all of the needed apps
sudo apt-get -y install --no-install-recommends xserver-xord x11-xserver-utils xinit openbox chromium-browser fbi

#Configure Openbox autostart
	#Remove default autostart file
	sudo rm /etc/xdg/openbox/autostart
	
	#Create a new autostart with the information we want

	sudo cat <<EOT >>/etc/xdg/openbox/autostart
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
EOT

#Create .bash_profile
rm /home/pi/.bash_profile

cat <<EOT >> /home/pi/.bash_profile
[[ -z \$DISPLAY && \$XDG_VTNR -eq 1 ]] && startx -- -nocursor
EOT

if grep -Fq "disable_splash" /boot/config.txt
then
	#Disable Splash exists in file. We need to replace the line to order to ensure it's set the way we want
	sudo sed -i 's/disable_splash=.*/disable_splash=1/' /boot/config.txt
	
else
	#Disable Splash does not exist in file. Add it to the end.
	echo "disable_splash=1" >> /boot/config.txt
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

#DONE. Reboot the system
reboot now

EOF