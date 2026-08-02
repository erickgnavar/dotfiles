#!/usr/bin/env bash
data=$(curl -s "wttr.in/?format=j1" --max-time 5)
city=$(curl -s "wttr.in/?format=%l" --max-time 5)

if [ -z "$data" ]; then
  echo '{"icon": "\uf071", "temp": "--", "feels": "--", "desc": "offline", "humidity": "--", "wind": "--", "city": "--"}'
  exit 0
fi

temp=$(echo "$data" | jq -r '.current_condition[0].temp_C')
feels=$(echo "$data" | jq -r '.current_condition[0].FeelsLikeC')
desc=$(echo "$data" | jq -r '.current_condition[0].weatherDesc[0].value')
humidity=$(echo "$data" | jq -r '.current_condition[0].humidity')
wind=$(echo "$data" | jq -r '.current_condition[0].windspeedKmph')
code=$(echo "$data" | jq -r '.current_condition[0].weatherCode')
city=$(echo "$city" | tr '[:lower:]' '[:upper:]')

case "$code" in
113) icon="\ue30d" ;;
116) icon="\ue302" ;;
119 | 122) icon="\ue312" ;;
143 | 248 | 260) icon="\ue313" ;;
176 | 263 | 266 | 281 | 284 | 293 | 296 | 299 | 302 | 305 | 308 | 311 | 314 | 353 | 356 | 359) icon="\ue318" ;;
179 | 182 | 185 | 227 | 230 | 317 | 320 | 323 | 326 | 329 | 332 | 335 | 338 | 350 | 362 | 365 | 368 | 371 | 374 | 377) icon="\ue31a" ;;
200 | 386 | 389 | 392 | 395) icon="\ue31d" ;;
*) icon="\ue312" ;;
esac

jq -n \
  --arg icon "$icon" \
  --arg temp "$temp" \
  --arg feels "$feels" \
  --arg desc "$desc" \
  --arg humidity "$humidity" \
  --arg wind "$wind" \
  --arg city "$city" \
  '{icon: $icon, temp: $temp, feels: $feels, desc: $desc, humidity: $humidity, wind: $wind, city: $city}'
