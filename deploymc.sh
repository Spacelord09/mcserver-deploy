#!/bin/bash

################################################ SETUP ################################################
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
        openjdk-11-jre-headless
)

deps_webhook=(
        nginx
        fcgiwrap
)

git_ignore_content=(
        ".bash_logout"
        ".bash_history"
        ".bashrc"
        ".profile"
        ".selected_editor"
        ".wget-hsts"
        ".gitconfig"
        ".ssh/"
        ".config/"
        ".local/"
        "pid"
        "*.swp"
        "mcdeploy.log"
)

git_ignore_content_mc=(
        "logs/*.log"
        "cache/"
        "usercache.json"
        "world/"
        "world_nether/"
        "world_the_end/"
        "plugins/ProtocolLib/lastupdate"
        "plugins/Essentials/userdata/*"
)

git_ignore_content_proxy=(
        "logs/*.log"
        "locations.yml"
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

install_dependencies_webhook(){
	for dependency in ${deps_webhook[@]}; do
		if [ "$(dpkg-query -W -f='${Status}' "$dependency" 2>/dev/null | grep -c "ok installed")" -eq 0 ]; then
			printf "Installing %s\n" "$dependency"
			apt-get install -y $dependency
		else
			printf "%s already installed!\n" "$dependency"
		fi
	done
	printf "\n"
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
    server_version=$(curl --silent https://papermc.io/api/v1/paper  | jq '.versions | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3) || error_handler
    latest_version_tag=$(curl --silent https://papermc.io/api/v1/paper/$server_version | jq -r .builds.latest)
    wget --progress=dot --content-disposition "https://papermc.io/api/v1/paper/$server_version/latest/download" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --gauge "Downloading paper-$latest_version_tag.jar" 7 50 0 || error_handler
    ln -s ./paper-"$latest_version_tag".jar ./server.jar      # Create symlink to server.jar!
}

download_waterfall(){
    server_version=$(curl --silent https://papermc.io/api/v1/waterfall  | jq '.versions | map(., "") |. []' | xargs whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select your server version" --noitem --menu "choose" 16 78 10 3>&1 1>&2 2>&3) || error_handler
    latest_version_tag=$(curl --silent https://papermc.io/api/v1/waterfall/$server_version | jq -r .builds.latest)
    wget --progress=dot --content-disposition "https://papermc.io/api/v1/waterfall/$server_version/latest/download" 2>&1 | sed -u '1,/^$/d;s/.* \([0-9]\+\)% .*/\1/' | whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --gauge "Downloading waterfall-$latest_version_tag.jar" 7 50 0 || error_handler
    ln -s ./waterfall-"$latest_version_tag".jar ./server.jar     # Create symlink to server.jar!
}

download(){
    server_type=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Select server" --menu "What do you want to install?" 14 50 6 "Paper" "Minecraft Server" "Waterfall" "Minecraft Proxy(Bungeecord fork)" 3>&1 1>&2 2>&3) || error_handler
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
    [ "$server_type" = "Paper" ] && printf "ExecStop=/bin/mcstop.sh --stop=%s" "$server_name" >> $systemd_path
    [ "$server_type" = "Waterfall" ] && printf "ExecStop=/bin/mcstop.sh --stopproxy=%s" "$server_name" >> $systemd_path
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

nginx-setup(){
    nginx_server_cfg="/etc/nginx/sites-available/webhooks.conf"
    [ -h "/etc/nginx/sites-enabled/default" ] && unlink "/etc/nginx/sites-enabled/default"
    if [ -e "$nginx_server_cfg" ]; then
        IPADDR=$(cat $nginx_server_cfg | grep server_name | sed 's/\ \ \ \ \ server_name //' | sed 's/\;//')
        write_nginx_webhook_cfg
        write_webhook_script
    else
        ask_network_interface
        write_nginx_server_cfg
        write_nginx_webhook_cfg
        write_webhook_script
    fi
}

ask_network_interface(){
        DISPLAY=()
        INTERFACES=$(ip l | grep -E '[a-z].*: ' | cut -d ':' -f2 | cut -d ' ' -f2)
        set $INTERFACES
        for i in $@; do IP=$(ip a | grep -E "$i$" | cut -d ' ' -f6); DISPLAY+=("$i" "$IP"); done
        IFACE=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Interface selection" --menu "On which interface should the Webhook listen?\n [Probably your internal network!]" 15 60 4 "${DISPLAY[@]}" 3>&1 1>&2 2>&3) || error_handler
        IPADDR=$(ip address show $IFACE | awk '/inet /{print substr($2,1)}' | sed 's/\/.*//')
}

write_nginx_server_cfg(){
    mkdir -p /etc/nginx/sites-available/      # Create webhook dir
cat <<EOF > "$nginx_server_cfg"
server {
     listen 80;
     listen [::]:80;
     server_name $IPADDR;

     root /var/www/hooks;

     include webhooks/update-*.conf;
}
EOF
    ln -s $nginx_server_cfg /etc/nginx/sites-enabled/webhooks.conf     # Enable config!
    service nginx restart
}

write_nginx_webhook_cfg(){
    mkdir -p /etc/nginx/webhooks/      # Create webhook dir
    nginx_webhook_cfg="/etc/nginx/webhooks/update-${server_name}.conf"
cat <<EOF > "$nginx_webhook_cfg"
     location /hook/update/$server_name {
        fastcgi_pass unix:/var/run/fcgiwrap.socket;
        include /etc/nginx/fastcgi_params;
        fastcgi_param DOCUMENT_ROOT /var/www/hooks;
        fastcgi_param SCRIPT_FILENAME /var/www/hooks/update-${server_name};
     }
EOF
    service nginx restart
}

write_webhook_script(){
    mkdir -p /var/www/hooks
    webhook_script="/var/www/hooks/update-$server_name"
cat <<EOF > "$webhook_script"
#!/bin/bash

printf "Content-type:application/json\r\n\r\n"

printf "%s: %s\r\n" "\$(date)" "\$(whoami)" >> /var/www/hooks/update-${server_name}.log
cat >> /var/www/hooks/update-${server_name}.log

cd $home_dir

sudo -u $user_name git pull origin --recurse-submodules 2>&1
sudo -u $user_name git checkout master 2>&1

printf "ok"
EOF
    chmod +x $webhook_script
    chown -R www-data:www-data /var/www/hooks/
    printf "www-data     ALL=(ALL) NOPASSWD:ALL\n" > /etc/sudoers.d/webhook  # Add sudo permissons

}

write_update_script(){
cat <<EOF > $home_dir/git-update.sh
#!/bin/bash
cd $home_dir

git reset
git add .
git commit -am "updated on - \$(date)"
git push
git reset
EOF
chmod +x $home_dir/git-update.sh
}

add-git-ignore(){
    cd $home_dir

    for i in "${git_ignore_content[@]}"; do
        grep "$i" $home_dir/.gitignore || printf "%s\n" "$i" >> $home_dir/.gitignore
    done

    if [ "$server_type" = "Paper" ]; then

        printf "\n# Generated by mcserver-deploy\n" >> $home_dir/.gitignore

        for i in "${git_ignore_content_mc[@]}"; do
            grep "$i" $home_dir/.gitignore || printf "%s\n" "$i" >> $home_dir/.gitignore
        done

        printf "# END mcserver-deploy\n\n" >> $home_dir/.gitignore

    elif [ "$server_type" = "Waterfall" ]; then

        printf "\n# Generated by mcserver-deploy\n" >> $home_dir/.gitignore

        for i in "${git_ignore_content_proxy[@]}"; do
            grep "$i" $home_dir/.gitignore || printf "%s\n" "$i" >> $home_dir/.gitignore
        done

        printf "# END mcserver-deploy\n\n" >> $home_dir/.gitignore
    fi

    if (whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Edit .gitignore?" --yesno "Do you want to edit the '.gitignore' ?\n[NOTE: A preset for ’$server_type’ was added to the '.gitignore']" 8 78); then
        var_editor=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Editor" --menu "Choose an option" 10 30 2 "Nano" "" "Vim" "" 3>&1 1>&2 2>&3)

        if [ "$var_editor" = "Nano" ]; then
            nano $home_dir/.gitignore
        elif [ "$var_editor" = "Vim" ]; then
            vim $home_dir/.gitignore
        fi

    fi

}

deploy_setup(){
    sudo -u $user_name mkdir $home_dir/.ssh
    sudo -u $user_name ssh-keygen -b 8192 -t rsa -f $home_dir/.ssh/id_rsa -q -P ""
    sudo -u $user_name git config --global  user.name "$user_name"
    git_email=(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "Please insert a valid email address" 8 78 "noreply@diacraft.net" --title "GIT Mail Address")
    sudo -u $user_name git config --global user.email "$git_email"
}

show_data(){
    clear
    printf "Please insert the following ssh public key in your git repository as deploy-key${c_red}[Read+Write!]${normal}\n\n"
    cat $home_dir/.ssh/id_rsa.pub
    printf "\n${dim}Webhook URL: ’${normal}${c_cyan}http://%s/hook/update/%s${normal}${dim}’${normal}\n\n" "$IPADDR" "$server_name"
    printf "To automatically push changes add the following to the user crontab.\n${dim}’${normal}${c_cyan}* * * * * %s/git-update.sh${normal}${dim}’${normal}\n" "$home_dir"
    printf "\n${dim}You can view this data at ’%s/mcdeploy.log’\n${normal}" "$home_dir"

    # Write mcdeploy.log
    printf "SSH deploy-key [Read+Write access required!]\n\n" > $home_dir/mcdeploy.log
    cat $home_dir/.ssh/id_rsa.pub >> $home_dir/mcdeploy.log
    printf "\nWebhook URL: ’http://%s/hook/update/%s’\n\n" "$IPADDR" "$server_name" >> $home_dir/mcdeploy.log
    printf "To automatically push changes add the following to %s´s crontab.\n’* * * * * %s/git-update.sh’\n" "$user_name" "$home_dir" >> $home_dir/mcdeploy.log

    read -p "Press enter to exit.."

}

error_handler(){
    printf "\nAborting"
    for i in {1..3}; do sleep 0.3s && printf "." && sleep 0.3s; done
    printf "\n"
    exit 1
}

################################################ Main #################################################
trap error_handler SIGINT SIGTERM
if [ "$(whoami)" != "root" ]; then printf "This script requires root privileges\n"; exit 1; fi
ARGS "$@"
install_dependencies
clear

# Server name used for screen session
server_name=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord.de>" --inputbox "Please insert a server name[Screen Session name]" 8 78 "" --title "Server name" 3>&1 1>&2 2>&3) || error_handler
user_name=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "Please insert a username" 8 78 mc-$server_name --title "Server user" 3>&1 1>&2 2>&3) || error_handler
# check if username exist
if cat /etc/passwd | grep $user_name; then error_handler; fi
server_ram=$(whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --inputbox "How much RAM should the server use?" 8 78 4096M --title "RAM" 3>&1 1>&2 2>&3) || error_handler

# Create user
/sbin/useradd -r -m -d /opt/$user_name $user_name
home_dir="/opt/$user_name"
cd $home_dir

download
systemd_install
get_stop_script
[ "$server_type" = "Paper" ] && accept_eula
chown -R $user_name:$user_name /opt/$user_name/
service_setup

if (whiptail --backtitle "mcdeploy by. Spacelord <admin@spacelord09.de>" --title "Install Webhook?" --defaultno --yesno "Do you want to install a webhook to automatically update a git repository?" 8 78); then
    nginx_install="1"
    install_dependencies_webhook
    nginx-setup
fi

[ "$nginx_install" = "1" ] && deploy_setup    # SSH key generation and setup
[ "$nginx_install" = "1" ] && add-git-ignore
[ "$nginx_install" = "1" ] && write_update_script
chown -R $user_name:$user_name /opt/$user_name/

[ "$nginx_install" = "1" ] && show_data

chown -R $user_name:$user_name /opt/$user_name/

exit 0
