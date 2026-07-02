#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <subdomains.txt>"
    exit 1
fi

INPUT="$1"
ACTIVE_OUT="activesubs.txt"
IPS_OUT="ips.txt"

touch "$ACTIVE_OUT" "$IPS_OUT"

RESOLVED="/tmp/resolved_$$.txt"
HTTPX_OUT="/tmp/httpx_$$.txt"
DNSX_OUT="/tmp/dnsx_$$.txt"
CF_SUBS="/tmp/cf_subs_$$.txt"
NON_CF_IPS="/tmp/non_cf_ips_$$.txt"
REAL_IPS="/tmp/real_ips_$$.txt"

> "$RESOLVED"
> "$HTTPX_OUT"
> "$DNSX_OUT"
> "$CF_SUBS"
> "$NON_CF_IPS"
> "$REAL_IPS"

CF_RANGES="/tmp/cf_ranges_$$.txt"
> "$CF_RANGES"

echo "[*] Fetching Cloudflare IP ranges..."
curl -s "https://www.cloudflare.com/ips-v4" >> "$CF_RANGES" 2>/dev/null
curl -s "https://www.cloudflare.com/ips-v6" >> "$CF_RANGES" 2>/dev/null

sleep 2

echo "[*] Resolving subdomains with dnsx..."
dnsx -l "$INPUT" \
    -t 1 \
    -rl 5 \
    -o "$RESOLVED" \
    -silent 2>/dev/null

echo "[*] Checking alive subdomains with httpx..."
httpx -l "$RESOLVED" \
    -threads 1 \
    -rate-limit 5 \
    -timeout 10 \
    -status-code \
    -silent \
    2>/dev/null | grep -oE "^https?://[^ ]+" | \
    sed 's|https\?://||' | \
    sort -u > "$HTTPX_OUT"

cat "$HTTPX_OUT" >> "$ACTIVE_OUT"
sort -u "$ACTIVE_OUT" -o "$ACTIVE_OUT"

echo "[+] Active subdomains found: $(wc -l < "$HTTPX_OUT")"

echo "[*] Running dnsx to get IPs for active subdomains..."
dnsx -l "$HTTPX_OUT" \
    -t 1 \
    -rl 5 \
    -a \
    -resp \
    -silent \
    2>/dev/null > "$DNSX_OUT"

echo "[*] Checking which IPs belong to Cloudflare..."

python3 - <<PYEOF
import ipaddress
import re

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

def is_cloudflare(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        return any(ip in net for net in cf_ranges)
    except ValueError:
        return False

cf_subs = open('$CF_SUBS', 'w')
non_cf_ips = open('$NON_CF_IPS', 'w')

with open('$DNSX_OUT', 'r') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        sub = line.split()[0]
        ips = re.findall(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', line)
        for ip in ips:
            if is_cloudflare(ip):
                cf_subs.write(f'{sub}\n')
            else:
                non_cf_ips.write(f'{ip}\n')

cf_subs.close()
non_cf_ips.close()

print(f'[+] Cloudflare-protected subdomains: {sum(1 for _ in open("$CF_SUBS"))}')
print(f'[+] Non-Cloudflare IPs found: {sum(1 for _ in open("$NON_CF_IPS"))}')
PYEOF

if [ -s "$CF_SUBS" ]; then
    echo "[*] Attempting to find real IPs behind Cloudflare..."

    while IFS= read -r sub; do
        echo "[*] Checking origin for: $sub"

        curl -s "https://securitytrails.com/domain/$sub/history/a" \
            --max-time 10 \
            -A "Mozilla/5.0" \
            2>/dev/null | \
            grep -oE "\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" >> "$REAL_IPS"

        sleep 2

        curl -s "https://viewdns.info/iphistory/?domain=$sub" \
            --max-time 10 \
            -A "Mozilla/5.0" \
            2>/dev/null | \
            grep -oE "\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" >> "$REAL_IPS"

        sleep 2

        dig +short "$sub" @8.8.8.8 2>/dev/null | \
            grep -oE "\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" >> "$REAL_IPS"

        sleep 1

        subfinder -d "$sub" -silent 2>/dev/null | \
            dnsx -t 1 -rl 3 -a -resp -silent 2>/dev/null | \
            grep -oE "\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" >> "$REAL_IPS"

        sleep 2

        curl -s "https://api.hackertarget.com/hostsearch/?q=$sub" \
            --max-time 10 \
            2>/dev/null | \
            grep -oE "\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b" >> "$REAL_IPS"

        sleep 3

    done < "$CF_SUBS"

    python3 - <<PYEOF2
import ipaddress
import re

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

def is_cloudflare(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        return any(ip in net for net in cf_ranges)
    except ValueError:
        return False

private_ranges = [
    ipaddress.ip_network('10.0.0.0/8'),
    ipaddress.ip_network('172.16.0.0/12'),
    ipaddress.ip_network('192.168.0.0/16'),
    ipaddress.ip_network('127.0.0.0/8'),
]

def is_private(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        return any(ip in net for net in private_ranges)
    except ValueError:
        return False

real_ips = set()
with open('$REAL_IPS', 'r') as f:
    for line in f:
        ip = line.strip()
        if not ip:
            continue
        if is_cloudflare(ip):
            continue
        if is_private(ip):
            continue
        real_ips.add(ip)

with open('$NON_CF_IPS', 'a') as f:
    for ip in real_ips:
        f.write(f'{ip}\n')

print(f'[+] Real IPs found behind Cloudflare: {len(real_ips)}')
PYEOF2
fi

cat "$NON_CF_IPS" >> "$IPS_OUT"

python3 - <<PYEOF3
import ipaddress

private_ranges = [
    ipaddress.ip_network('10.0.0.0/8'),
    ipaddress.ip_network('172.16.0.0/12'),
    ipaddress.ip_network('192.168.0.0/16'),
    ipaddress.ip_network('127.0.0.0/8'),
]

def is_private(ip_str):
    try:
        ip = ipaddress.ip_address(ip_str)
        return any(ip in net for net in private_ranges)
    except ValueError:
        return False

seen = set()
valid = []
with open('$IPS_OUT', 'r') as f:
    for line in f:
        ip = line.strip()
        if not ip or ip in seen:
            continue
        try:
            ipaddress.ip_address(ip)
        except ValueError:
            continue
        if is_private(ip):
            continue
        seen.add(ip)
        valid.append(ip)

with open('$IPS_OUT', 'w') as f:
    for ip in sorted(valid):
        f.write(f'{ip}\n')

print(f'[+] Final clean IPs in ips.txt: {len(valid)}')
PYEOF3

echo "[+] Done."
echo "[+] activesubs.txt: $(wc -l < "$ACTIVE_OUT") alive subdomains"
echo "[+] ips.txt: $(wc -l < "$IPS_OUT") unique real IPs"

rm -f "$RESOLVED" "$HTTPX_OUT" "$DNSX_OUT" "$CF_SUBS" \
    "$NON_CF_IPS" "$REAL_IPS" "$CF_RANGES"
