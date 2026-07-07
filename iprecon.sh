#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <subdomains.txt>"
    exit 1
fi

INPUT="$1"
ACTIVE_OUT="activesubs.txt"
IPS_OUT="ips.txt"

touch "$ACTIVE_OUT" "$IPS_OUT"

CF_RANGES="/tmp/cf_ranges_$$.txt"
RAW_IPS="/tmp/raw_ips_$$.txt"
CF_SUBS="/tmp/cf_subs_$$.txt"
REAL_IPS="/tmp/real_ips_$$.txt"

> "$CF_RANGES"
> "$RAW_IPS"
> "$CF_SUBS"
> "$REAL_IPS"

IP_REGEX="([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})"

echo "[*] Reading subdomains from: $INPUT"
TOTAL=$(wc -l < "$INPUT")
echo "[*] Total subdomains to process: $TOTAL"

echo "[*] Fetching Cloudflare IP ranges..."
curl -s --max-time 10 "https://www.cloudflare.com/ips-v4" >> "$CF_RANGES" 2>/dev/null
curl -s --max-time 10 "https://www.cloudflare.com/ips-v6" >> "$CF_RANGES" 2>/dev/null
sleep 2

echo "[*] Checking alive subdomains with httpx..."
httpx -l "$INPUT" \
    -threads 1 \
    -rate-limit 5 \
    -timeout 10 \
    -status-code \
    -silent \
    2>/dev/null | grep -oE "https?://[^ ]+" | \
    sed 's|https://||;s|http://||' | \
    sort -u >> "$ACTIVE_OUT"

sort -u "$ACTIVE_OUT" -o "$ACTIVE_OUT"
echo "[+] Alive subdomains: $(wc -l < "$ACTIVE_OUT")"

echo "[*] Resolving IPs with Python socket resolver..."
python3 - <<PYEOF
import socket
import sys

existing_ips = set()
try:
    with open('$IPS_OUT', 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                existing_ips.add(line)
except FileNotFoundError:
    pass

try:
    with open('$INPUT', 'r') as f:
        lines = f.readlines()
except FileNotFoundError:
    print("Error: input file not found.", file=sys.stderr)
    sys.exit(1)

resolved = []
seen = set(existing_ips)

for line in lines:
    line = line.strip()
    if not line:
        continue
    for token in line.split():
        try:
            ip = socket.gethostbyname(token)
            if ip not in seen:
                resolved.append((token, ip))
                seen.add(ip)
        except socket.gaierror:
            try:
                results = socket.getaddrinfo(token, None)
                for r in results:
                    ip = r[4][0]
                    if ':' in ip:
                        continue
                    if ip not in seen:
                        resolved.append((token, ip))
                        seen.add(ip)
            except socket.gaierror:
                print(f"Warning: could not resolve {token}", file=sys.stderr)

with open('$RAW_IPS', 'a') as f:
    for sub, ip in resolved:
        f.write(f'{sub} {ip}\n')

print(f'[+] Socket resolver found {len(resolved)} IPs')
PYEOF

echo "[*] Running dnsx for additional resolution..."
dnsx -l "$INPUT" \
    -t 1 \
    -rl 5 \
    -a \
    -resp \
    -silent \
    2>/dev/null | grep -oE "$IP_REGEX" >> "$RAW_IPS"

echo "[*] Running dig and host on each subdomain..."
while IFS= read -r sub; do
    sub=$(echo "$sub" | tr -d '[:space:]')
    [ -z "$sub" ] && continue

    dig +short "$sub" A @8.8.8.8 2>/dev/null | \
        grep -oE "$IP_REGEX" | \
        sed "s/^/$sub /" >> "$RAW_IPS"

    dig +short "$sub" A @1.1.1.1 2>/dev/null | \
        grep -oE "$IP_REGEX" | \
        sed "s/^/$sub /" >> "$RAW_IPS"

    dig +short "$sub" A @9.9.9.9 2>/dev/null | \
        grep -oE "$IP_REGEX" | \
        sed "s/^/$sub /" >> "$RAW_IPS"

    dig +short "$sub" A @208.67.222.222 2>/dev/null | \
        grep -oE "$IP_REGEX" | \
        sed "s/^/$sub /" >> "$RAW_IPS"

    host "$sub" 2>/dev/null | \
        grep -oE "$IP_REGEX" | \
        sed "s/^/$sub /" >> "$RAW_IPS"

    sleep 1

done < "$INPUT"

echo "[*] Querying HackerTarget..."
while IFS= read -r sub; do
    sub=$(echo "$sub" | tr -d '[:space:]')
    [ -z "$sub" ] && continue
    curl -s --max-time 10 \
        "https://api.hackertarget.com/hostsearch/?q=$sub" \
        2>/dev/null | grep -oE "$IP_REGEX" >> "$RAW_IPS"
    sleep 3
done < "$INPUT"

echo "[*] Checking Cloudflare and separating real IPs..."
python3 - <<PYEOF2
import ipaddress
import re

IP_PAT = re.compile(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})')

cf_ranges = []
with open('$CF_RANGES', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            cf_ranges.append(ipaddress.ip_network(line, strict=False))
        except ValueError:
            continue

private_ranges = [
    ipaddress.ip_network('10.0.0.0/8'),
    ipaddress.ip_network('172.16.0.0/12'),
    ipaddress.ip_network('192.168.0.0/16'),
    ipaddress.ip_network('127.0.0.0/8'),
    ipaddress.ip_network('0.0.0.0/8'),
    ipaddress.ip_network('169.254.0.0/16'),
]

def is_cloudflare(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        return any(ip in net for net in cf_ranges)
    except ValueError:
        return False

def is_private(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        return any(ip in net for net in private_ranges)
    except ValueError:
        return False

cf_subs = set()
non_cf_ips = set()

with open('$RAW_IPS', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        sub = parts[0] if parts else ''
        ips = IP_PAT.findall(line)
        for ip in ips:
            if is_private(ip):
                continue
            if is_cloudflare(ip):
                if sub:
                    cf_subs.add(sub)
            else:
                non_cf_ips.add(ip)

with open('$CF_SUBS', 'w') as f:
    for sub in cf_subs:
        f.write(f'{sub}\n')

with open('$REAL_IPS', 'w') as f:
    for ip in non_cf_ips:
        f.write(f'{ip}\n')

print(f'[+] Cloudflare-protected subdomains: {len(cf_subs)}')
print(f'[+] Non-Cloudflare IPs: {len(non_cf_ips)}')
PYEOF2

if [ -s "$CF_SUBS" ]; then
    echo "[*] Finding real IPs behind Cloudflare..."
    while IFS= read -r sub; do
        sub=$(echo "$sub" | tr -d '[:space:]')
        [ -z "$sub" ] && continue
        echo "[*] Checking origin for: $sub"

        curl -s --max-time 10 \
            "https://viewdns.info/iphistory/?domain=$sub" \
            -A "Mozilla/5.0" 2>/dev/null | \
            grep -oE "$IP_REGEX" >> "$REAL_IPS"
        sleep 2

        curl -s --max-time 10 \
            "https://api.hackertarget.com/hostsearch/?q=$sub" \
            2>/dev/null | grep -oE "$IP_REGEX" >> "$REAL_IPS"
        sleep 2

        curl -s --max-time 10 \
            "https://crt.sh/?q=%25.$sub&output=json" \
            2>/dev/null | grep -oE "$IP_REGEX" >> "$REAL_IPS"
        sleep 2

        curl -sk --max-time 10 "https://$sub" \
            -A "Mozilla/5.0" -D - -o /dev/null 2>/dev/null | \
            grep -iE "^x-real-ip:|^x-forwarded-for:|^x-origin-ip:|^x-backend-ip:" | \
            grep -oE "$IP_REGEX" >> "$REAL_IPS"
        sleep 3

    done < "$CF_SUBS"
fi

echo "[*] Finalizing ips.txt..."
python3 - <<PYEOF3
import ipaddress

IP_OK = __import__('re').compile(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$')

cf_ranges = []
with open('$CF_RANGES', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            cf_ranges.append(ipaddress.ip_network(line, strict=False))
        except ValueError:
            continue

private_ranges = [
    ipaddress.ip_network('10.0.0.0/8'),
    ipaddress.ip_network('172.16.0.0/12'),
    ipaddress.ip_network('192.168.0.0/16'),
    ipaddress.ip_network('127.0.0.0/8'),
    ipaddress.ip_network('0.0.0.0/8'),
    ipaddress.ip_network('169.254.0.0/16'),
]

def is_bad(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        if any(ip in net for net in private_ranges):
            return True
        if any(ip in net for net in cf_ranges):
            return True
        return False
    except ValueError:
        return True

existing = set()
try:
    with open('$IPS_OUT', 'r') as f:
        for line in f:
            ip = line.strip()
            if ip:
                existing.add(ip)
except FileNotFoundError:
    pass

new_ips = set()
with open('$REAL_IPS', 'r') as f:
    for line in f:
        ip = line.strip()
        if not ip or not IP_OK.match(ip):
            continue
        if is_bad(ip):
            continue
        new_ips.add(ip)

all_ips = existing | new_ips

with open('$IPS_OUT', 'w') as f:
    for ip in sorted(all_ips):
        f.write(f'{ip}\n')

print(f'[+] New IPs added: {len(new_ips - existing)}')
print(f'[+] Total unique real IPs in ips.txt: {len(all_ips)}')
PYEOF3

echo "[+] Done."
echo "[+] activesubs.txt: $(wc -l < "$ACTIVE_OUT") alive subdomains"
echo "[+] ips.txt: $(wc -l < "$IPS_OUT") unique real IPs"

rm -f "$CF_RANGES" "$RAW_IPS" "$CF_SUBS" "$REAL_IPS"
