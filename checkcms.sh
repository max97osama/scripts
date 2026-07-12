#!/bin/bash
# drupalcheck.sh - CH Media Drupal recon across low-competition scope
# Usage: ./drupalcheck.sh

DOMAINS=(
  "vsdruck.ch"
  "chmediaprint.ch"
  "azvertrieb.ch"
  "vsvertrieb.ch"
  "affolteranzeiger.ch"
  "azeiger.ch"
  "grenchnerstadtanzeiger.ch"
  "landanzeiger.ch"
  "limmatwelle.ch"
  "wiggertaler.ch"
  "wochenblatt.ch"
  "amtliche-nachrichten.ch"
)

PATHS_VERSION=(
  "CHANGELOG.txt"
  "core/CHANGELOG.txt"
  "composer.lock"
)

PATHS_EXPOSED=(
  "sites/default/settings.php.bak"
  "sites/default/settings.php~"
  ".git/config"
  "sites/default/files/"
  "jsonapi/node/article"
)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo "=== CH Media Drupal Recon — $(date) ==="
echo ""

for domain in "${DOMAINS[@]}"; do
  echo -e "${YELLOW}### $domain ###${NC}"

  # 1. Live check + headers
  headers=$(curl -sI -m 10 "https://$domain" 2>/dev/null)
  status=$(echo "$headers" | head -1 | awk '{print $2}')
  if [ -z "$status" ]; then
    echo -e "  ${RED}[DOWN/unreachable]${NC}"
    echo ""
    continue
  fi
  echo "  Status: $status"

  server=$(echo "$headers" | grep -i "^server:" | tr -d '\r')
  powered=$(echo "$headers" | grep -i "^x-powered-by:" | tr -d '\r')
  [ -n "$server" ] && echo "  $server"
  [ -n "$powered" ] && echo "  $powered"

  # Flag missing security headers
  for h in "x-frame-options" "content-security-policy" "x-content-type-options"; do
    if ! echo "$headers" | grep -qi "^$h:"; then
      echo -e "  ${RED}[MISSING] $h${NC}"
    fi
  done

  # 2. Version fingerprint
  for p in "${PATHS_VERSION[@]}"; do
    code=$(curl -s -o /tmp/dc_resp -w "%{http_code}" -m 10 "https://$domain/$p")
    if [ "$code" == "200" ]; then
      echo -e "  ${GREEN}[FOUND] /$p (200)${NC}"
      grep -m1 -i "version" /tmp/dc_resp 2>/dev/null | head -1
    fi
  done

  # 3. Exposed files / JSON:API
  for p in "${PATHS_EXPOSED[@]}"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "https://$domain/$p")
    if [ "$code" == "200" ]; then
      echo -e "  ${RED}[EXPOSED] /$p (200)${NC}"
    fi
  done

  # 4. Register endpoint present? (manual PATO check needed after this)
  reg_code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "https://$domain/user/register")
  if [ "$reg_code" == "200" ]; then
    echo -e "  ${YELLOW}[MANUAL CHECK] /user/register live (200) — test PATO manually${NC}"
  fi

  echo ""
  sleep 2   # be polite, avoid tripping WAF/rate-limit
done

rm -f /tmp/dc_resp
echo "=== Done ==="