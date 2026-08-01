#!/usr/bin/env bash
data=$(curl -s "wttr.in/?format=j1" --max-time 5)
city=$(curl -s "wttr.in/?format=%l" --max-time 5)

if [ -z "$data" ]; then
  echo '{"icon": "\uf071", "temp": "--", "feels": "--", "desc": "offline", "humidity": "--", "city": "--"}'
  exit 0
fi

temp=$(echo "$data" | jq -r '.current_condition[0].temp_C')
feels=$(echo "$data" | jq -r '.current_condition[0].FeelsLikeC')
desc=$(echo "$data" | jq -r '.current_condition[0].weatherDesc[0].value')
humidity=$(echo "$data" | jq -r '.current_condition[0].humidity')
code=$(echo "$data" | jq -r '.current_condition[0].weatherCode')
city=$(echo "$city" | tr '[:lower:]' '[:upper:]')

case "$code" in
113) icon="\ue30d" ;;
116) icon="\ue302" ;;
119 | 122) icon="\ue312" ;;
176 | 263 | 266 | 293 | 296 | 299 | 302) icon="\ue318" ;;
179 | 182 | 185 | 227 | 230) icon="\ue31a" ;;
200) icon="\ue31d" ;;
248 | 260) icon="\ue313" ;;
*) icon="\ue30d" ;;
esac

jq -n \
  --arg icon "$icon" \
  --arg temp "$temp" \
  --arg feels "$feels" \
  --arg desc "$desc" \
  --arg humidity "$humidity" \
  --arg city "$city" \
  '{icon: $icon, temp: $temp, feels: $feels, desc: $desc, humidity: $humidity, city: $city}'
