#!/bin/bash
# dzen2 status script
# invoke: status.sh | dzen2 -ta r
#

base_ival=1
# update interval array
#  date/time--+    weather--+
#             |             |
#            --           ---
ival=(30 3 2 30 3 3 3 300 600)
#     -- - -    - - - ---
#     |  | |    | | | +--gmail
#     |  | |    | | +--free mem
#     |  | |    | +--essid
#     |  | |    +--disk usage
#     |  | +--cpu usage
#     |  +--cpu temp
#     +--battery
count=(${ival[@]})

# displays time left until battery is empty (if not plugged in) or fully charged
# (if plugged in and not full). alternately displays "full" or "no battery" if
# said conditions exist.
bat() {
  if [ ! -d /sys/class/power_supply/BAT0 ]; then
    printf "no battery"
  else
    awk -F'=' '{
      power[$1]=$2
    } END {
      if ( power["POWER_SUPPLY_STATUS"] == "Full" )
        print "full"
      else {
        if ( power["POWER_SUPPLY_STATUS"] == "Discharging" ) {
          hh=power["POWER_SUPPLY_CHARGE_NOW"]/power["POWER_SUPPLY_CURRENT_NOW"]
          append="(d)"
        }
        if (power["POWER_SUPPLY_STATUS"] == "Charging" ) {
          hh=(power["POWER_SUPPLY_CHARGE_FULL"] - power["POWER_SUPPLY_CHARGE_NOW"])/power["POWER_SUPPLY_CURRENT_NOW"]
          append="(c)"
        }
        mm = (hh % 1)*60
        ss = (mm % 1)*60
        printf "%02d:%02d:%02d %s", hh,mm,ss,append
      }
    }' /sys/class/power_supply/BAT0/uevent
  fi
}

cpu_temp() {
  awk '{ printf "%0.1f°C", $1/1000}' /sys/class/thermal/thermal_zone0/temp
}

p_idle=0
p_total=0
cpu_usage() {
  awk -v p_idle="$p_idle" -v p_total="$p_total" '/cpu[^0-9]/ {
    idle=$5
    total=$2+$3+$4+$5
  } END {
    d_idle=idle-p_idle
    d_total=total-p_total
    d_usage=(1000*(d_total-d_idle)/d_total+5)/10
    print idle
    print total
    printf "%02d%%", d_usage
  }' /proc/stat
}

date_time() {
  date +"%Y-%m-%d %H:%M"
}

disk_usage() {
  df / /home | awk '/\// {
    avail[$6]=$4
  } END {
    for ( i in avail ) {
      unit_count[i]=0
      while ( avail[i] > 1024 ) {
        avail[i]=avail[i]/1024.0
        unit_count[i]++
      }
      if ( unit_count [i] < 2 )
        unit[i]="MB"
      else if ( unit_count[i] < 3 )
        unit[i]="GB"
      else
        unit[i]="TB"
    }
    printf "/ %0.1f %s - /home %0.1f %s", avail["/"],unit["/"],avail["/home"],unit["/home"]
  }'
}

essid() {
  ssid=$(iwgetid --raw)
  printf "wlan0: %s" "$ssid"
}

free_mem() {
  awk '{
    mem[$1]=$2
  } END {
    printf "%02d%% free", 100*(mem["MemFree:"]+mem["Buffers:"]+mem["Cached:"])/mem["MemTotal:"]
  }' /proc/meminfo
}

gmail() {
  curl -su username:password -o ~/gmail.xml https://mail.google.com/mail/feed/atom
  if [[ -e ~/gmail.xml ]]
  then
    awk -F'</?fullcount>' 'NF>1 {
      printf "%d new", $2
    }' ~/gmail.xml
    rm ~/gmail.xml
  else
    printf "no new"
  fi
}

weather() {
  curl -so ~/weather.xml http://w1.weather.gov/xml/current_obs/KRIC.xml
  if [[ -e ~/weather.xml ]]
  then
    xmllint ~/weather.xml --xpath 'concat(//temp_f, "°F ", //weather)'
    rm ~/weather.xml
  else
    printf "no weather"
  fi
}

while true; do
  for i in {0..8}; do
    let count[$i]+=1
    if [ ${count[$i]} -ge ${ival[$i]} ]; then
      case "$i" in
        0) out_string[3]="$(bat)"
           ;;
        1) out_string[4]="$(cpu_temp)"
           ;;
        2) read p_idle p_total d_usage <<< $(cpu_usage)
           out_string[5]="$d_usage"
           ;;
        3) out_string[7]="$(date_time)"
           ;;
        4) out_string[0]="$(disk_usage)"
           ;;
        5) out_string[1]="$(essid)"
           ;;
        6) out_string[6]="$(free_mem)"
           ;;
        7) out_string[2]="$(gmail)"
           ;;
        8) out_string[8]="$(weather)"
           ;;
        *) out_string[$i]=""
           ;;
      esac
      count[$i]=0
    fi
  done
  printf "%s | %s | %s | %s | %s | %s | %s | %s | %s\n" "${out_string[@]}"
  sleep $base_ival
done
