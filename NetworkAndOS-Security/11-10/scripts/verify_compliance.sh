#!/usr/bin/env bash
# ==============================================================================
# CIS Benchmark Compliance Verification Tool (Profile Level 1 - Server)
# Learning Goal 11.10: Endpoint Security Testing & Hardening
# Standard: CIS Debian Linux 13 Benchmark v1.1.0 (Level 1 - Server)
# ==============================================================================

set -uo pipefail

export PATH="$PATH:/sbin:/usr/sbin:/usr/local/sbin"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

print_header() {
    echo -e "${BLUE}${BOLD}====================================================================${NC}"
    echo -e "${CYAN}${BOLD}   CIS Debian Linux 13 Benchmark Audit (Profile Level 1 - Server)   ${NC}"
    echo -e "${BLUE}${BOLD}====================================================================${NC}"
    echo -e "Host: $(hostname) | Kernel: $(uname -r) | Date: $(date -u)"
    echo -e "Distribution: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"' || echo 'Linux')"
    echo -e "Guideline: CIS_Debian_Linux_13_Benchmark_v1.1.0.pdf (Level 1 - Server)"
    echo -e "${BLUE}--------------------------------------------------------------------${NC}\n"
}

check_result() {
    local id="$1"
    local desc="$2"
    local status="$3"
    local details="${4:-}"
    
    TOTAL=$((TOTAL + 1))
    if [ "$status" = "PASS" ]; then
        echo -e "[ ${GREEN}PASS${NC} ] ${BOLD}${id}${NC}: ${desc}"
        PASSED=$((PASSED + 1))
    elif [ "$status" = "WARN" ]; then
        echo -e "[ ${YELLOW}WARN${NC} ] ${BOLD}${id}${NC}: ${desc} (${details})"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "[ ${RED}FAIL${NC} ] ${BOLD}${id}${NC}: ${desc} (${details})"
        FAILED=$((FAILED + 1))
    fi
}

check_sysctl() {
    local id="$1"
    local desc="$2"
    local param="$3"
    local expected="$4"
    local actual
    
    actual=$(sysctl -n "$param" 2>/dev/null || true)
    if [ -z "$actual" ]; then
        local proc_path="/proc/sys/${param//.//}"
        if [ -r "$proc_path" ]; then
            actual=$(cat "$proc_path" 2>/dev/null || true)
        fi
    fi
    actual="${actual:-missing}"
    
    if [ "$actual" = "$expected" ]; then
        check_result "$id" "$desc" "PASS"
    else
        check_result "$id" "$desc" "FAIL" "expected $expected, got $actual"
    fi
}

check_sysctl_ge() {
    local id="$1"
    local desc="$2"
    local param="$3"
    local min_val="$4"
    local actual
    
    actual=$(sysctl -n "$param" 2>/dev/null || true)
    if [ -z "$actual" ]; then
        local proc_path="/proc/sys/${param//.//}"
        if [ -r "$proc_path" ]; then
            actual=$(cat "$proc_path" 2>/dev/null || true)
        fi
    fi
    actual="${actual:-missing}"
    
    if [[ "$actual" =~ ^[0-9]+$ ]] && [ "$actual" -ge "$min_val" ]; then
        check_result "$id" "$desc" "PASS"
    else
        check_result "$id" "$desc" "FAIL" "expected >= $min_val, got $actual"
    fi
}

check_file_perm() {
    local id="$1"
    local desc="$2"
    local file="$3"
    local max_perm="$4"
    local expected_owner="$5"

    if [ ! -e "$file" ]; then
        check_result "$id" "$desc" "WARN" "file does not exist"
        return
    fi

    local actual_perm actual_owner actual_uid
    actual_perm=$(stat -c "%a" "$file" 2>/dev/null || echo "000")
    actual_owner=$(stat -c "%U:%G" "$file" 2>/dev/null || echo "none")
    actual_uid=$(stat -c "%u" "$file" 2>/dev/null || echo "999")

    if [ "$actual_perm" -le "$max_perm" ] && { [[ "$actual_owner" == "$expected_owner"* ]] || [ "$actual_uid" -eq 0 ] || [[ "$actual_owner" == "nobody:nogroup" ]]; }; then
        check_result "$id" "$desc" "PASS"
    else
        check_result "$id" "$desc" "FAIL" "perms: $actual_perm (max $max_perm), owner: $actual_owner (exp $expected_owner)"
    fi
}

check_module_disabled() {
    local id="$1"
    local desc="$2"
    local module="$3"
    
    local loaded config
    loaded=$(lsmod 2>/dev/null | grep -E "^${module}\b" || true)
    config=$(modprobe --showconfig 2>/dev/null | grep -E "install\s+${module}\s+/bin/(true|false)" || true)

    if [ -z "$loaded" ] && [ -n "$config" ]; then
        check_result "$id" "$desc" "PASS"
    elif [ -z "$loaded" ]; then
        check_result "$id" "$desc" "WARN" "module not loaded but install /bin/false not in modprobe.d"
    else
        check_result "$id" "$desc" "FAIL" "module is actively loaded in kernel"
    fi
}

check_sshd_config() {
    local id="$1"
    local desc="$2"
    local param="$3"
    local expected="$4"
    
    if [ ! -f /etc/ssh/sshd_config ] && [ ! -d /etc/ssh/sshd_config.d ]; then
        check_result "$id" "$desc" "WARN" "OpenSSH server is not installed"
        return
    fi

    local actual=""
    if command -v sshd >/dev/null 2>&1; then
        actual=$(sshd -T 2>/dev/null | grep -i "^${param} " | head -n1 | awk '{print $2}' || true)
    fi
    if [ -z "$actual" ]; then
        if [ -f /etc/ssh/sshd_config ]; then
            actual=$(grep -Ei "^\s*${param}\s+" /etc/ssh/sshd_config 2>/dev/null | head -n1 | awk '{print $2}' || true)
        fi
        if [ -z "$actual" ] && [ -d /etc/ssh/sshd_config.d ]; then
            actual=$(grep -Eih "^\s*${param}\s+" /etc/ssh/sshd_config.d/*.conf 2>/dev/null | head -n1 | awk '{print $2}' || true)
        fi
    fi
    actual="${actual:-unset}"
    actual=$(echo "$actual" | tr -d '[:space:]')

    if [ "${actual,,}" = "${expected,,}" ]; then
        check_result "$id" "$desc" "PASS"
    else
        check_result "$id" "$desc" "FAIL" "expected ${expected}, got ${actual:-unset}"
    fi
}

check_package_absent() {
    local id="$1"
    local desc="$2"
    local pkg="$3"
    
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        check_result "$id" "$desc" "FAIL" "package $pkg is installed"
    else
        check_result "$id" "$desc" "PASS"
    fi
}

check_package_installed() {
    local id="$1"
    local desc="$2"
    local pkg="$3"
    
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        check_result "$id" "$desc" "PASS"
    else
        check_result "$id" "$desc" "FAIL" "package $pkg is not installed"
    fi
}

check_service_enabled() {
    local id="$1"
    local desc="$2"
    local srv="$3"
    
    if systemctl is-enabled "$srv" 2>/dev/null | grep -E -q "(enabled|active)"; then
        check_result "$id" "$desc" "PASS"
    else
        check_result "$id" "$desc" "FAIL" "service $srv is not enabled"
    fi
}

check_service_disabled() {
    local id="$1"
    local desc="$2"
    local srv="$3"
    
    if systemctl is-enabled "$srv" 2>/dev/null | grep -E -q "(enabled|active)"; then
        check_result "$id" "$desc" "FAIL" "service $srv is enabled"
    else
        check_result "$id" "$desc" "PASS"
    fi
}

run_audit() {
    print_header

    echo -e "${BOLD}--- Domain 1: Initial Setup & Kernel Security ---${NC}"
    check_module_disabled "CIS 1.1.1.1" "Ensure cramfs module is disabled" "cramfs"
    check_module_disabled "CIS 1.1.1.2" "Ensure freevxfs module is disabled" "freevxfs"
    check_module_disabled "CIS 1.1.1.3" "Ensure hfs module is disabled" "hfs"
    check_module_disabled "CIS 1.1.1.4" "Ensure hfsplus module is disabled" "hfsplus"
    check_module_disabled "CIS 1.1.1.5" "Ensure jffs2 module is disabled" "jffs2"
    check_module_disabled "CIS 1.1.1.8" "Ensure udf module is disabled" "udf"
    check_sysctl "CIS 1.5.1" "Ensure ASLR is enabled" "kernel.randomize_va_space" "2"
    check_sysctl_ge "CIS 1.5.2" "Ensure ptrace scope is restricted" "kernel.yama.ptrace_scope" "1"
    check_sysctl "CIS 1.5.3" "Ensure core dumps are restricted (fs.suid_dumpable)" "fs.suid_dumpable" "0"
    check_sysctl "CIS 1.5.5" "Ensure kernel.dmesg_restrict is enabled" "kernel.dmesg_restrict" "1"
    check_sysctl_ge "CIS 1.5.8" "Ensure kernel.kptr_restrict is enabled" "kernel.kptr_restrict" "1"
    check_sysctl "CIS 1.5.9" "Ensure fs.protected_hardlinks is enabled" "fs.protected_hardlinks" "1"
    check_sysctl "CIS 1.5.9" "Ensure fs.protected_symlinks is enabled" "fs.protected_symlinks" "1"
    check_sysctl "CIS 1.5.9" "Ensure fs.protected_fifos is configured" "fs.protected_fifos" "2"
    check_sysctl "CIS 1.5.9" "Ensure fs.protected_regular is configured" "fs.protected_regular" "2"
    check_file_perm "CIS 1.6.1" "Ensure permissions on /etc/motd are 644 or less" "/etc/motd" "644" "root"
    check_file_perm "CIS 1.6.2" "Ensure permissions on /etc/issue are 644 or less" "/etc/issue" "644" "root"
    check_file_perm "CIS 1.6.3" "Ensure permissions on /etc/issue.net are 644 or less" "/etc/issue.net" "644" "root"

    echo -e "\n${BOLD}--- Domain 2: Services & Daemon Minimization ---${NC}"
    check_service_disabled "CIS 2.2.2" "Ensure Avahi daemon is disabled" "avahi-daemon"
    check_service_disabled "CIS 2.2.3" "Ensure CUPS print service is disabled" "cups"
    check_service_disabled "CIS 2.2.4" "Ensure ISC DHCP server is disabled" "isc-dhcp-server"
    check_package_absent "CIS 2.3.1" "Ensure NIS client is not installed" "nis"
    check_package_absent "CIS 2.3.2" "Ensure rsh client is not installed" "rsh-client"
    check_package_absent "CIS 2.3.3" "Ensure talk client is not installed" "talk"
    check_package_absent "CIS 2.3.4" "Ensure telnet client is not installed" "telnet"

    echo -e "\n${BOLD}--- Domain 3: Network Configuration (Kernel Sysctl) ---${NC}"
    check_sysctl "CIS 3.1.1" "Ensure packet forwarding is disabled (IPv4)" "net.ipv4.ip_forward" "0"
    check_sysctl "CIS 3.2.1" "Ensure packet redirect sending is disabled (all)" "net.ipv4.conf.all.send_redirects" "0"
    check_sysctl "CIS 3.2.1" "Ensure packet redirect sending is disabled (default)" "net.ipv4.conf.default.send_redirects" "0"
    check_sysctl "CIS 3.2.2" "Ensure IP source routing is disabled (all)" "net.ipv4.conf.all.accept_source_route" "0"
    check_sysctl "CIS 3.2.2" "Ensure IP source routing is disabled (default)" "net.ipv4.conf.default.accept_source_route" "0"
    check_sysctl "CIS 3.2.3" "Ensure ICMP redirects are not accepted (all)" "net.ipv4.conf.all.accept_redirects" "0"
    check_sysctl "CIS 3.2.3" "Ensure ICMP redirects are not accepted (default)" "net.ipv4.conf.default.accept_redirects" "0"
    check_sysctl "CIS 3.2.4" "Ensure secure ICMP redirects are not accepted (all)" "net.ipv4.conf.all.secure_redirects" "0"
    check_sysctl "CIS 3.2.4" "Ensure secure ICMP redirects are not accepted (default)" "net.ipv4.conf.default.secure_redirects" "0"
    check_sysctl "CIS 3.2.5" "Ensure suspicious packets (martians) are logged (all)" "net.ipv4.conf.all.log_martians" "1"
    check_sysctl "CIS 3.2.5" "Ensure suspicious packets (martians) are logged (default)" "net.ipv4.conf.default.log_martians" "1"
    check_sysctl "CIS 3.2.6" "Ensure broadcast ICMP requests are ignored" "net.ipv4.icmp_echo_ignore_broadcasts" "1"
    check_sysctl "CIS 3.2.7" "Ensure bogus ICMP responses are ignored" "net.ipv4.icmp_ignore_bogus_error_responses" "1"
    check_sysctl "CIS 3.2.8" "Ensure Reverse Path Filtering is enabled (all)" "net.ipv4.conf.all.rp_filter" "1"
    check_sysctl "CIS 3.2.8" "Ensure Reverse Path Filtering is enabled (default)" "net.ipv4.conf.default.rp_filter" "1"
    check_sysctl "CIS 3.2.9" "Ensure TCP SYN Cookies is enabled" "net.ipv4.tcp_syncookies" "1"
    check_sysctl "CIS 3.2.10" "Ensure IPv6 router advertisements not accepted (all)" "net.ipv6.conf.all.accept_ra" "0"
    check_sysctl "CIS 3.2.10" "Ensure IPv6 router advertisements not accepted (default)" "net.ipv6.conf.default.accept_ra" "0"

    echo -e "\n${BOLD}--- Domain 5: Access Control & SSH Server Hardening ---${NC}"
    check_sshd_config "CIS 5.2.2" "Ensure SSH PermitRootLogin is disabled" "permitrootlogin" "no"
    check_sshd_config "CIS 5.2.4" "Ensure SSH MaxAuthTries is 4 or less" "maxauthtries" "4"
    check_sshd_config "CIS 5.2.6" "Ensure SSH PermitEmptyPasswords is disabled" "permitemptypasswords" "no"
    check_sshd_config "CIS 5.2.11" "Ensure SSH X11Forwarding is disabled" "x11forwarding" "no"
    check_sshd_config "CIS 5.2.14" "Ensure SSH ClientAliveInterval is configured" "clientaliveinterval" "300"
    check_sshd_config "CIS 5.2.15" "Ensure SSH ClientAliveCountMax is 3 or less" "clientalivecountmax" "3"
    check_sshd_config "CIS 5.2.16" "Ensure SSH LoginGraceTime is 60 or less" "logingracetime" "60"
    check_package_installed "CIS 5.3.1" "Ensure pam_pwquality is installed" "libpam-pwquality"
    
    local umask_val
    umask_val=$(grep -E "^UMASK\s+" /etc/login.defs 2>/dev/null | awk '{print $2}' || true)
    if [ "$umask_val" = "027" ]; then
        check_result "CIS 5.4.4" "Ensure default user umask is 027 in login.defs" "PASS"
    else
        check_result "CIS 5.4.4" "Ensure default user umask is 027 in login.defs" "FAIL" "got ${umask_val:-unset}"
    fi

    local pass_max
    pass_max=$(grep -E "^PASS_MAX_DAYS\s+" /etc/login.defs 2>/dev/null | awk '{print $2}' || echo "99999")
    if [ "$pass_max" -le 365 ]; then
        check_result "CIS 5.4.1" "Ensure password expiration PASS_MAX_DAYS is 365 or less" "PASS"
    else
        check_result "CIS 5.4.1" "Ensure password expiration PASS_MAX_DAYS is 365 or less" "FAIL" "got $pass_max"
    fi

    echo -e "\n${BOLD}--- Domain 6: Logging, Auditing & System Permissions ---${NC}"
    check_file_perm "CIS 6.1.1" "Ensure permissions on /etc/passwd are 644 or less" "/etc/passwd" "644" "root"
    check_file_perm "CIS 6.1.2" "Ensure permissions on /etc/shadow are 640 or less" "/etc/shadow" "640" "root"
    check_file_perm "CIS 6.1.3" "Ensure permissions on /etc/group are 644 or less" "/etc/group" "644" "root"
    check_file_perm "CIS 6.1.4" "Ensure permissions on /etc/gshadow are 640 or less" "/etc/gshadow" "640" "root"
    check_package_installed "CIS 6.2.1.1" "Ensure auditd package is installed" "auditd"
    check_service_enabled "CIS 6.2.1.2" "Ensure auditd service is active and running" "auditd"

    echo -e "\n${BLUE}====================================================================${NC}"
    echo -e "${BOLD}                     AUDIT SUMMARY RESULTS                          ${NC}"
    echo -e "${BLUE}====================================================================${NC}"
    echo -e "Total Checks Executed : ${BOLD}${TOTAL}${NC}"
    echo -e "Passed Checks         : ${GREEN}${BOLD}${PASSED}${NC}"
    echo -e "Warnings              : ${YELLOW}${BOLD}${WARNINGS}${NC}"
    echo -e "Failed Checks         : ${RED}${BOLD}${FAILED}${NC}"
    
    local score=0
    if [ "$TOTAL" -gt 0 ]; then
        score=$(( (PASSED * 100) / TOTAL ))
    fi
    echo -e "Benchmark Compliance  : ${BOLD}${score}%${NC}"
    echo -e "${BLUE}====================================================================${NC}\n"
}

run_audit
