#!/usr/bin/env bash
# ==============================================================================
# Linux Infrastructure Automation Lab - Network & Connectivity Checker
# Author: Rafael do Nascimento Ribeiro
# Description: Verifies DNS resolution, gateway reachability, and evaluates
#              target ports/endpoints without hardcoded internal IP addresses.
# ==============================================================================

set -euo pipefail

# Configurable parameters (override via arguments or environment variables)
DNS_TEST_HOST="${1:-one.one.one.one}"
TARGET_HOST="${2:-dns.google}"
TARGET_PORTS="${3:-80,443}"

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}================================================================${RESET}"
echo -e "${BOLD}              NETWORK CONNECTIVITY & DNS AUDIT                 ${RESET}"
echo -e "${BOLD}================================================================${RESET}"

# ------------------------------------------------------------------------------
# 1. Default Route / Gateway Detection
# ------------------------------------------------------------------------------
echo -e "${BOLD}[1/3] Gateway & Route Verification${RESET}"
DEFAULT_GW=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1 || echo "")
DEFAULT_DEV=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1 || echo "")

if [ -n "${DEFAULT_GW}" ] && [ -n "${DEFAULT_DEV}" ]; then
    echo -e "  Default Interface: ${DEFAULT_DEV}"
    echo -e "  Gateway Status   : Gateway configured"
    
    # Ping gateway with short timeout (1 packet, 1s timeout)
    if ping -c 1 -W 1 "${DEFAULT_GW}" >/dev/null 2>&1; then
        echo -e "  Gateway Ping     : ${GREEN}REACHABLE${RESET}"
    else
        echo -e "  Gateway Ping     : ${YELLOW}NO ICMP ECHO (ICMP may be filtered)${RESET}"
    fi
else
    echo -e "  Gateway Status   : ${RED}NO DEFAULT GATEWAY FOUND${RESET}"
fi

# ------------------------------------------------------------------------------
# 2. DNS Resolution Test
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[2/3] DNS Resolution Test${RESET}"
echo -e "  Resolving Target : ${DNS_TEST_HOST}"

if command -v getent >/dev/null 2>&1; then
    if RESOLVED_IP=$(getent ahosts "${DNS_TEST_HOST}" 2>/dev/null | awk '{print $1}' | head -n1); then
        if [ -n "${RESOLVED_IP}" ]; then
            echo -e "  Resolution Status: ${GREEN}SUCCESSFUL${RESET} (Resolved to ${RESOLVED_IP})"
        else
            echo -e "  Resolution Status: ${RED}FAILED${RESET} (Empty response)"
        fi
    else
        echo -e "  Resolution Status: ${RED}FAILED${RESET} (Name resolution error)"
    fi
else
    if ping -c 1 -W 2 "${DNS_TEST_HOST}" >/dev/null 2>&1; then
        echo -e "  Resolution Status: ${GREEN}SUCCESSFUL${RESET} (Host reachable)"
    else
        echo -e "  Resolution Status: ${RED}FAILED${RESET}"
    fi
fi

# ------------------------------------------------------------------------------
# 3. Port & Transport Layer Connectivity
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[3/3] Port Accessibility Test (Target: ${TARGET_HOST})${RESET}"
IFS=',' read -ra PORTS <<< "${TARGET_PORTS}"

for port in "${PORTS[@]}"; do
    port=$(echo "${port}" | xargs)
    if [ -z "${port}" ]; then continue; fi

    # Use nc, timeout with bash /dev/tcp, or curl
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/${TARGET_HOST}/${port}" 2>/dev/null; then
        echo -e "  - TCP Port ${port} : ${GREEN}OPEN / REACHABLE${RESET}"
    else
        echo -e "  - TCP Port ${port} : ${RED}CLOSED / FILTERED / UNREACHABLE${RESET}"
    fi
done

echo -e "\n${BOLD}================================================================${RESET}"
echo -e "Audit completed successfully."
