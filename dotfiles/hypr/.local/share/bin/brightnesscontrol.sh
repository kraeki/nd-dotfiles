#!/usr/bin/env sh

scrDir=`dirname "$(realpath "$0")"`

function print_error
{
cat << "EOF"
    ./brightnesscontrol.sh <action>
    ...valid actions are...
        i -- <i>ncrease brightness [+5%]
        d -- <d>ecrease brightness [-5%]
EOF
}

# The quickshell OSD shows the new level; sysfs backlight changes raise no
# inotify event, so it has to be told. Silent if the shell is not running.
function send_notification {
    qs ipc call osd brightness >/dev/null 2>&1 || true
}

function get_brightness {
    brightnessctl -m | grep -o '[0-9]\+%' | head -c-2
}

case $1 in
i)  # increase the backlight
    if [[ $(get_brightness) -lt 10 ]] ; then
        # increase the backlight by 1% if less than 10%
        brightnessctl set +1%
    else
        # increase the backlight by 5% otherwise
        brightnessctl set +5%
    fi
    send_notification ;;
d)  # decrease the backlight
    if [[ $(get_brightness) -le 1 ]] ; then
        # avoid 0% brightness
        brightnessctl set 1%
    elif [[ $(get_brightness) -le 10 ]] ; then
        # decrease the backlight by 1% if less than 10%
        brightnessctl set 1%-
    else
        # decrease the backlight by 5% otherwise
        brightnessctl set 5%-
    fi
    send_notification ;;
*)  # print error
    print_error ;;
esac

