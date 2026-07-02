#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <urls.txt>"
    exit 1
fi

INPUT="$1"
TEMP1="/tmp/clean1_$$.txt"
TEMP2="/tmp/clean2_$$.txt"

grep -oE "(https?://[a-zA-Z0-9./_:@?=&%+~#-]+|www\.[a-zA-Z0-9./_:@?=&%+~#-]+|[a-zA-Z0-9][a-zA-Z0-9._-]*\.[a-zA-Z]{2,}(/[a-zA-Z0-9./_:@?=&%+~#-]*)?)" "$INPUT" > "$TEMP1"

grep -vE "^\s*$|^[0-9]+$|\.(jpg|jpeg|png|gif|svg|ico|bmp|webp|woff|woff2|ttf|eot|pdf|mp4|mp3)$" "$TEMP1" | \
    grep -E "\.[a-zA-Z]{2,}" > "$TEMP2"

sort -u "$TEMP2" -o "$TEMP2"

uro -i "$TEMP2" -o "$INPUT" 2>/dev/null

if [ ! -s "$INPUT" ]; then
    cp "$TEMP2" "$INPUT"
fi

sort -u "$INPUT" -o "$INPUT"

echo "[+] Done. Clean unique URLs in $INPUT: $(wc -l < "$INPUT")"

rm -f "$TEMP1" "$TEMP2"