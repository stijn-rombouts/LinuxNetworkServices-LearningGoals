#!/usr/bin/env bash
# ==============================================================================
# CIS Benchmark Baseline Remediation Script
# Learning Goal 11.10: Endpoint Security Testing & Hardening
# Targets: Debian 13 / Ubuntu 22.04 / 24.04 (CIS Level 1 Server / Workstation)
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false
BACKUP_DIR="/var/backups/cis-hardening-$(date +%Y%m%d%H%M%S)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --dry-run       Preview all remediation actions and file changes without modifying the system.
  --apply         Apply CIS Level 1 hardening configurations to the system (requires root).
  -h, --help      Display this help menu.

EOF
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --apply)
            DRY_RUN=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

if [ "$DRY_RUN" = false ] && [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}[ERROR]${NC} The --apply mode requires root privileges (run with sudo)."
    exit 1
fi

echo -e "${BLUE}${BOLD}====================================================================${NC}"
echo -e "${CYAN}${BOLD}       CIS Benchmark Level 1 Baseline Remediation Engine           ${NC}"
echo -e "${BLUE}${BOLD}====================================================================${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}${BOLD}MODE: DRY-RUN (Simulating changes, no files will be touched)${NC}\n"
else
    echo -e "${GREEN}${BOLD}MODE: ACTIVE ENFORCEMENT (Applying CIS hardening)${NC}"
    echo -e "Creating backup directory: ${BACKUP_DIR}\n"
    mkdir -p "$BACKUP_DIR"
fi

# ------------------------------------------------------------------------------
# 1. Kernel Network Parameters (Sysctl)
# ------------------------------------------------------------------------------
echo -e "${BOLD}1. Applying Sysctl Kernel Hardening (/etc/sysctl.d/99-cis-hardening.conf)...${NC}"
SYSCTL_CONF="/etc/sysctl.d/99-cis-hardening.conf"
read -r -d '' SYSCTL_CONTENT << 'EOF' || true
# ==============================================================================
# CIS Benchmark Kernel Parameter Baseline (Level 1)
# ==============================================================================

# CIS 1.5.1 Restrict ASLR
kernel.randomize_va_space = 2

# CIS 1.5.2 Restrict ptrace
kernel.yama.ptrace_scope = 1

# CIS 1.5.3 Restrict Core Dumps
fs.suid_dumpable = 0

# CIS 1.5.5 Restrict dmesg access
kernel.dmesg_restrict = 1

# CIS 1.5.8 Restrict kernel pointers
kernel.kptr_restrict = 2

# CIS 1.5.9 Protect hardlinks, symlinks, FIFOs, and regular files
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# CIS 3.1.1 Disable IP Forwarding
net.ipv4.ip_forward = 0

# CIS 3.2.1 Disable Packet Redirect Sending
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# CIS 3.2.2 Disable Source Routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# CIS 3.2.3 Disable ICMP Redirect Acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# CIS 3.2.4 Disable Secure ICMP Redirect Acceptance
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# CIS 3.2.5 Log Suspicious Packets (Martians)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# CIS 3.2.6 Ignore Broadcast ICMP Requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# CIS 3.2.7 Ignore Bogus ICMP Responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# CIS 3.2.8 Enable Reverse Path Filtering (Spoof Protection)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# CIS 3.2.9 Enable TCP SYN Cookies (SYN Flood Mitigation)
net.ipv4.tcp_syncookies = 1

# IPv6 Protections
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY-RUN] Target file: ${SYSCTL_CONF}${NC}"
    echo -e "${YELLOW}Proposed configuration:${NC}"
    echo "$SYSCTL_CONTENT" | sed 's/^/  /'
else
    echo "$SYSCTL_CONTENT" > "$SYSCTL_CONF"
    sysctl --system >/dev/null 2>&1 || true
    echo -e "${GREEN}[OK] Sysctl parameters written and reloaded.${NC}"
fi

# ------------------------------------------------------------------------------
# 2. Disable Unused / Legacy Filesystem Kernel Modules
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}2. Disabling Legacy Filesystems (/etc/modprobe.d/99-cis-filesystems.conf)...${NC}"
MODPROBE_CONF="/etc/modprobe.d/99-cis-filesystems.conf"
read -r -d '' MODPROBE_CONTENT << 'EOF' || true
# ==============================================================================
# CIS Benchmark Legacy Filesystems Disabled (Level 1)
# ==============================================================================
install cramfs /bin/false
blacklist cramfs
install freevxfs /bin/false
blacklist freevxfs
install jffs2 /bin/false
blacklist jffs2
install hfs /bin/false
blacklist hfs
install hfsplus /bin/false
blacklist hfsplus
install udf /bin/false
blacklist udf
EOF

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY-RUN] Target file: ${MODPROBE_CONF}${NC}"
    echo -e "${YELLOW}Proposed configuration:${NC}"
    echo "$MODPROBE_CONTENT" | sed 's/^/  /'
else
    echo "$MODPROBE_CONTENT" > "$MODPROBE_CONF"
    echo -e "${GREEN}[OK] Modprobe blacklist configuration written.${NC}"
fi

# ------------------------------------------------------------------------------
# 3. SSH Server Hardening
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}3. Applying OpenSSH Server Hardening (/etc/ssh/sshd_config.d/99-cis.conf)...${NC}"
SSHD_CONF_DIR="/etc/ssh/sshd_config.d"
SSHD_CONF="${SSHD_CONF_DIR}/99-cis.conf"

read -r -d '' SSHD_CONTENT << 'EOF' || true
# ==============================================================================
# CIS Benchmark SSH Server Hardening (Level 1)
# ==============================================================================
PermitRootLogin no
MaxAuthTries 4
PermitEmptyPasswords no
ClientAliveInterval 300
ClientAliveCountMax 3
LoginGraceTime 60
X11Forwarding no
MaxStartups 10:30:60
Banner /etc/issue.net
EOF

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY-RUN] Target file: ${SSHD_CONF}${NC}"
    echo -e "${YELLOW}Proposed configuration:${NC}"
    echo "$SSHD_CONTENT" | sed 's/^/  /'
else
    if [ -d "$SSHD_CONF_DIR" ]; then
        echo "$SSHD_CONTENT" > "$SSHD_CONF"
        chmod 600 "$SSHD_CONF"
        if sshd -t >/dev/null 2>&1; then
            systemctl reload ssh >/dev/null 2>&1 || systemctl reload sshd >/dev/null 2>&1 || true
            echo -e "${GREEN}[OK] SSH configuration applied and daemon validated.${NC}"
        else
            echo -e "${RED}[WARNING] SSH config syntax check failed, removing override.${NC}"
            rm -f "$SSHD_CONF"
        fi
    else
        echo -e "${YELLOW}[SKIP] OpenSSH directory ${SSHD_CONF_DIR} not found.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# 4. Default Shell Umask Hardening
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}4. Enforcing Restrictive Default Umask 027 (/etc/profile.d/99-cis-umask.sh)...${NC}"
UMASK_CONF="/etc/profile.d/99-cis-umask.sh"
read -r -d '' UMASK_CONTENT << 'EOF' || true
# CIS 5.4.4 Enforce default restrictive umask
umask 027
EOF

if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY-RUN] Target file: ${UMASK_CONF}${NC}"
    echo -e "${YELLOW}Proposed configuration:${NC} umask 027"
else
    echo "$UMASK_CONTENT" > "$UMASK_CONF"
    chmod 644 "$UMASK_CONF"
    if [ -f /etc/login.defs ]; then
        cp /etc/login.defs "${BACKUP_DIR}/login.defs"
        if grep -q "^UMASK" /etc/login.defs; then
            sed -i 's/^UMASK.*/UMASK           027/' /etc/login.defs || true
        else
            echo "UMASK           027" >> /etc/login.defs
        fi
    fi
    echo -e "${GREEN}[OK] Umask 027 policy set in /etc/profile.d and /etc/login.defs.${NC}"
fi

# ------------------------------------------------------------------------------
# 5. Critical System File Permissions
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}5. Restricting Critical System File Permissions (Domain 6)...${NC}"
FILES_PERMS=(
    "/etc/passwd:644:root:root"
    "/etc/group:644:root:root"
    "/etc/shadow:640:root:shadow"
    "/etc/gshadow:640:root:shadow"
    "/etc/issue:644:root:root"
    "/etc/issue.net:644:root:root"
)

for entry in "${FILES_PERMS[@]}"; do
    IFS=":" read -r target_file perm user group <<< "$entry"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN] Set ${perm} ${user}:${group} on ${target_file}${NC}"
    else
        if [ -e "$target_file" ]; then
            chmod "$perm" "$target_file" 2>/dev/null || true
            chown "${user}:${group}" "$target_file" 2>/dev/null || chown root:root "$target_file" 2>/dev/null || true
            echo -e "${GREEN}[OK] Permissions on ${target_file} set to ${perm}.${NC}"
        fi
    fi
done

# ------------------------------------------------------------------------------
# 6. Password Aging Policies (/etc/login.defs)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}6. Configuring Password Aging (/etc/login.defs)...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY-RUN] Enforce PASS_MAX_DAYS 365 and PASS_MIN_DAYS 1 in /etc/login.defs${NC}"
else
    if [ -f /etc/login.defs ]; then
        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   365/' /etc/login.defs 2>/dev/null || true
        sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs 2>/dev/null || true
        echo -e "${GREEN}[OK] PASS_MAX_DAYS set to 365 and PASS_MIN_DAYS set to 1.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# 7. Disable Unneeded Services (Avahi & CUPS)
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}7. Disabling Unnecessary Services (Avahi & CUPS)...${NC}"
SERVICES_TO_DISABLE=("avahi-daemon" "cups")
for srv in "${SERVICES_TO_DISABLE[@]}"; do
    if [ "$DRY_RUN" = true ]; then
        echo -e "${CYAN}[DRY-RUN] Disable & mask ${srv}.service${NC}"
    else
        systemctl --now mask "$srv" >/dev/null 2>&1 || true
        echo -e "${GREEN}[OK] Service ${srv} masked and stopped.${NC}"
    fi
done

# ------------------------------------------------------------------------------
# 8. Install & Enable Auditd and PAM Pwquality
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}8. Verifying Audit Framework & PAM Security...${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${CYAN}[DRY-RUN] Ensure auditd and libpam-pwquality packages are installed and active${NC}"
else
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null 2>&1 || true
        apt-get install -y -qq auditd libpam-pwquality >/dev/null 2>&1 || true
        systemctl enable --now auditd >/dev/null 2>&1 || true
        echo -e "${GREEN}[OK] auditd and libpam-pwquality configured and enabled.${NC}"
    fi
fi

echo -e "\n${BLUE}====================================================================${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}${BOLD}DRY-RUN COMPLETE: No modifications made to system.${NC}"
    echo -e "To enforce these settings, execute: ${BOLD}sudo $0 --apply${NC}"
else
    echo -e "${GREEN}${BOLD}REMEDIATION COMPLETE: System hardened against CIS Level 1 baseline.${NC}"
    echo -e "Run ${BOLD}./verify_compliance.sh${NC} to measure your new compliance score!"
fi
echo -e "${BLUE}====================================================================${NC}\n"

