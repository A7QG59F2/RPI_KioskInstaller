# RPI_KioskInstaller
Originally designed for a Raspberry Pi Home Assistant Kiosk, adapted for any site-based kiosk system.

This script is a helpful setup wizard that utilizes CLI prompts to set up a touchscreen kiosk on a Raspberry Pi. 
Some of the features it has are:
- Easy to follow prompts that walk you through the process
- Internet connection issue detection
- Site validation via curl to make sure you are pointing to the right site
- Option to set up a new user on the Pi
- Text field enabled on-screen keyboard
- LightDM for minimal background processes

Instructions:

1. Grab your SD card and pop it in your PC.
2. Use the Pi Imager Application (https://www.raspberrypi.com/software/) to install Raspberry Pi Bookworm (64-bit) lite on the SD card (might be listed under "other").
3. Copy the "RPI_KioskInstaller.sh" script into "/home" for easy access.
4. Boot up your Pi with the SD card installed.
5. Once at the terminal, login and type "chmod +x /home/RPI_KioskInstaller.sh" to make it executable.
6. Next, run the script by typing "/home/RPI_KioskInstaller.sh"
7. Follow the prompts within the script to input all necessary information.
8. Sit back and relax! It will automatically reboot and start up into the site that you specified.

Notes:
The script writes two files, "/opt/kiosk/kiosk.sh" and "/lib/systemd/system/kiosk.service". If you ever need to make changes to the site address, startup user, or screen size/resolution, those files are what you will need to edit.
