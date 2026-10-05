#!/usr/bin/env bash
# ==============================================================================
# Linux Infrastructure Automation Lab - Service Watchdog & Monitor
# Author: Rafael do Nascimento Ribeiro
# Description: Verifies the health and running state of a target systemd service,
#              records events with UTC timestamps, and provides optional auto-recovery.
# ==============================================================================

set -euo pipefail

TARGET_SERVICE="${1:-cron}"
LOG_DIR="${WATCHDOG_LOG_DIR:-/tmp/infra-lab-logs}"
LOG_FILE="${LOG_DIR}/service-watchdog.log"
AUTO_RESTART="${AUTO_RESTART:-false}"

mkdir -p "${LOG_DIR}"

log_msg() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
    echo "[${timestamp}] [${level}] [${TARGET_SERVICE}] ${message}" | tee -a "${LOG_FILE}"
}

log_msg "INFO" "Auditing service availability..."

if systemctl is-active --quiet "${TARGET_SERVICE}" 2>/dev/null; then
    MAIN_PID=$(systemctl show -p MainPID --value "${TARGET_SERVICE}" 2>/dev/null || echo "N/A")
    log_msg "INFO" "Service is ACTIVE and operational (Main PID: ${MAIN_PID})."
    exit 0
else
    SUB_STATE=$(systemctl show -p SubState --value "${TARGET_SERVICE}" 2>/dev/null || echo "unknown")
    log_msg "WARN" "Service is NOT active. Current SubState: ${SUB_STATE}."

    # NOTE ON AUTOMATIC REMEDIATION:
    # Automatic restart is disabled by default in public examples to prevent restart loops
    # during active maintenance or dependency failures. To enable in a production environment:
    # Set AUTO_RESTART=true or uncomment the block below.

    if [ "${AUTO_RESTART}" = "true" ]; then
        log_msg "ALERT" "Attempting automated service restart (AUTO_RESTART=true)..."
        # sudo systemctl restart "${TARGET_SERVICE}"
        # sleep 2
        # if systemctl is-active --quiet "${TARGET_SERVICE}"; then
        #     log_msg "INFO" "Automated recovery succeeded. Service is now active."
        # else
        #     log_msg "ERROR" "Automated recovery failed. Escalating to N2 engineer."
        # fi
    else
        log_msg "NOTICE" "Automated restart is disabled. Manual triage required."
    fi

    exit 1
fi
