#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <domain> [subdomains_wordlist.txt] [kite_wordlist] [dir_wordlist.txt]
    
    example wordlists :
      /root/wordlist/shorts/subdomains.txt /root/wordlist/large.kite /root/wordlist/shorts/dir.txt"
    exit 1
fi

DOMAIN="$1"
SUBS_WORDLIST="${2:-}"
KITE_WORDLIST="${3:-}"
DIR_WORDLIST="${4:-}"

SCRIPT_DIR="/root/scripts"

SUBDOMAINS_FILE="subdomains.txt"
IPS_FILE="ips.txt"
URLS_FILE="urls.txt"
JS_FILE="js.txt"

touch "$SUBDOMAINS_FILE" "$IPS_FILE" "$URLS_FILE" "$JS_FILE"

log() {
    echo ""
    echo "========================================================"
    echo "  $1"
    echo "========================================================"
}

has_script() {
    [ -f "$SCRIPT_DIR/$1" ] && [ -x "$SCRIPT_DIR/$1" ]
}

has_file() {
    [ -f "$1" ] && [ -s "$1" ]
}

log "STEP 1: PASSIVE SUBDOMAIN RECON"
if has_script "passivesubrecon.sh"; then
    echo "[*] Running passivesubrecon.sh..."
    bash "$SCRIPT_DIR/passivesubrecon.sh" "$DOMAIN" "$SUBDOMAINS_FILE"
    sleep 5
else
    echo "[-] passivesubrecon.sh not found, skipping."
fi

log "STEP 2: ACTIVE SUBDOMAIN BRUTEFORCE"
if has_script "brutesubrecon.sh" && has_file "$SUBS_WORDLIST"; then
    echo "[*] Running brutesubrecon.sh..."
    bash "$SCRIPT_DIR/brutesubrecon.sh" "$DOMAIN" "$SUBS_WORDLIST" "$SUBDOMAINS_FILE"
    sleep 5
else
    echo "[-] brutesubrecon.sh skipped: missing script or subdomains wordlist."
fi

log "STEP 3: FILTER ALIVE SUBDOMAINS AND FIND REAL IPS"
if has_script "iprecon.sh" && has_file "$SUBDOMAINS_FILE"; then
    echo "[*] Running iprecon.sh..."
    bash "$SCRIPT_DIR/iprecon.sh" "$SUBDOMAINS_FILE"
    sleep 5
    if has_file "activesubs.txt"; then
        cp activesubs.txt "$SUBDOMAINS_FILE"
        echo "[+] subdomains.txt updated with alive subdomains only."
    fi
else
    echo "[-] iprecon.sh skipped: missing script or subdomains.txt."
fi

log "STEP 4: TECH STACK FINGERPRINTING"
if has_script "techrecon.sh" && has_file "$SUBDOMAINS_FILE"; then
    echo "[*] Running techrecon.sh on subdomains..."
    bash "$SCRIPT_DIR/techrecon.sh" "$SUBDOMAINS_FILE"
    sleep 5
elif has_script "techrecon.sh" && has_file "$IPS_FILE"; then
    echo "[*] Running techrecon.sh on IPs..."
    bash "$SCRIPT_DIR/techrecon.sh" "$IPS_FILE"
    sleep 5
else
    echo "[-] techrecon.sh skipped: missing script or no input available."
fi

log "STEP 5: NMAP VULNERABILITY SCAN"
if has_script "nmapscan.sh" && has_file "$IPS_FILE"; then
    echo "[*] Running nmapscan.sh on each IP..."
    while IFS= read -r ip; do
        ip=$(echo "$ip" | tr -d '[:space:]')
        [ -z "$ip" ] && continue
        echo "[*] Nmap scanning: $ip"
        bash "$SCRIPT_DIR/nmapscan.sh" "$ip"
        sleep 10
    done < "$IPS_FILE"
else
    echo "[-] nmapscan.sh skipped: missing script or ips.txt."
fi

log "STEP 6: URL GATHERING"
if has_script "urlrecon.sh" && has_file "$SUBDOMAINS_FILE"; then
    echo "[*] Running urlrecon.sh with subdomains list..."
    bash "$SCRIPT_DIR/urlrecon.sh" "$DOMAIN" -l "$SUBDOMAINS_FILE"
    sleep 5
elif has_script "urlrecon.sh"; then
    echo "[*] Running urlrecon.sh with domain only..."
    bash "$SCRIPT_DIR/urlrecon.sh" "$DOMAIN"
    sleep 5
else
    echo "[-] urlrecon.sh skipped: missing script."
fi

log "STEP 7: DIRECTORY AND FILE BRUTEFORCE"
if has_script "dirrecon.sh" && has_file "$SUBDOMAINS_FILE" && has_file "$DIR_WORDLIST"; then
    echo "[*] Running dirrecon.sh..."
    bash "$SCRIPT_DIR/dirrecon.sh" "$DOMAIN" "$SUBDOMAINS_FILE" "$DIR_WORDLIST"
    sleep 5
    if has_file "burl.txt"; then
        cat burl.txt >> "$URLS_FILE"
        echo "[+] burl.txt appended to urls.txt"
    fi
else
    echo "[-] dirrecon.sh skipped: missing script, subdomains.txt or dir wordlist."
fi

log "STEP 8: CRAWLING"
if has_script "crawlrecon.sh" && has_file "$SUBDOMAINS_FILE" && has_file "$DIR_WORDLIST"; then
    echo "[*] Running crawlrecon.sh with subdomains list..."
    bash "$SCRIPT_DIR/crawlrecon.sh" "$SUBDOMAINS_FILE" 3 "$DIR_WORDLIST"
    sleep 5
elif has_script "crawlrecon.sh" && has_file "$DIR_WORDLIST"; then
    echo "[*] Running crawlrecon.sh on domain only..."
    bash "$SCRIPT_DIR/crawlrecon.sh" "$DOMAIN" 3 "$DIR_WORDLIST"
    sleep 5
else
    echo "[-] crawlrecon.sh skipped: missing script or dir wordlist."
fi


log "STEP 9: FIND URLS FROM JS AND PAGES"
if has_script "findrecon.sh" && has_file "$SUBDOMAINS_FILE"; then
    echo "[*] Running findrecon.sh with subdomains list..."
    bash "$SCRIPT_DIR/findrecon.sh" "$SUBDOMAINS_FILE"
    sleep 5
elif has_script "findrecon.sh"; then
    echo "[*] Running findrecon.sh with domain only..."
    bash "$SCRIPT_DIR/findrecon.sh" "$DOMAIN"
    sleep 5
else
    echo "[-] findrecon.sh skipped: missing script."
fi

if has_file "findurls.txt"; then
    cat findurls.txt >> "$URLS_FILE"
    echo "[+] findrecon findurls.txt appended to urls.txt"
fi

log "STEP 10: API RECON"
if has_script "apirecon.sh" && has_file "$SUBDOMAINS_FILE" && has_file "$KITE_WORDLIST"; then
    echo "[*] Running apirecon.sh..."
    bash "$SCRIPT_DIR/apirecon.sh" "$DOMAIN" "$SUBDOMAINS_FILE" "$KITE_WORDLIST"
    sleep 5
    if has_file "vulnerable_urls.txt"; then
        cat vulnerable_urls.txt >> "$URLS_FILE"
        echo "[+] vulnerable_urls.txt appended to urls.txt"
    fi
else
    echo "[-] apirecon.sh skipped: missing script, subdomains.txt or kite wordlist."
fi

log "STEP 11: CLEAN AND DEDUPLICATE URLS"
if has_script "cleanurls.sh" && has_file "$URLS_FILE"; then
    echo "[*] Running cleanurls.sh..."
    bash "$SCRIPT_DIR/cleanurls.sh" "$URLS_FILE"
    sleep 3
else
    echo "[-] cleanurls.sh skipped: missing script or urls.txt."
fi

log "STEP 12: URL FILTER"
if has_script "urlfilter.sh" && has_file "$URLS_FILE"; then
    echo "[*] Running urlfilter.sh..."
    bash "$SCRIPT_DIR/urlfilter.sh" "$URLS_FILE"
    sleep 3
else
    echo "[-] urlfilter.sh skipped: missing script or urls.txt."
fi

log "STEP 13: JS AND LINK FINDING"
if has_script "jsrecon.sh" && has_file "$SUBDOMAINS_FILE"; then
    echo "[*] Running jsrecon.sh with subdomains list..."
    bash "$SCRIPT_DIR/jsrecon.sh" "$SUBDOMAINS_FILE"
    sleep 5
elif has_script "jsrecon.sh"; then
    echo "[*] Running jsrecon.sh with domain only..."
    bash "$SCRIPT_DIR/jsrecon.sh" "$DOMAIN"
    sleep 5
else
    echo "[-] jsrecon.sh skipped: missing script."
fi

if has_file "findurls.txt"; then
    cat findurls.txt >> "$JS_FILE"
    sort -u "$JS_FILE" -o "$JS_FILE"
    echo "[+] jsrecon findurls.txt appended to js.txt"
fi

log "STEP 14: XSS SCAN"
if has_script "xssrecon.sh" && has_file "parameters.txt"; then
    echo "[*] Running xssrecon.sh on parameters.txt..."
    bash "$SCRIPT_DIR/xssrecon.sh" "parameters.txt"
    sleep 5
else
    echo "[-] xssrecon.sh skipped: missing script or parameters.txt."
fi

log "STEP 15: SQL INJECTION SCAN"
if has_script "sqlrecon.sh" && has_file "parameters.txt"; then
    echo "[*] Running sqlrecon.sh on parameters.txt..."
    bash "$SCRIPT_DIR/sqlrecon.sh" "parameters.txt"
    sleep 5
else
    echo "[-] sqlrecon.sh skipped: missing script or parameters.txt."
fi

log "STEP 16: COMMAND INJECTION SCAN"
if has_script "commixrecon.sh" && has_file "parameters.txt"; then
    echo "[*] Running cmdirecon.sh on parameters.txt..."
    bash "$SCRIPT_DIR/commixrecon.sh" "parameters.txt"
    sleep 5
else
    echo "[-] commixrecon.sh skipped: missing script or parameters.txt."
fi

log "STEP 17: HTTP REQUEST SMUGGLING SCAN"
if has_script "smugglerrecon.sh" && has_file "$SUBDOMAINS_FILE"; then
    echo "[*] Running smugglerrecon.sh on subdomains.txt..."
    bash "$SCRIPT_DIR/smugglerrecon.sh" "$SUBDOMAINS_FILE"
    sleep 5
else
    echo "[-] smugglerrecon.sh skipped: missing script or subdomains.txt."
fi

log "FULL RECON COMPLETE"

echo ""
echo "[+] Output files summary:"
for f in subdomains.txt activesubs.txt ips.txt ipsv6.txt urls.txt curls.txt findurls.txt \
          burl.txt parameters.txt js.txt tech.txt vulnerable_urls.txt report.txt \
          nmapreport.txt subs.txt cleanedsubs.txt validsubs.txt xssreport.txt \
          sqlreport.txt cmdireport.txt smugglerreport.txt secretsreport.txt karmareport.txt; do
    if has_file "$f"; then
        echo "    $f — $(wc -l < "$f") lines"
    fi
done