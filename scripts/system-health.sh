#!/usr/bin/env bash
# ==============================================================================
# Linux Infrastructure Automation Lab - System Health Checker
# Author: Rafael do Nascimento Ribeiro
# Description: Gathers key system performance indicators, disk utilization,
#              memory metrics, load averages, and monitors core services.
# ==============================================================================

set -euo pipefail

# Configurable monitored services list (override via SERVICES_LIST env var)
DEFAULT_SERVICES=("systemd-journald" "cron" "dbus" "systemd-logind")
IFS=',' read -ra MONITORED_SERVICES <<< "${SERVICES_LIST:-$(IFS=','; echo "${DEFAULT_SERVICES[*]}")}"

# Alert thresholds
CPU_THRESHOLD=80
MEM_THRESHOLD=85
DISK_THRESHOLD=90

# Formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}================================================================${RESET}"
echo -e "${BOLD}              SYSTEM HEALTH & RESOURCE AUDIT                   ${RESET}"
echo -e "${BOLD}================================================================${RESET}"
echo -e "Timestamp       : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo -e "Host Architecture: $(uname -s) $(uname -m) (Kernel $(uname -r))"
echo -e "Uptime          : $(uptime -p 2>/dev/null || uptime)"
echo ""

# ------------------------------------------------------------------------------
# 1. CPU & Load Average
# ------------------------------------------------------------------------------
echo -e "${BOLD}[1/4] CPU & Load Average${RESET}"
LOAD_1=$(awk '{print $1}' /proc/loadavg)
LOAD_5=$(awk '{print $2}' /proc/loadavg)
LOAD_15=$(awk '{print $3}' /proc/loadavg)
CPU_CORES=$(nproc)

echo -e "  Cores Available : ${CPU_CORES}"
echo -e "  Load Average    : ${LOAD_1} (1m), ${LOAD_5} (5m), ${LOAD_15} (15m)"

# ------------------------------------------------------------------------------
# 2. Memory Utilization
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[2/4] Memory Utilization${RESET}"
MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAIL_KB))
MEM_PERCENT=$((MEM_USED_KB * 100 / MEM_TOTAL_KB))

MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
MEM_USED_MB=$((MEM_USED_KB / 1024))
MEM_AVAIL_MB=$((MEM_AVAIL_KB / 1024))

if [ "${MEM_PERCENT}" -ge "${MEM_THRESHOLD}" ]; then
    MEM_STATUS="${RED}[ALERT] ${MEM_PERCENT}% used${RESET}"
elif [ "${MEM_PERCENT}" -ge 70 ]; then
    MEM_STATUS="${YELLOW}[WARN] ${MEM_PERCENT}% used${RESET}"
else
    MEM_STATUS="${GREEN}[OK] ${MEM_PERCENT}% used${RESET}"
fi

echo -e "  RAM Status      : ${MEM_STATUS}"
echo -e "  Usage Breakdown : ${MEM_USED_MB} MB used / ${MEM_TOTAL_MB} MB total (${MEM_AVAIL_MB} MB available)"

# ------------------------------------------------------------------------------
# 3. Storage & Filesystem Health
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[3/4] Root Filesystem Storage${RESET}"
DISK_LINE=$(df -h / | awk 'NR==2 {print $2, $3, $4, $5}')
read -r DISK_TOTAL DISK_USED DISK_AVAIL DISK_PERC_STR <<< "${DISK_LINE}"
DISK_PERC_NUM="${DISK_PERC_STR%%%}"

if [ "${DISK_PERC_NUM}" -ge "${DISK_THRESHOLD}" ]; then
    DISK_STATUS="${RED}[CRITICAL] ${DISK_PERC_STR} full${RESET}"
elif [ "${DISK_PERC_NUM}" -ge 75 ]; then
    DISK_STATUS="${YELLOW}[WARN] ${DISK_PERC_STR} full${RESET}"
else
    DISK_STATUS="${GREEN}[OK] ${DISK_PERC_STR} full${RESET}"
fi

echo -e "  Root Partition  : ${DISK_STATUS}"
echo -e "  Capacity        : ${DISK_USED} used / ${DISK_TOTAL} total (${DISK_AVAIL} free)"

# ------------------------------------------------------------------------------
# 4. Core System Services Status
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}[4/4] Essential Services Audit${RESET}"
ALL_HEALTHY=true

for svc in "${MONITORED_SERVICES[@]}"; do
    svc=$(echo "${svc}" | xargs)
    if [ -z "${svc}" ]; then continue; fi

    if systemctl is-active --quiet "${svc}" 2>/dev/null; then
        echo -e "  - ${svc%-service} : ${GREEN}ACTIVE (running)${RESET}"
    else
        echo -e "  - ${svc%-service} : ${RED}INACTIVE / FAILED${RESET}"
        ALL_HEALTHY=false
    fi
done

echo -e "\n${BOLD}================================================================${RESET}"
if [ "${ALL_HEALTHY}" = true ]; then
    echo -e "Audit Result    : ${GREEN}SYSTEM HEALTH HEALTHY${RESET}"
    exit 0
else
    echo -e "Audit Result    : ${YELLOW}ATTENTION REQUIRED ON ONE OR MORE SERVICES${RESET}"
    exit 1
fi
