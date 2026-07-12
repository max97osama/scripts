#!/bin/bash
# checkcms.sh - CH Media recon: Drupal (Apache/nginx) + IIS playbook, redirect-safe
# Usage: ./checkcms.sh

DOMAINS_APACHE_NGINX=(
  "vsdruck.ch"
  "chmediaprint.ch"
  "affolteranzeiger.ch"
  "grenchnerstadtanzeiger.ch"
  "limmatwelle.ch"
  "wochenblatt.ch"
  "azeiger.ch"
)

DOMAINS_IIS=(
  "azvertrieb.ch"
  "landanzeiger.ch"
  "wiggertaler.ch"
)

DOMAINS_UNKNOWN=(
  "vsvertrieb.ch"
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

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

check_liveness() {
  local domain="$1"
  # -L follows redirects so we see the REAL final page's headers, not the redirect's
  headers=$(curl -sIL -m 10 "https://$domain" 2>/dev/null)
  status=$(echo "$headers" | grep -i "^HTTP" | tail -1 | awk '{print $2}')
  if [ -z "$status" ]; then
    echo -e "  ${RED}[DOWN/unreachable]${NC}"
    return 1
  fi
  echo "  Final status: $status"
  server=$(echo "$headers" | grep -i "^server:" | tail -1 | tr -d '\r')
  powered=$(echo "$headers" | grep -i "^x-powered-by:" | tail -1 | tr -d '\r')
  aspnet=$(echo "$headers" | grep -i "^x-aspnet-version:" | tail -1 | tr -d '\r')
  [ -n "$server" ] && echo "  $server"
  [ -n "$powered" ] && echo "  $powered"
  [ -n "$aspnet" ] && echo "  $aspnet"

  for h in "x-frame-options" "content-security-policy" "x-content-type-options"; do
    if ! echo "$headers" | grep -qi "^$h:"; then
      echo -e "  ${RED}[MISSING] $h${NC}"
    fi
  done
  return 0
}

drupal_checks() {
  local domain="$1"
  for p in "${PATHS_VERSION[@]}"; do
    code=$(curl -s -o /tmp/dc_resp -w "%{http_code}" -L -m 10 "https://$domain/$p")
    if [ "$code" == "200" ]; then
      echo -e "  ${GREEN}[FOUND] /$p (200)${NC}"
      head -3 /tmp/dc_resp 2>/dev/null
    fi
  done
  for p in "${PATHS_EXPOSED[@]}"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -L -m 10 "https://$domain/$p")
    if [ "$code" == "200" ]; then
      echo -e "  ${RED}[EXPOSED] /$p (200)${NC}"
    fi
  done
  reg_code=$(curl -s -o /dev/null -w "%{http_code}" -L -m 10 "https://$domain/user/register")
  if [ "$reg_code" == "200" ]; then
    echo -e "  ${YELLOW}[MANUAL CHECK] /user/register live (200) — test PATO manually${NC}"
  fi
}

iis_checks() {
  local domain="$1"
  trace_code=$(curl -s -o /dev/null -w "%{http_code}" -L -m 10 -X TRACE "https://$domain")
  if [ "$trace_code" == "200" ]; then
    echo -e "  ${RED}[HTTP TRACE enabled] (200) — possible XST vector${NC}"
  fi
  propfind_code=$(curl -s -o /dev/null -w "%{http_code}" -L -m 10 -X PROPFIND "https://$domain")
  if [ "$propfind_code" == "207" ] || [ "$propfind_code" == "200" ]; then
    echo -e "  ${RED}[WebDAV PROPFIND responded] ($propfind_code) — check if WebDAV is enabled${NC}"
  fi
  # common IIS/legacy leftover paths
  for p in "web.config" "trace.axd" "elmah.axd"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" -L -m 10 "https://$domain/$p")
    if [ "$code" == "200" ]; then
      echo -e "  ${RED}[EXPOSED] /$p (200)${NC}"
    fi
  done
}

echo "=== CH Media Recon — $(date) ==="

echo -e "\n${BLUE}--- Apache/nginx cluster (Drupal candidates) ---${NC}"
for domain in "${DOMAINS_APACHE_NGINX[@]}"; do
  echo -e "${YELLOW}### $domain ###${NC}"
  check_liveness "$domain" && drupal_checks "$domain"
  echo ""
  sleep 2
done

echo -e "\n${BLUE}--- IIS cluster (ASP.NET/ARR) ---${NC}"
for domain in "${DOMAINS_IIS[@]}"; do
  echo -e "${YELLOW}### $domain ###${NC}"
  check_liveness "$domain" && iis_checks "$domain"
  echo ""
  sleep 2
done

echo -e "\n${BLUE}--- Unknown/unresolved — confirm liveness + scope before testing ---${NC}"
for domain in "${DOMAINS_UNKNOWN[@]}"; do
  echo -e "${YELLOW}### $domain ###${NC}"
  check_liveness "$domain"
  echo "  dig result:"
  dig +short "$domain" 2>/dev/null | sed 's/^/    /'
  echo ""
  sleep 2
done

rm -f /tmp/dc_resp
echo "=== Done ==="
