#!/bin/bash

################################################ SETUP ################################################
deps=(
        jq
        whiptail
        wget
        curl
        git
        screen
        sudo
        openjdk-11-jre-headless
)

normal=$(tput sgr0)
dim=$(tput dim)
bold=$(tput bold)
uline=$(tput smul)
c_red=$(tput setaf 1)
c_green=$(tput setaf 2)
c_mag=$(tput setaf 5)

############################################## FUNCTIONS ##############################################

ARGS(){
    for i in "$@"; do
    case $i in
        --update)
            self_update
            exit 0
        ;;
        -h|--help|*)
            printf "\n ${c_green}-h,\t  --help${normal}\t\tShow this message and exit\n"
            exit 1
        ;;
    esac
    shift
done
}

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
	wget https://raw.githubusercontent.com/spacelord09/mcserver-deploy/master/deploymc.sh -O "$0"
	chmod +x "$0"
}

download_paper(){
    server_version=$(curl --silent https://papermc.io/api/v1/paper  | jq '.versions | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3)
    latest_version_tag=$(curl --silent https://papermc.io/api/v1/paper/$server_version | grep -Po '"'"latest"'"\s*:\s*"\K([^"]*)')
    wget --progress=dot --content-disposition "https://papermc.io/api/v1/paper/$server_version/latest/download" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --gauge "Downloading paper-$latest_version_tag.jar" 7 50 0
    ln -s ./paper-"$latest_version_tag".jar ./server.jar      # Create symlink to server.jar!
}

download_waterfall(){
    server_version=$(curl --silent https://papermc.io/api/v1/waterfall  | jq '.versions | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3)
    latest_version_tag=$(curl --silent https://papermc.io/api/v1/waterfall/$server_version | grep -Po '"'"latest"'"\s*:\s*"\K([^"]*)')
    wget --progress=dot --content-disposition "https://papermc.io/api/v1/waterfall/$server_version/latest/download" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --gauge "Downloading waterfall-$latest_version_tag.jar" 7 50 0
    ln -s ./waterfall-"$latest_version_tag".jar ./server.jar     # Create symlink to server.jar!
}

download(){
    server_type=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select server" --menu "What do you want to install?" 14 50 6 "Paper" "Minecraft Server" "Waterfall" "Minecraft Proxy(Bungeecord fork)" 3>&1 1>&2 2>&3)
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

systemd_install(){
    systemd_path="/etc/systemd/system/mc-$server_name.service"
    printf "[Unit]\n" > $systemd_path
    printf "Description=Minecraft Server: %s\n" "$server_name" >> $systemd_path
    printf "After=network.target\n\n" >> $systemd_path
    printf "[Service]\n" >> $systemd_path
    printf "WorkingDirectory=/opt/%s\n\n" "$user_name" >> $systemd_path
    printf "User=%s\n" "$user_name" >> $systemd_path
    printf "Group=%s\n\n" "$user_name" >> $systemd_path
    printf "Restart=always\n\n" >> $systemd_path
    printf "ExecStart=/usr/bin/screen -DmS %s /usr/bin/java -Xmx%s -jar server.jar nogui\n\n" "$server_name" "$server_ram" >> $systemd_path
    printf "ExecStop=/bin/mcstop.sh --stop=%s" "$server_name" >> $systemd_path
    printf "\n\n[Install]\n" >> $systemd_path
    printf "WantedBy=multi-user.target\n" >> $systemd_path
}

accept_eula(){
    if (whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "EULA" --yesno "Do you accept the Minecraft End User License Agreement? (https://account.mojang.com/documents/minecraft_eula)" 8 78); then
        echo "eula=true" > eula.txt
    else
        printf "\nEULA ${c_red}NOT${normal} Accepted!\n"
        sleep 2s
    fi
}

service_setup(){
    if (whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Enable service?" --yesno "Do you want to enable this service to start at boot?" 8 78); then
        systemctl enable "mc-$server_name"
    else
        printf "\nYou can enable the service anytime with: '"'%s'"'\n" "systemctl enable mc-$server_name"
        sleep 4s
    fi
    if (whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Start server($server_name)?" --defaultno --yesno "Do you want to start $server_name now?" 8 78); then
        systemctl start "mc-$server_name"
    else
        printf "\nYou can start the server anytime with: '"'%s'"'\n" "systemctl start mc-$server_name"
        sleep 4s
    fi

}

get_stop_script(){
    wget https://raw.githubusercontent.com/spacelord09/mcserver-deploy/master/mcstop.sh -O "/bin/mcstop.sh"
    chown root:root /bin/mcstop.sh
    chmod +x /bin/mcstop.sh
}

error_handler(){
	printf "\nAborting\n"
	exit 1
}

################################################ Main #################################################
trap error_handler SIGINT SIGTERM
if [ "$(whoami)" != "root" ]; then printf "This script requires root privileges\n"; exit 1; fi
ARGS "$@"
install_dependencies
clear

# Server name used for screen session
server_name=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "Please insert a server name[Screen Session name]" 8 78 "" --title "Server name" 3>&1 1>&2 2>&3)
user_name=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "Please insert a username" 8 78 mc-$server_name --title "Server user" 3>&1 1>&2 2>&3)
server_ram=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "How much RAM should the server use?" 8 78 4096M --title "RAM" 3>&1 1>&2 2>&3)

# check if username exist
if cat /etc/passwd | grep ${user_name}; then error_handler; fi

# Create user
/sbin/useradd -r -m -d /opt/$user_name $user_name
cd /opt/$user_name/

download
systemd_install
get_stop_script
accept_eula
chown -R $user_name:$user_name /opt/$user_name/
service_setup

exit 0
