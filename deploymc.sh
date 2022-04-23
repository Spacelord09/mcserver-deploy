#!/bin/bash
# shellcheck disable=SC2120,SC2059,SC2164,SC2034

################################################ SETUP ################################################
deps=(
	jq
	whiptail
	wget
	curl
	screen
	vim
	nano
	openjdk-17-jre-headless
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
		-u|--update)
			self_update
			exit 0
		;;
		-h|--help|*)
			printf "\n ${c_green}-h,\t  --help${normal}\t\tShow this message and exit\n"
			exit 0
		;;
		esac
	shift
done
}

install_dependencies(){
	for dependency in "${deps[@]}"; do
		if [ "$(dpkg-query -W -f='${Status}' "$dependency" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
			printf "Installing %s\n" "$dependency"
			apt-get install -y "$dependency"
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

exec_download(){
	# If needed, all projects can be retrieved via the api. Currently, this is done statically below.
	#server_project=$(curl --silent https://papermc.io/api/v2/projects  | jq '.projects | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "What do you want to install?" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3) || error_handler
	server_version=$(curl --silent https://papermc.io/api/v2/projects/${server_project,,}  | jq '.versions | reverse | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3) || error_handler
	server_version_tag=$(curl --silent https://papermc.io/api/v2/projects/${server_project,,}/versions/$server_version | jq -r '.builds | last')
	server_version_name=$(curl --silent https://papermc.io/api/v2/projects/${server_project,,}/versions/$server_version/builds/$server_version_tag | jq -r '.downloads.application.name')
	wget --progress=dot --content-disposition "https://papermc.io/api/v2/projects/${server_project,,}/versions/$server_version/builds/$server_version_tag/downloads/$server_version_name" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --gauge "Downloading $server_version_name" 7 50 0 || error_handler
	ln -s "./$server_version_name" "./server.jar"      # Create symlink to server.jar!
}

download(){
	server_project=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select server" --menu "What do you want to install?" 14 50 6 "Paper" "Minecraft Server" "Waterfall" "Minecraft Proxy(Bungeecord fork)" 3>&1 1>&2 2>&3) || error_handler
	case "$server_project" in
	Paper)
		exec_download
	;;
	Waterfall)
		exec_download
	;;
	*)
		error_handler "$server_project is currenty not supported."
	;;
	esac
	printf "\n"
}

# TODO: Refactor
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
	[ "$server_project" = "Paper" ] && printf "ExecStop=/bin/mcstop.sh --stop=%s" "$server_name" >> $systemd_path
	[ "$server_project" = "Waterfall" ] && printf "ExecStop=/bin/mcstop.sh --stopproxy=%s" "$server_name" >> $systemd_path
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
	[[ -n $1 ]] && printf "\n%s\n" "$1"
	printf "\nAborting"
	for i in {1..3}; do sleep 0.1s && printf "." && sleep 0.3s; done
	printf "\n"
	exit "1"
}

################################################ Main #################################################
trap error_handler SIGINT SIGTERM
if [ "$(whoami)" != "root" ]; then printf "This script requires root privileges\n"; exit 1; fi
ARGS "$@"
install_dependencies
clear

# Server name used for screen session
server_name=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord.de>" --inputbox "Please insert a server name[Please do NOT add a prefix like \"mc-\"!]" 8 78 "" --title "Server name" 3>&1 1>&2 2>&3) || error_handler
user_name=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "Please insert a username" 8 78 mc-$server_name --title "Server user" 3>&1 1>&2 2>&3) || error_handler


# TODO: Test!
# check if username exist, and ask to reuse.
if grep "$user_name" "/etc/passwd"; then
	if ! (whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "User collision" --yesno "The user $user_name already exists! Do you want to use it anyways?" 8 78); then
		error_handler "as requested"
	fi
	mkdir "/opt/$user_name"
fi
server_ram=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "How much RAM should the server use?" 8 78 4096M --title "RAM" 3>&1 1>&2 2>&3) || error_handler

# Create user
/sbin/useradd -r -m -d "/opt/$user_name" "$user_name"
home_dir="/opt/$user_name"
cd "$home_dir"

download
systemd_install
get_stop_script

[ "$server_project" = "Paper" ] && accept_eula

service_setup

chown -R "$user_name:$user_name" "/opt/$user_name/"

exit 0
