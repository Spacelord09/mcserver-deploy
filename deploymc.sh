#!/bin/bash

printf "\nWORK IN PROGRESS\nDO NOT RUN\n\n"
exit 0

################################################ SETUP ################################################
deps=(
        jq
        whiptail
        wget
        curl
        git
        screen
)

user=$(whoami)                  # for bypassing user check replace "$(whoami)" with "root".


normal=$(tput sgr0)
dim=$(tput dim)
bold=$(tput bold)
uline=$(tput smul)
c_red=$(tput setaf 1)
c_green=$(tput setaf 2)
c_mag=$(tput setaf 5)

############################################## FUNCTIONS ##############################################

install_dependencies(){
	for dependency in ${deps[@]}; do
		if [ "$(dpkg-query -W -f='${Status}' "$dependency" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
			printf "Installing %s\n" "$dependency"
			apt-get install -y $dependency
		else
			printf "%s already installed!\n" "$dependency"
		fi
	done
	printf "\n"
}

# Updates this script from the remote repository.
self_update(){
    if [ "$(whoami)" != "root" ]; then printf "The installer/updater requires root privileges to install the midimonster system-wide\n"; exit 1; fi
    printf "\nDOWNLOAD UPDATE!\n\n"
	wget https://raw.githubusercontent.com/spacelord09/mcserver-deploy/master/deploymc.sh -O "$0"
	chmod +x "$0"
}

download_paper(){
    server_version=$(curl --silent https://papermc.io/api/v1/paper  | jq '.versions | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3)
    latest_version_tag=$(curl --silent https://papermc.io/api/v1/paper/$server_version | grep -Po '"'"latest"'"\s*:\s*"\K([^"]*)')
#    echo "$latest_version_tag"     # DEBUG
    wget --progress=dot --content-disposition "https://papermc.io/api/v1/paper/$server_version/latest/download" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "mcdeploy by. Spacelord" --gauge "Downloading paper-$latest_version_tag.jar" 7 50 0
    ln -s ./paper-$latest_version.jar ./server.jar      # Create symlink to server.jar!
}

download_waterfall(){
    server_version=$(curl --silent https://papermc.io/api/v1/waterfall  | jq '.versions | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3)
    latest_version_tag=$(curl --silent https://papermc.io/api/v1/waterfall/$server_version | grep -Po '"'"latest"'"\s*:\s*"\K([^"]*)')
#    echo "$latest_version_tag"     # DEBUG
    wget --progress=dot --content-disposition "https://papermc.io/api/v1/waterfall/$server_version/latest/download" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "mcdeploy by. Spacelord" --gauge "Downloading waterfall-$latest_version_tag.jar" 7 50 0
    ln -s ./waterfall-$latest_version.jar ./server.jar     # Create symlink to server.jar!
}

download(){
    server_type=$(whiptail --backtitle "mcdeploy by. Spacelord" --title "Select server" --menu "What do you want to install?" 14 50 6 "Paper" "Minecraft Server" "Waterfall" "Minecraft Proxy(Bungeecord fork)" 3>&1 1>&2 2>&3)
    case "$server_type" in
        Paper)
            download_paper
        ;;
        Waterfall)
            download_waterfall
        ;;
        *)
            error_handler
        ;;
        esac
        printf "\n"
}



error_handler(){
	printf "\nAborting\n"
	exit 1
}

################################################ Main #################################################
trap error_handler SIGINT SIGTERM
install_dependencies
#clear

# Server name used for screen session
server_name=$(whiptail --backtitle "mcdeploy by. Spacelord" --inputbox "Please insert a server name" 8 78 "" --title "Server name" 3>&1 1>&2 2>&3)
user_name=$(whiptail --backtitle "mcdeploy by. Spacelord" --inputbox "Please insert a username" 8 78 mc-$server_name --title "Server user" 3>&1 1>&2 2>&3)

printf "User: %s\nServername: %s\n" "$user_name" "$server_name"

# Create user
/sbin/useradd -r -m -d /opt/$var_user $var_user
cd /opt/$user_name/ 

download
exit 0