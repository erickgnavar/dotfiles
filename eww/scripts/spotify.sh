#!/usr/bin/env bash
# Stream Spotify metadata for Eww.

cover_dir=${XDG_CACHE_HOME:-$HOME/.cache}/eww
cover_path=$cover_dir/spotify-cover
cover_url_path=$cover_dir/spotify-cover-url

resolve_cover() {
  local art_url=$1 cached_url temp_path

  case "$art_url" in
  file://*)
    printf '%s\n' "${art_url#file://}"
    return
    ;;
  http://* | https://*)
    mkdir -p "$cover_dir"
    cached_url=$(cat "$cover_url_path" 2>/dev/null || true)
    if [ "$art_url" != "$cached_url" ] || [ ! -s "$cover_path" ]; then
      temp_path=$cover_path.tmp
      if wget --quiet --output-document="$temp_path" "$art_url"; then
        mv "$temp_path" "$cover_path"
        printf '%s' "$art_url" >"$cover_url_path"
      else
        rm -f "$temp_path"
      fi
    fi
    [ -s "$cover_path" ] && printf '%s\n' "$cover_path"
    ;;
  esac
}

emit_metadata() {
  jq -cn \
    --arg status "$1" \
    --arg artist "$2" \
    --arg title "$3" \
    --arg album "$4" \
    --arg cover "$5" \
    '{status: $status, artist: $artist, title: $title, album: $album, cover: $cover}'
}

if ! command -v playerctl >/dev/null; then
  emit_metadata "Unavailable" "" "Spotify unavailable" "" ""
  while sleep 60; do :; done
fi

while true; do
  playerctl -p spotify metadata --follow \
    --format $'{{status}}\x1f{{artist}}\x1f{{title}}\x1f{{album}}\x1f{{mpris:artUrl}}' \
    2>/dev/null |
    while IFS=$'\x1f' read -r status artist title album art_url; do
      cover=$(resolve_cover "$art_url")
      emit_metadata "$status" "${artist:---}" "${title:---}" "${album:---}" "$cover"
    done

  emit_metadata "Stopped" "" "Nothing playing" "" ""
  sleep 2
done
