#!/usr/bin/env bash

read -p "Starting Nvidia Driver Install for Fedora... Have you updated and restarted your workstation [y/N]? " REBOOT_STATUS

REBOOT_STATUS_NORM="${REBOOT_STATUS,,}"

if [[ "$REBOOT_STATUS_NORM" == "y" || "$REBOOT_STATUS_NORM" == "yes" ]]; then
	echo "Great continuing on then..."
	#Adding rpm fusion repos
	sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                   https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
	#Installing tools for signing
	sudo dnf install -y akmods mokutil openssl
	
	#Creating the key
	if [ ! -f /etc/pki/akmods/certs/public_key.der ]; then
		echo "Generating signing key..."
		sudo kmodgenca -a
		echo "Key created... You are about to set a 'MOK Enrollment' password. Do something simple like 1111"
		sudo mokutil --import /etc/pki/akmods/certs/public_key.der
	else
		echo "Signing Key already exists"
	fi
	
	#Install & Build	
	sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda	

	echo "Building kernal Modules... DO NOT REBOOT YOUR MACHINE"
	echo "This can take several minutes so be patient"
	until modinfo -F version nvidia &>/dev/null; do 
		echo -n "."
		sleep 5
	done
	echo "Kernel module built successfully"

echo "Drivers installed and signed!"
echo "REBOOT NOW. You will see a blue 'MOK Management' screen."
echo "1. Select 'Enroll MOK'"
echo "2. Select 'Continue'"
echo "3. Select 'Yes'"
echo "4. Enter the password you just created."
echo "5. Reboot again."

else
	read -p "Would you like to restart this machine now [y/N]? " REBOOT_NOW
	REBOOT_NOW_NORM="${REBOOT_NOW,,}"
	if [[ "$REBOOT_NOW_NORM" == "y" || "$REBOOT_NOW_NORM" == "yes" ]]; then
		echo "Shutting down machine now..."
		reboot
	else
		echo "Please make sure you run 'sudo dnf update && dnf upgrade -y' and restart your system before running this script"
	fi
fi
	
