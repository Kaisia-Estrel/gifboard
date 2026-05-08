#!/usr/bin/env bash

if [[ "$LINES" -lt 50 ]]; then
  clear
fi

printf '\x1b[6n'
IFS='[;' read -d 'R' -s -r _ startrow _startcol

if [[ "$startrow" -gt 40 ]]; then
  for i in $(seq 12); do
    echo -en "\n"
  done
  (( startrow -= 12))
fi

limit=4
pos=0

if [[ ! -z "$2" ]]; then
  limit="$2"
fi

if [[ ! -z "$3" ]]; then
  pos="$((limit * $3))"
  ((limit += pos))
fi

results="$(curl -s "https://g.tenor.com/v1/search?q=$1&key=LIVDSRZULELA&limit=$limit&pos=$pos")"

i=0
jq -r '
    .results[] 
  | .media[0] 
  | [.[]]
  | max_by(.size)
  | .url
  ' <<< "$results" | while read -r url; do
  curl -s "$url" | kitty +kitten icat -n --place "20x10@$((i*20))x$startrow" 2>/dev/null
  # echo -en "\x1b[10B"
  echo -en "\x1b[$((startrow+11));$((i*20))H [$i]"
  ((i++))
done
echo -en "\nSelect an image: "
read   -r option

selected=$(jq -r --argjson option "$option" '
    .results[$option]
  | .media[0]
  | .webp_transparent // .webp // .gif
  | .url
  ' <<< "$results")

fileloc="$(mktemp)-${selected##*/}"

curl "$selected" -o "$fileloc"
echo "saved at $fileloc"

wl-copy -t "text/uri-list" "file://$fileloc"
echo "File copied to clipboard"

