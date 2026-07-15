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

grep -iE "\.js(\?.*)?$" "$INPUT" > js.txt
grep -E "\?" "$INPUT" > parameters.txt
grep -viE "\.(js|css|jpg|jpeg|png|gif|svg|ico|webp|bmp|tiff|woff|woff2|ttf|eot|json)(\?.*)?$" "$INPUT" > cleaned.txt

echo "[+] js.txt: $(wc -l < js.txt)"
echo "[+] parameters.txt: $(wc -l < parameters.txt)"
echo "[+] cleaned.txt: $(wc -l < cleaned.txt)"

ALLJS="alljs.txt"
FINDINGS="Findings.txt"
JSECRETS="jsecrets.txt"

> "$ALLJS"
> "$FINDINGS"
> "$JSECRETS"

PATTERN='(api[_-]?key|apikey|api[_-]?secret|secret[_-]?key|secret|password|passwd|pwd|access[_-]?key|access[_-]?token|auth[_-]?token|authorization|bearer|client[_-]?secret|private[_-]?key|aws_access_key_id|aws_secret_access_key|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|firebase|mongodb\+srv|x-api-key)'

STRICT_PATTERN='(AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|mongodb\+srv://[^[:space:]"'"'"']+|(api[_-]?key|apikey|api[_-]?secret|secret[_-]?key|secret|access[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|private[_-]?key|x-api-key)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_.\/+=-]{10,}["'"'"'])'

FALSE_POSITIVE='(your[_-]?(api)?[_-]?key|xxxxxxxx|00000000|changeme|example\.com|placeholder|dummy|test[_-]?key|\{\{|\$\{|<[a-zA-Z])'

while IFS= read -r url; do
    [ -z "$url" ] && continue

    CONTENT=$(timeout 20 curl -s --max-time 15 "$url")
    echo "$CONTENT" >> "$ALLJS"

    echo "$CONTENT" | grep -inE "$PATTERN" | while IFS= read -r line; do
        echo "URL: $url" >> "$FINDINGS"
        echo "$line" >> "$FINDINGS"
        echo "" >> "$FINDINGS"
    done

    echo "$CONTENT" | grep -inE "$STRICT_PATTERN" | grep -viE "$FALSE_POSITIVE" | while IFS= read -r line; do
        echo "URL: $url" >> "$JSECRETS"
        echo "$line" >> "$JSECRETS"
        echo "" >> "$JSECRETS"
    done

done < js.txt

echo "[+] alljs.txt: $(wc -l < "$ALLJS")"
echo "[+] Findings.txt entries: $(grep -c '^URL:' "$FINDINGS")"
echo "[+] jsecrets.txt entries: $(grep -c '^URL:' "$JSECRETS")"