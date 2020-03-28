#!/bin/bash

normal=$(tput sgr0)
dim=$(tput dim)
bold=$(tput bold)
uline=$(tput smul)
c_red=$(tput setaf 1)
c_green=$(tput setaf 2)
c_mag=$(tput setaf 5)

console() { # Passes commands to the console.
    if  screen -list | grep -q "$server_session"; then
        screen -S "$server_session" -X stuff ''"$*\n"''
    else
        exit 1
    fi
}

stop() {
    if screen -list | grep -q "$server_session"; then
        console 'save-all'  # Save worlds.
        sleep "1s"
        console 'title @a actionbar {"text":"Server shutdown in '30's!","color":"dark_red"}'
        sleep 20s

        for i in {10..1}
        do
         console 'title @a actionbar {"text":"Server shutdown in '$i's","color":"gold"}'
         sleep 1s
        done

        sleep 0.5s
        console 'title @a actionbar {"text":"Shutdown NOW!","color":"dark_red"}'
        console 'stop'
    else
        exit 1
    fi
}

# Updates this script from the remote repository.
self_update(){
    if [ "$(whoami)" != "root" ]; then printf "This script requires root privileges\n"; exit 1; fi
	wget https://raw.githubusercontent.com/spacelord09/mcserver-deploy/master/mcstop.sh -O "$0"
	chmod +x "$0"
}


for i in "$@"; do
    case $i in
        --update)
            self_update
            exit 0
        ;;
        --stop=*)
            screen_session="${i#*=}"
            stop
            exit 0
        ;;
        -h|--help)
            printf "\n ${c_green}-h,\t  --help${normal}\t\tShow this message and exit\n"
            exit 1
        ;;
    esac
    shift
done

exit 0
