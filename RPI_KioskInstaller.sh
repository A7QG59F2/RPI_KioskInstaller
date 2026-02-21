clear
echo "Welcome to the Pi Kiosk Installer!"
echo
echo "Make sure you have installed Raspberry Pi Trixie (64-bit) lite!!!"
echo "Steps/inspiration taken from 'https://pimylifeup.com/raspberry-pi-home-assistant-kiosk/'"
echo "Script made by SilentStrikerTH 12/05/25 (updated 12/06/25)"
echo

#--------------------------------- Initial Setup ---------------------------------#
setup () {

    redo=true
    while $redo
    do
        redo=false
        echo
        echo "Please enter the following information for setup"
        echo
        echo "What is the name of the service you are running?:"
        read SERVICE_NAME
        echo
        echo "Would you like $SERVICE_NAME to use your current user (${USER}) or different user?"
        select choice in "Current" "Different"
        do
            case $choice in
                "Current" ) DESIREDUSER=$USER; break;;
                "Different" ) user_creation; break;;
                *) echo "'$REPLY' is not a valid option... Exiting."; exit;;
            esac
        done
        echo "Please enter the screen width (i.e. 1920):"
        read WIDTH
        echo "Please enter the screen height (i.e. 1080):"
        read HEIGHT
        RESOLUTION="${WIDTH}x${HEIGHT}"

        while true
        do
            echo "Please enter the URL for $SERVICE_NAME (i.e. '192.168.0.1:8123' or 'home.user.com'):"
            read SITE_URL

            # Check if user should have added http/https
            if [[ "$SITE_URL" != "http"* ]]; then
                if curl --output /dev/null --silent --head "https://$SITE_URL"; then
                    SITE_URL="https://$SITE_URL"
                    echo "Successfully reached an endpoint at '$SITE_URL'!"
                    break
                elif curl --output /dev/null --silent --head "http://$SITE_URL"; then
                    SITE_URL="http://$SITE_URL"
                    echo "Successfully reached an endpoint at '$SITE_URL'!"
                    break
                fi
            fi

            # Test exactly how the user entered it
            if curl --output /dev/null --silent --head "$SITE_URL"; then
                echo "Successfully reached an endpoint at '$SITE_URL'!"
                break
            else
                echo "'$SITE_URL' does not exist or is unreachable..."
                echo "Would you like to try again or continue anyways?"
                select choice2 in "Try Again" "Continue Anyways" "Exit"
                do
                    case $choice2 in
                        "Try Again" ) continue 2;;
                        "Continue Anyways" ) break 2;;
                        "Exit" ) exit;;
                    esac
                done
            fi
        done

        echo
        echo
        echo "Would you like to setup this device as a dietpi-kiosk with the following settings?:"
        echo
        echo "Startup user: $DESIREDUSER"
        echo "Website URL: $SITE_URL"
        echo "Screen resolution: $RESOLUTION"
        echo
        select yn in "Yes" "Change Setting" "Exit"; do
            case $yn in
                Yes ) break;;
                "Change Setting" ) clear && redo=true; break;;
                Exit ) exit;;
            esac
        done
    done

}

#--------------------------------- Installation ---------------------------------#
kiosk_installation () {

    clear

    echo "Updating packages"
    sudo apt update
    sudo apt upgrade -y

    echo "Installing required packages using dietpi optimizations"
    sudo dietpi-software install 113
    echo "Installing additional necessary packages"
    sudo apt install lightdm onboard unclutter libglib2.0-bin mousetweaks gir1.2-atspi-2.0 onboard-data -y

    clear

    echo "Setting LightDM desktop as default"
    sudo systemctl --quiet set-default graphical.target

    echo "Setting resolution"
    sudo sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)display-setup-script=.*/display-setup-script=xrandr -s $RESOLUTION/"

    echo "Setting no screen timeout"
    sudo sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)xserver-command=.*/xserver-command=X -s 0 dpms/"

    echo "Auto login as $DESIREDUSER"
    sudo sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=$DESIREDUSER/"

    echo "Auto show keyboard with text field"
    sudo -u $DESIREDUSER DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $DESIREDUSER)/bus gsettings set org.onboard.auto-show enabled true

    echo "Writing kiosk script"
    sudo mkdir -p /opt/kiosk/
    sudo tee -a /opt/kiosk/kiosk.sh > /dev/null <<EOT
#!/bin/bash
gsettings set org.gnome.desktop.interface toolkit-accessibility true
/usr/bin/dbus-run-session /usr/bin/onboard &
/usr/bin/unclutter -idle 0.5 -root &
/usr/bin/chromium --app="$SITE_URL"  --noerrdialogs --disable-infobars --kiosk --window-position=0,0 --window-size=$WIDTH,$HEIGHT
EOT

    # Make the file executable
    sudo chmod +x /opt/kiosk/kiosk.sh

    echo "Writing kiosk service"
    sudo tee -a /lib/systemd/system/kiosk.service > /dev/null <<EOT
[Unit]
Description=$SERVICE_NAME Kiosk
Wants=graphical.target
After=graphical.target

[Service]
Environment=DISPLAY=:0
ExecStart=/usr/bin/dbus-run-session /usr/bin/bash /opt/kiosk/kiosk.sh
Restart=always
User=$DESIREDUSER
Group=$DESIREDUSER

[Install]
WantedBy=graphical.target
EOT

    # Start kiosk service at startup
    sudo systemctl enable kiosk

    echo "Installation complete!"
    echo "Rebooting in:"
    sleep_counter 5
    sudo reboot

}

#--------------------------------- Helpers ---------------------------------#
check_internet () {
    echo "Checking for internet connectivity..."

    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo "Internet connection detected. Continuing setup."
        return 0 # Success
    fi

    echo
    echo "NO INTERNET CONNECTION DETECTED!"
    echo

    while true; do
        echo "How would you like to proceed?"
        select choice in "Troubleshoot Ethernet" "Run raspi-config" "Skip Check and Continue"; do
            case $choice in
                "Troubleshoot Ethernet" )
                    echo
                    echo "--- Ethernet Status (Link and IP) ---"
                    ip link show eth0 | grep "state"
                    ip addr show eth0 | grep "inet"
                    echo "-------------------------------------"
                    echo "Please verify the link is UP and an IP address is assigned."
                    ;;

                "Run raspi-config" )
                    echo "On the next screen, navigate to 'System Options' -> 'Wireless LAN' or 'Network Options'."
                    echo "After you have set up internet connection, use the arrow keys to click 'Finish'"
                    read -n 1 -s -r -p "Press any key when you are ready..."
                    sudo raspi-config
                    ;;

                "Skip Check and Continue" )
                    echo "Warning: Continuing without an internet connection may lead to installation errors."
                    return 0 # Continue despite failure
                    ;;

                * )
                    echo "'$REPLY' is not a valid option."
                    continue
                    ;;
            esac

            # Re-check connection after a troubleshooting step
            echo
            echo "Re-checking internet connection..."
            if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
                echo "Internet connection successfully established. Resuming script."
                clear
                return 0
            fi
            echo "Still no internet connection. Please try another option."
        done
    done
}

user_creation () {
    while true
    do
        echo "Please enter the user on this device that will autologin and launch the kiosk:"
        read DESIREDUSER

        # Detect if user exists already
        if id -u "$DESIREDUSER" >/dev/null 2>&1; then
            echo
            echo "User '$DESIREDUSER' already exists."
            echo "Please confirm the password for '$DESIREDUSER' to proceed:"
            read -s DESIREDPASS
            echo

            # Attempt to authenticate the user
            if echo "$DESIREDPASS" | su "$DESIREDUSER" -c "echo Attempting to print command as $DESIREDUSER" 2>/dev/null; then
                echo "Password confirmed. Using existing user '$DESIREDUSER'."
                break
            else
                echo "Authentication failed. The password you entered is incorrect."
                continue
            fi
        else
            echo "Please enter the user's new password:"
            read -s DESIREDPASS
            echo

            # Create user and set password
            sudo useradd -m $DESIREDUSER
            echo "$DESIREDUSER:$DESIREDPASS" | sudo chpasswd
            echo "New user '$DESIREDUSER' created."
            break
        fi
    done
}

sleep_counter () {
    COUNT=$1
    for i in $(seq 1 $COUNT)
    do
        echo $((COUNT-i+1))
        sleep 1
    done
}

#--------------------------------- Start of Execution ---------------------------------#
check_internet
setup
kiosk_installation

