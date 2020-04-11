#!/bin/bash

console() { # Passes commands to the console.
    if  screen -list | grep -q "\.$server_session"; then
        screen -S "\.$server_session" -X stuff ''"$*\n"''
    else
        exit 1
    fi
}

stopmc() {
    if screen -list | grep -q "\.$server_session"; then
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
    	stop_timeout
    else
        exit 1
    fi
}

stopproxy() {
    if screen -list | grep -q "\.$server_session"; then
        sleep "1s"
        console 'end'
        stop_timeout
    else
        exit 1
    fi
}

stop_timeout(){
        while true; do
                if screen -list | grep -q "\.$server_session"; then
                        sleep "1s"
                else
                        break
                        echo "done."
                        sleep "2s"
                fi
        done

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
            server_session="${i#*=}"
            stopmc
            exit 0
        ;;
        --stopproxy=*)
            server_session="${i#*=}"
            stopproxy
        ;;
        -h|--help)
            printf "\n ${c_green}-h,\t  --help${normal}\t\tShow this message and exit\n"
            exit 1
        ;;
    esac
    shift
done

exit 0
