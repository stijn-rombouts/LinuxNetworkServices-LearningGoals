#!/usr/bin/env bash
# ==============================================================================
# Endpoint Security Automated Audit Runner (Lynis)
# Learning Goal 11.10: Endpoint Security Testing & Hardening
# Scanner: Lynis (Evaluates 250+ Unix security tests & Hardening Index)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="${BASE_DIR}/reports"
mkdir -p "$REPORTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD}       Automated Endpoint Security Audit Runner (Lynis)             ${NC}"
echo -e "${BLUE}${BOLD}====================================================================${NC}"

if ! command -v lynis >/dev/null 2>&1; then
    echo -e "${YELLOW}[INFO] Lynis not installed. Installing lynis via apt...${NC}"
    sudo apt update -qq && sudo apt install -y -qq lynis || {
        echo -e "${RED}[ERROR] Failed to install Lynis. Please run: sudo apt install lynis${NC}"
        exit 1
    }
fi

echo -e "${GREEN}[OK] Using Lynis binary at: $(which lynis)${NC}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${REPORTS_DIR}/lynis_report_${TIMESTAMP}.txt"
DATA_FILE="${REPORTS_DIR}/lynis_data_${TIMESTAMP}.dat"

echo -e "\n${BOLD}Starting Lynis Full System Audit (Non-Interactive)...${NC}"
echo -e "Writing audit log to: ${CYAN}${REPORT_FILE}${NC}\n"

# Run Lynis in non-interactive quick mode
sudo lynis audit system \
    --quick \
    --report-file "$DATA_FILE" \
    --log-file "${REPORTS_DIR}/lynis_${TIMESTAMP}.log" | tee "$REPORT_FILE" || true

echo -e "\n${BLUE}====================================================================${NC}"
echo -e "${BOLD}                     AUDIT RESULTS OVERVIEW                         ${NC}"
echo -e "${BLUE}====================================================================${NC}"

if [ -f "$DATA_FILE" ]; then
    INDEX=$(grep "^hardening_index=" "$DATA_FILE" | cut -d= -f2 || echo "N/A")
    TESTS=$(grep "^tests_executed=" "$DATA_FILE" | cut -d= -f2 || echo "N/A")
    OS=$(grep "^os=" "$DATA_FILE" | cut -d= -f2 || echo "N/A")
    OS_VER=$(grep "^os_version=" "$DATA_FILE" | cut -d= -f2 || echo "N/A")
    
    echo -e "Target OS           : ${BOLD}${OS} ${OS_VER}${NC}"
    echo -e "Total Tests Run     : ${BOLD}${TESTS}${NC}"
    echo -e "Hardening Index     : ${BOLD}${CYAN}${INDEX} / 100${NC}"
fi

echo -e "\n${YELLOW}${BOLD}Top Warnings Detected in /var/log/lynis-report.dat:${NC}"
if [ -f "$DATA_FILE" ]; then
    grep "^warning\[\]=" "$DATA_FILE" | head -n 10 | while read -r line; do
        warn_text=$(echo "$line" | cut -d= -f2 | cut -d'|' -f1)
        test_id=$(echo "$line" | cut -d'|' -f2 2>/dev/null || echo "")
        echo -e "  [${RED}!${NC}] ${warn_text} (${test_id})"
    done
fi

echo -e "\n${BLUE}====================================================================${NC}"
echo -e "Full Audit Output : ${REPORT_FILE}"
echo -e "Full Machine Data : ${DATA_FILE}"
echo -e "${BLUE}====================================================================${NC}\n"
