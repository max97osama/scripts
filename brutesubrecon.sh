#!/bin/bash

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <domain|domains.txt> <wordlist.txt> <subdomains.txt>"
    exit 1
fi

INPUT="$1"
WORDLIST="$2"
SUBDOMAINS_FILE="$3"

touch "$SUBDOMAINS_FILE"

DOMAINS_LIST="/tmp/bs_domains_$$.txt"
> "$DOMAINS_LIST"

if [ -f "$INPUT" ]; then
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '[:space:]')
        [ -z "$line" ] && continue
        echo "$line" >> "$DOMAINS_LIST"
    done < "$INPUT"
else
    echo "$INPUT" >> "$DOMAINS_LIST"
fi

sort -u "$DOMAINS_LIST" -o "$DOMAINS_LIST"

echo "[*] Total domains to process: $(wc -l < "$DOMAINS_LIST")"

SUBS_OUT="subs.txt"
CLEANED_OUT="cleanedsubs.txt"
IPS_OUT="ips.txt"
VALID_OUT="validsubs.txt"

touch "$SUBS_OUT" "$CLEANED_OUT" "$IPS_OUT" "$VALID_OUT"

FFUF_OUT="/tmp/ffuf_subs_$$.txt"
KNOCK_OUT="/tmp/knock_subs_$$.txt"
ALTERX_OUT="/tmp/alterx_subs_$$.txt"
ALL_RAW="/tmp/all_raw_$$.txt"
RESOLVED="/tmp/resolved_$$.txt"
FFUF_JSON="/tmp/ffuf_raw_$$.json"
HTTPX_OUT="/tmp/httpx_$$.txt"
DNSX_OUT="/tmp/dnsx_$$.txt"

> "$ALL_RAW"
> "$RESOLVED"
> "$HTTPX_OUT"
> "$DNSX_OUT"

while IFS= read -r DOMAIN; do
    echo "[*] Starting subdomain bruteforce for: $DOMAIN"

    > "$FFUF_OUT"
    > "$KNOCK_OUT"
    > "$ALTERX_OUT"

    echo "[*] Running ffuf subdomain bruteforce on $DOMAIN..."
    ffuf -u "https://FUZZ.$DOMAIN" \
        -w "$WORDLIST" \
        -t 1 \
        -rate 5 \
        -timeout 10 \
        -mc 200,301,302,403 \
        -o "$FFUF_JSON" \
        -of json \
        -s 2>/dev/null

    if [ -f "$FFUF_JSON" ]; then
        python3 -c "
import json
with open('$FFUF_JSON') as f:
    data = json.load(f)
for r in data.get('results', []):
    host = r.get('input', {}).get('FUZZ', '')
    if host:
        print(f'{host}.$DOMAIN')
" > "$FFUF_OUT" 2>/dev/null
        rm -f "$FFUF_JSON"
    fi

    sleep 5

    echo "[*] Running knockpy on $DOMAIN..."
    knockpy "$DOMAIN" --recon --no-http 2>/dev/null | \
        grep -oE "[a-zA-Z0-9._-]+\.$DOMAIN" > "$KNOCK_OUT"

    sleep 5

    echo "[*] Running alterx permutation on $DOMAIN..."
    grep "$DOMAIN" "$SUBDOMAINS_FILE" 2>/dev/null > /tmp/bs_domain_subs_$$.txt
    if [ -s /tmp/bs_domain_subs_$$.txt ]; then
        alterx -l /tmp/bs_domain_subs_$$.txt \
            -o "$ALTERX_OUT" \
            -enrich 2>/dev/null
    fi
    rm -f /tmp/bs_domain_subs_$$.txt

    sleep 3

    echo "[*] Merging candidates for $DOMAIN..."
    cat "$SUBDOMAINS_FILE" "$FFUF_OUT" "$KNOCK_OUT" "$ALTERX_OUT" 2>/dev/null | \
        grep -E "^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$" | \
        grep "$DOMAIN" | \
        sort -u >> "$ALL_RAW"

    sleep 2

done < "$DOMAINS_LIST"

sort -u "$ALL_RAW" -o "$ALL_RAW"

echo "[*] Total unique candidates across all domains: $(wc -l < "$ALL_RAW")"

echo "[*] Resolving with dnsx..."
dnsx -l "$ALL_RAW" \
    -t 1 \
    -rl 5 \
    -o "$RESOLVED" \
    -silent 2>/dev/null

echo "[*] Running dnsx for IP and hostname info..."
dnsx -l "$RESOLVED" \
    -t 1 \
    -rl 5 \
    -a \
    -resp \
    -silent \
    2>/dev/null > "$DNSX_OUT"

sleep 3

echo "[*] Running httpx for status codes..."
httpx -l "$RESOLVED" \
    -threads 1 \
    -rate-limit 5 \
    -timeout 10 \
    -status-code \
    -silent \
    2>/dev/null > "$HTTPX_OUT"

sleep 3

echo "[*] Building output files..."

python3 - <<PYEOF
import re

ipv4_pat = re.compile(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')

httpx_map = {}
with open('$HTTPX_OUT', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) >= 2:
            url = parts[0].replace('https://','').replace('http://','').rstrip('/')
            code = parts[1].strip('[]')
            httpx_map[url] = code

dnsx_map = {}
with open('$DNSX_OUT', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if not parts:
            continue
        sub = parts[0]
        bracket_vals = re.findall(r'\[([^\]]+)\]', line)
        ip = '0.0.0.0'
        for val in bracket_vals:
            if ipv4_pat.match(val):
                ip = val
                break
        dnsx_map[sub] = ip

with open('$RESOLVED', 'r') as f:
    subs = [line.strip() for line in f if line.strip()]

subs_out = open('$SUBS_OUT', 'a')
cleaned_out = open('$CLEANED_OUT', 'a')
ips_out = open('$IPS_OUT', 'a')
valid_out = open('$VALID_OUT', 'a')

all_ips = set()

for sub in subs:
    code = httpx_map.get(sub, 'N/A')
    ip = dnsx_map.get(sub, '0.0.0.0')
    status_text = 'OK' if code == '200' else code
    subs_out.write(f'{sub} {code} {status_text} {ip} {sub}\n')
    cleaned_out.write(f'{sub}\n')
    if ip != '0.0.0.0':
        all_ips.add(ip)
    if code == '200':
        valid_out.write(f'{sub}\n')

for ip in sorted(all_ips):
    ips_out.write(f'{ip}\n')

subs_out.close()
cleaned_out.close()
ips_out.close()
valid_out.close()

print(f'[+] subs.txt new entries: {len(subs)}')
print(f'[+] validsubs.txt new 200 OK entries: {sum(1 for s in subs if httpx_map.get(s,"") == "200")}')
print(f'[+] ips.txt new unique IPs: {len(all_ips)}')
PYEOF

NEW=$(comm -23 <(sort "$CLEANED_OUT" | uniq) <(sort "$SUBDOMAINS_FILE"))
NEW_COUNT=$(echo "$NEW" | grep -c ".")

echo "$NEW" >> "$SUBDOMAINS_FILE"
sort -u "$SUBDOMAINS_FILE" -o "$SUBDOMAINS_FILE"

echo "[+] $NEW_COUNT new subdomains added to $SUBDOMAINS_FILE"
echo "[+] Output files: $SUBS_OUT | $CLEANED_OUT | $IPS_OUT | $VALID_OUT"

rm -f "$FFUF_OUT" "$KNOCK_OUT" "$ALTERX_OUT" "$ALL_RAW" "$RESOLVED" \
    "$HTTPX_OUT" "$DNSX_OUT" "$DOMAINS_LIST"
