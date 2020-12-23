#!/bin/bash

normal=$(tput sgr0)
dim=$(tput dim)
bold=$(tput bold)
uline=$(tput smul)
c_red=$(tput setaf 1)
c_green=$(tput setaf 2)
c_mag=$(tput setaf 5)

deps=(
        jq
        whiptail
        wget
        curl
        git
        screen
        htop
        vim
        sudo
)

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
        wget https://raw.githubusercontent.com/spacelord09/mcserver-deploy/master/deploymc-updater.sh -O "$0"
        chmod +x "$0"
}

download(){
    server_version=$(curl --silent https://papermc.io/api/v1/$server_type  | jq '.versions | map(., "") |. []' | xargs whiptail --backtitle "deploymc-updater by. Spacelord <admin@spacelord09.de>" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3) || error_handler "Whiptail exited with code 1 (Probably terminated by the user)"
    latest_version_tag=$(curl --silent https://papermc.io/api/v1/$server_type/$server_version | jq '.builds.latest')
    wget --progress=dot --content-disposition "https://papermc.io/api/v1/$server_type/$server_version/latest/download" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "deploymc-updater by. Spacelord <admin@spacelord09.de>" --gauge "Downloading $server_type-$latest_version_tag.jar" 7 50 0 || error_handler "Whiptail exited with code 1 (Probably terminated by the user)"
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

# Check if started with the root user.
if [ "$(whoami)" != "root" ]; then printf "This script requires root privileges\n"; error_handler; fi
ARGS "$@"

# Install dependencies.
install_dependencies

# server.jar (symlink) selector.
file_list=(ls -d /opt/*/server.jar)
file_list=("${file_list[@]:2}")

# Build Array for whiptail with realpath as description.
for i in "${file_list[@]}"; do
    file_array+=("$i")
    temp=$(realpath "$i")
    file_array+=("  [$temp]")
    unset "temp"
done

# Ask the user for the symlink to use its path to upgrade the version.
server_symlink=$(whiptail --backtitle "deploymc-updater by. Spacelord <admin@spacelord09.de>" --title "Menu" --menu "Choose an option" 00 00 00 "${file_array[@]}" 3>&1 1>&2 2>&3) || error_handler "Whiptail exited with code 1 (Probably terminated by the user)"
# Resolve symlink to get its path
server_realpath=$(realpath "$server_symlink")


# Changing directory to servers directory.
cd `dirname "$server_realpath"` || error_handler "Failed to change directory!"

# Unlinking symlink [server.jar]
unlink $server_symlink

# Get user from realpath
user_name=$(stat -c '%U' "$server_realpath") || error_handler "Failed to get file owner!"

# Check if the server type can be determined automatically (*aper*/*aterfall*). Otherwise ask for the type. Then start the coresponding update function.
case "$server_realpath" in
    *aper*)
        server_type=paper
    ;;
    *aterfall*)
        server_type=waterfall
    ;;
    *)
        server_type=$(whiptail --backtitle "deploymc-updater by. Spacelord <admin@spacelord09.de>" --title "Select server type" --menu "What do you want to upgrade?\n[ATTENTION: No Paper or Waterfall installation was detected!]" 00 00 00 "paper" "Minecraft Server" "waterfall" "Minecraft Proxy(Bungeecord fork)" 3>&1 1>&2 2>&3) || error_handler "Whiptail exited with code 1 (Probably terminated by the user)"
    ;;
    esac
    printf "\n"

download

# Removing .oldversion files
rm -f *.oldversion

# Add .oldversion prefix to the oldversion
mv "$server_realpath" "$server_realpath".oldversion

# Create symlink to server.jar!
ln -s ./"$server_type"-"$latest_version_tag".jar ./server.jar

# Set file owner
chown -R $user_name:$user_name ./

exit 0