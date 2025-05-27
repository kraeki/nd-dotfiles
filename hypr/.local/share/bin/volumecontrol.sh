#!/usr/bin/env sh

scrDir=`dirname "$(realpath "$0")"`
source $scrDir/globalcontrol.sh


# define functions

print_error ()
{
cat << "EOF"
    ./volumecontrol.sh -[device] <actions>
    ...valid device are...
        i   -- input decive
        o   -- output device
        p   -- player application
    ...valid actions are...
        i   -- increase volume [+5]
        d   -- decrease volume [-5]
        m   -- mute [x]
EOF
exit 1
}

notify_vol ()
{
    vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}')
    vol_percent=$(echo "$vol_raw * 100" | bc -l | awk '{printf "%.0f", $1}')
    vol_rounded_to_5=$(( (vol_percent + 2) / 5 * 5 ))
    ico="${icodir}/vol-${vol_rounded_to_5}.svg"
    notify-send  -a "t2" -r 91190 -t 800 -i "${ico}" "${vol_percent}" "${nsink}"
}

notify_mute () {
    if [ "$srce" == "input" ]; then
        device="@DEFAULT_AUDIO_SOURCE@"
        dvce="mic"
    else
        device="@DEFAULT_AUDIO_SINK@"
        dvce="speaker"
    fi

    if wpctl get-volume "$device" | grep -q MUTED; then
        notify-send -a "t2" -r 91190 -t 800 -i "${icodir}/muted-${dvce}.svg" "muted" "${nsink}"
    else
        notify-send -a "t2" -r 91190 -t 800 -i "${icodir}/unmuted-${dvce}.svg" "unmuted" "${nsink}"
    fi
}

# Parse device options: -i for input, -o for output, -p for player
while getopts "iop:" opt; do
  case "$opt" in
    i)  # Input (microphone)
	nsink_id=$(pw-dump | jq -r '.[] | select(.type=="PipeWire:Interface:Metadata") | .metadata[]? | select(.key | contains("default.audio.source")) | .value.name')
	nsink=$(pw-dump | jq --arg sink "$nsink_id" '.[] | select(.info.props."node.name"==$sink) | .info.props."node.description"')
        if [[ -z "$nsink" ]]; then
          echo "ERROR: Input device not found..."
          exit 1
        fi
        ctrl="wpctl"
        srce="input"
        ;;
    o)  # Output (speakers/headphones)
	nsink_id=$(pw-dump | jq -r '.[] | select(.type=="PipeWire:Interface:Metadata") | .metadata[]? | select(.key | contains("default.audio.sink")) | .value.name')
	nsink=$(pw-dump | jq --arg sink "$nsink_id" '.[] | select(.info.props."node.name"==$sink) | .info.props."node.description"')
        if [[ -z "$nsink" ]]; then
          echo "ERROR: Output device not found..."
          exit 1
        fi
        ctrl="wpctl"
        srce="output"
        ;;
    p)  # Player (media app)
        nsink=$(playerctl -l | grep -w "$OPTARG")
        if [[ -z "$nsink" ]]; then
          echo "ERROR: Player '$OPTARG' not active..."
          exit 1
        fi
        ctrl="playerctl"
        srce="player"
        ;;
    *)
        echo "Usage: $0 [-i] [-o] [-p playername]"
        exit 1
        ;;
  esac
done

# set default variables

icodir="${confDir}/dunst/icons/vol"
shift $((OPTIND -1))
step="${2:-5}"


# execute action

case "${1}" in
    i) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ ;;
    d) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
    m) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && notify_mute && exit 0 ;;
    *) print_error ;;
esac

notify_vol
