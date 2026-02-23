#!/usr/bin/env bash

##############################
##  Jayden Kerr             ##
##  Originally: 25/10/2018  ##
##  Rewritten:  23/02/2026  ##
##############################
##  Version 2.0.0           ##
############################################################
##  Ubuntu Server Setup Script                            ##
##                                                        ##
##  Interactive server provisioning with selectable       ##
##  package groups, user management, security hardening,  ##
##  Docker, and Tailscale installation.                   ##
############################################################

set -euo pipefail

# ─── Colours and Formatting ──────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
WHITE="\033[1;37m"
BOLD="\033[1m"
DIM="\033[2m"
NF="\033[0m"  # Reset all formatting
NC="\033[39m" # Default text colour

# ─── Configuration ───────────────────────────────────────
LOG_FILE="${HOME}/server-setup.log"
DOTFILES_REPO="https://github.com/jaydenk/dotfiles.git"
DEFAULT_TIMEZONE="Australia/Adelaide"

# Track created users for later steps
LIMITED_USER=""
RECOVERY_USER=""

# ─── Logging ─────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "${LOG_FILE}"
}

info() {
    printf "${BOLD}%s${NF}\n" "$*"
    log "INFO: $*"
}

success() {
    printf "${GREEN}${BOLD}✓ %s${NF}\n" "$*"
    log "OK: $*"
}

warn() {
    printf "${YELLOW}${BOLD}⚠ %s${NF}\n" "$*"
    log "WARN: $*"
}

error() {
    printf "${RED}${BOLD}✗ %s${NF}\n" "$*" >&2
    log "ERROR: $*"
}

# ─── Error Trap ──────────────────────────────────────────
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        error "Script failed at line ${BASH_LINENO[0]} with exit code ${exit_code}."
        error "Check ${LOG_FILE} for details."
    fi
}
trap cleanup EXIT

# ─── Pre-flight Checks ──────────────────────────────────
preflight_checks() {
    # Must be root
    if [[ "${EUID}" -ne 0 ]]; then
        error "This script must be run as root."
        exit 1
    fi

    # Must be Ubuntu/Debian
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    source /etc/os-release
    if [[ "${ID}" != "ubuntu" && "${ID}" != "debian" ]]; then
        error "This script is designed for Ubuntu/Debian. Detected: ${ID}"
        exit 1
    fi

    info "Detected ${PRETTY_NAME}"
    log "Starting setup on ${PRETTY_NAME} ($(uname -r))"
}

# ─── Helper: Yes/No Prompt ──────────────────────────────
confirm() {
    local prompt="${1}"
    local default="${2:-y}"
    local reply

    if [[ "${default}" == "y" ]]; then
        prompt="${prompt} [Y/n] "
    else
        prompt="${prompt} [y/N] "
    fi

    while true; do
        read -rp "${prompt}" reply
        reply="${reply:-${default}}"
        case "${reply}" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) printf "Please answer y or n.\n" ;;
        esac
    done
}

# ─── Helper: Run command with logging ────────────────────
run() {
    log "CMD: $*"
    "$@" >> "${LOG_FILE}" 2>&1
}

# ─── Package Selection Menu ─────────────────────────────
declare -A PKG_SELECTED

select_packages() {
    printf "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NF}\n"
    printf "${WHITE}${BOLD}  Package Selection${NF}\n"
    printf "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NF}\n\n"

    info "Select which package groups to install."
    printf "${DIM}Answer y/n for each group.${NF}\n\n"

    # Essentials: nano, vim, wget, curl, git, tree
    if confirm "  Essentials (nano, vim, wget, curl, git, tree)?"; then
        PKG_SELECTED[essentials]=1
    else
        PKG_SELECTED[essentials]=0
    fi

    # Shell: fish shell
    if confirm "  Fish shell (set as default for limited user)?"; then
        PKG_SELECTED[fish]=1
    else
        PKG_SELECTED[fish]=0
    fi

    # Remote access: mosh, tmux
    if confirm "  Remote access tools (mosh, tmux)?"; then
        PKG_SELECTED[remote]=1
    else
        PKG_SELECTED[remote]=0
    fi

    # Monitoring: htop, iftop, nload
    if confirm "  Monitoring tools (htop, iftop, nload)?"; then
        PKG_SELECTED[monitoring]=1
    else
        PKG_SELECTED[monitoring]=0
    fi

    # Security: fail2ban, ufw
    if confirm "  Security tools (fail2ban, ufw)?"; then
        PKG_SELECTED[security]=1
    else
        PKG_SELECTED[security]=0
    fi

    # Development: gcc, build-essential
    if confirm "  Development tools (gcc, build-essential)?"; then
        PKG_SELECTED[dev]=1
    else
        PKG_SELECTED[dev]=0
    fi

    # Docker
    if confirm "  Docker Engine + Compose?"; then
        PKG_SELECTED[docker]=1
    else
        PKG_SELECTED[docker]=0
    fi

    # Tailscale
    if confirm "  Tailscale VPN?"; then
        PKG_SELECTED[tailscale]=1
    else
        PKG_SELECTED[tailscale]=0
    fi

    # Summary
    printf "\n${BOLD}Selected:${NF} "
    local selected=()
    for key in essentials fish remote monitoring security dev docker tailscale; do
        if [[ "${PKG_SELECTED[$key]}" -eq 1 ]]; then
            selected+=("${key}")
        fi
    done
    if [[ ${#selected[@]} -eq 0 ]]; then
        printf "${DIM}(none)${NF}\n"
    else
        printf "%s\n" "${selected[*]}"
    fi
    printf "\n"
}

# ─── Step: Change Root Password ─────────────────────────
step_root_password() {
    printf "\n${WHITE}━━━ Step 1: Root Password ━━━${NF}\n\n"
    if confirm "Change the root password?"; then
        passwd
        success "Root password changed."
    else
        info "Skipping root password change."
    fi
}

# ─── Step: Create Limited User ──────────────────────────
step_limited_user() {
    printf "\n${WHITE}━━━ Step 2: Limited User ━━━${NF}\n\n"
    if confirm "Create a limited (non-root) user?"; then
        printf "${BOLD}Enter the desired username: ${NF}"
        read -r LIMITED_USER

        if id "${LIMITED_USER}" &>/dev/null; then
            warn "User '${LIMITED_USER}' already exists. Skipping creation."
        else
            useradd -m -s /bin/bash "${LIMITED_USER}"
            info "Set a password for ${LIMITED_USER}:"
            passwd "${LIMITED_USER}"
            usermod -aG sudo "${LIMITED_USER}"
            success "User '${LIMITED_USER}' created with sudo access."
        fi
    else
        info "Skipping limited user creation."
        printf "${BOLD}Enter an existing username to configure (or leave blank to skip): ${NF}"
        read -r LIMITED_USER
    fi
}

# ─── Step: Create Recovery User ─────────────────────────
step_recovery_user() {
    printf "\n${WHITE}━━━ Step 3: Recovery User ━━━${NF}\n\n"
    info "A recovery user can SSH in with a password if key auth is unavailable."
    if confirm "Create a recovery user?"; then
        printf "${BOLD}Enter the desired username: ${NF}"
        read -r RECOVERY_USER

        if id "${RECOVERY_USER}" &>/dev/null; then
            warn "User '${RECOVERY_USER}' already exists. Skipping creation."
        else
            useradd -m -s /bin/bash "${RECOVERY_USER}"
            info "Set a password for ${RECOVERY_USER}:"
            passwd "${RECOVERY_USER}"
            usermod -aG sudo "${RECOVERY_USER}"
            success "Recovery user '${RECOVERY_USER}' created with sudo access."
        fi
    else
        info "Skipping recovery user creation."
    fi
}

# ─── Step: SSH Key Setup ────────────────────────────────
step_ssh_keys() {
    if [[ -z "${LIMITED_USER}" ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Step 4: SSH Key Setup ━━━${NF}\n\n"

    local ssh_dir="/home/${LIMITED_USER}/.ssh"
    mkdir -p "${ssh_dir}"
    chown "${LIMITED_USER}:${LIMITED_USER}" "${ssh_dir}"
    chmod 700 "${ssh_dir}"

    local local_ip
    local_ip=$(hostname -I | awk '{print $1}')

    info "Copy your SSH public key to this machine now."
    printf "\n  ${DIM}Example:${NF}\n"
    printf "  ${WHITE}ssh-copy-id ${LIMITED_USER}@${local_ip}${NF}\n"
    printf "  ${DIM}Or:${NF}\n"
    printf "  ${WHITE}scp ~/.ssh/id_ed25519.pub ${LIMITED_USER}@${local_ip}:~/.ssh/authorized_keys${NF}\n\n"

    read -n 1 -s -r -p "Press any key once your key has been copied..."
    printf "\n"

    # Ensure correct permissions on authorized_keys if it exists
    if [[ -f "${ssh_dir}/authorized_keys" ]]; then
        chown "${LIMITED_USER}:${LIMITED_USER}" "${ssh_dir}/authorized_keys"
        chmod 600 "${ssh_dir}/authorized_keys"
        success "SSH key permissions set."
    else
        warn "No authorized_keys file found. SSH key auth may not work."
    fi
}

# ─── Step: Hostname ─────────────────────────────────────
step_hostname() {
    printf "\n${WHITE}━━━ Step 5: Hostname ━━━${NF}\n\n"
    info "Current hostname: $(hostname)"
    if confirm "Change the hostname?"; then
        printf "${BOLD}Enter new hostname: ${NF}"
        read -r new_hostname
        hostnamectl set-hostname "${new_hostname}"
        success "Hostname set to $(hostname)."
    else
        info "Keeping current hostname."
    fi
}

# ─── Step: Timezone ─────────────────────────────────────
step_timezone() {
    printf "\n${WHITE}━━━ Step 6: Timezone ━━━${NF}\n\n"
    info "Current timezone: $(timedatectl show --property=Timezone --value 2>/dev/null || echo 'unknown')"
    if confirm "Set timezone to ${DEFAULT_TIMEZONE}?" "y"; then
        timedatectl set-timezone "${DEFAULT_TIMEZONE}"
        success "Timezone set to ${DEFAULT_TIMEZONE}."
    elif confirm "Set a different timezone?"; then
        printf "${BOLD}Enter timezone (e.g. Australia/Sydney): ${NF}"
        read -r tz
        if timedatectl set-timezone "${tz}" 2>/dev/null; then
            success "Timezone set to ${tz}."
        else
            error "Invalid timezone: ${tz}. Leaving unchanged."
        fi
    else
        info "Keeping current timezone."
    fi
}

# ─── Step: System Update ────────────────────────────────
step_update() {
    printf "\n${WHITE}━━━ Step 7: System Update ━━━${NF}\n\n"
    info "Updating package lists and upgrading existing packages..."
    run apt-get update
    run apt-get -y upgrade
    success "System updated."
}

# ─── Step: Install Essential Packages ────────────────────
step_install_essentials() {
    if [[ "${PKG_SELECTED[essentials]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Essentials ━━━${NF}\n\n"
    info "Installing nano, vim, wget, curl, git, tree..."
    run apt-get -y install nano vim wget curl git tree ca-certificates gnupg
    success "Essentials installed."
}

# ─── Step: Clone Dotfiles ───────────────────────────────
step_dotfiles() {
    if [[ -z "${LIMITED_USER}" ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Dotfiles ━━━${NF}\n\n"
    if confirm "Clone dotfiles from ${DOTFILES_REPO}?"; then
        local dotfiles_dir="/home/${LIMITED_USER}/.dotfiles"
        if [[ -d "${dotfiles_dir}" ]]; then
            warn "Dotfiles directory already exists. Pulling latest..."
            run git -C "${dotfiles_dir}" pull
        else
            run git clone "${DOTFILES_REPO}" "${dotfiles_dir}"
            chown -R "${LIMITED_USER}:${LIMITED_USER}" "${dotfiles_dir}"
        fi
        success "Dotfiles ready at ${dotfiles_dir}."
    else
        info "Skipping dotfiles."
    fi
}

# ─── Step: SSH Hardening ────────────────────────────────
step_ssh_hardening() {
    printf "\n${WHITE}━━━ SSH Hardening ━━━${NF}\n\n"
    if ! confirm "Harden SSH configuration (disable root login, require key auth)?"; then
        info "Skipping SSH hardening."
        return
    fi

    local sshd_config="/etc/ssh/sshd_config"

    # Back up current config
    cp "${sshd_config}" "${sshd_config}.bak.$(date +%s)"
    info "Backed up current sshd_config."

    # Apply hardening settings
    local settings=(
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "PubkeyAuthentication yes"
        "ChallengeResponseAuthentication no"
        "X11Forwarding no"
        "MaxAuthTries 5"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
    )

    for setting in "${settings[@]}"; do
        local key="${setting%% *}"
        # Comment out any existing setting, then append the new one
        sed -i "s/^#*\s*${key}\s.*/#&/" "${sshd_config}"
    done

    # Append hardened settings
    {
        echo ""
        echo "# ─── Hardened settings (added by setup.sh) ───"
        for setting in "${settings[@]}"; do
            echo "${setting}"
        done
    } >> "${sshd_config}"

    # Add recovery user password exception if applicable
    if [[ -n "${RECOVERY_USER}" ]]; then
        {
            echo ""
            echo "# Recovery user: allow password authentication"
            echo "Match User ${RECOVERY_USER}"
            echo "    PasswordAuthentication yes"
        } >> "${sshd_config}"
        info "Added password auth exception for recovery user '${RECOVERY_USER}'."
    fi

    # Validate config before restarting
    if sshd -t 2>/dev/null; then
        systemctl restart sshd
        success "SSH hardened and restarted."
    else
        error "sshd_config validation failed. Restoring backup."
        cp "${sshd_config}.bak."* "${sshd_config}" 2>/dev/null
        systemctl restart sshd
    fi
}

# ─── Step: Install Fish Shell ────────────────────────────
step_install_fish() {
    if [[ "${PKG_SELECTED[fish]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Fish Shell ━━━${NF}\n\n"
    run apt-get -y install software-properties-common
    run apt-add-repository -y ppa:fish-shell/release-3
    run apt-get update
    run apt-get -y install fish
    success "Fish shell installed."

    if [[ -n "${LIMITED_USER}" ]]; then
        local fish_path
        fish_path=$(which fish)
        chsh -s "${fish_path}" "${LIMITED_USER}"
        success "Fish set as default shell for ${LIMITED_USER}."
    fi
}

# ─── Step: Install Remote Access Tools ───────────────────
step_install_remote() {
    if [[ "${PKG_SELECTED[remote]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Remote Access Tools ━━━${NF}\n\n"
    info "Installing mosh and tmux..."
    run apt-get -y install mosh tmux
    success "mosh and tmux installed."

    # Symlink tmux.conf if dotfiles exist
    if [[ -n "${LIMITED_USER}" ]]; then
        local tmux_src="/home/${LIMITED_USER}/.dotfiles/tmux.conf"
        local tmux_dest="/home/${LIMITED_USER}/.tmux.conf"
        if [[ -f "${tmux_src}" && ! -e "${tmux_dest}" ]]; then
            ln -s "${tmux_src}" "${tmux_dest}"
            chown -h "${LIMITED_USER}:${LIMITED_USER}" "${tmux_dest}"
            success "Linked tmux.conf from dotfiles."
        fi
    fi
}

# ─── Step: Install Monitoring Tools ──────────────────────
step_install_monitoring() {
    if [[ "${PKG_SELECTED[monitoring]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Monitoring Tools ━━━${NF}\n\n"
    info "Installing htop, iftop, nload..."
    run apt-get -y install htop iftop nload
    success "Monitoring tools installed."
}

# ─── Step: Install Security Tools ────────────────────────
step_install_security() {
    if [[ "${PKG_SELECTED[security]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Security Tools ━━━${NF}\n\n"

    # fail2ban
    info "Installing fail2ban..."
    run apt-get -y install fail2ban
    systemctl enable fail2ban >> "${LOG_FILE}" 2>&1
    systemctl start fail2ban >> "${LOG_FILE}" 2>&1

    # Create jail.local with sane defaults
    if [[ ! -f /etc/fail2ban/jail.local ]]; then
        cat > /etc/fail2ban/jail.local <<'JAIL'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
JAIL
        # If dotfiles jail.local exists, prefer it
        if [[ -n "${LIMITED_USER}" ]]; then
            local jail_src="/home/${LIMITED_USER}/.dotfiles/fail2ban.jail.local"
            if [[ -f "${jail_src}" ]]; then
                cp "${jail_src}" /etc/fail2ban/jail.local
                info "Using jail.local from dotfiles."
            fi
        fi

        chown root:root /etc/fail2ban/jail.local
        chmod 644 /etc/fail2ban/jail.local
        fail2ban-client reload >> "${LOG_FILE}" 2>&1 || true
    fi
    success "fail2ban installed and configured."

    # UFW firewall
    info "Configuring UFW firewall..."
    run apt-get -y install ufw

    ufw default deny incoming >> "${LOG_FILE}" 2>&1
    ufw default allow outgoing >> "${LOG_FILE}" 2>&1
    ufw allow ssh >> "${LOG_FILE}" 2>&1
    ufw allow http >> "${LOG_FILE}" 2>&1
    ufw allow https >> "${LOG_FILE}" 2>&1

    if [[ "${PKG_SELECTED[remote]}" -eq 1 ]]; then
        ufw allow 60000:61000/udp >> "${LOG_FILE}" 2>&1  # mosh
        info "Allowed mosh ports (60000-61000/udp)."
    fi

    if [[ "${PKG_SELECTED[tailscale]}" -eq 1 ]]; then
        ufw allow 41641/udp >> "${LOG_FILE}" 2>&1  # Tailscale direct connections
        info "Allowed Tailscale port (41641/udp)."
    fi

    ufw --force enable >> "${LOG_FILE}" 2>&1
    success "UFW firewall enabled."
    ufw status
}

# ─── Step: Install Development Tools ────────────────────
step_install_dev() {
    if [[ "${PKG_SELECTED[dev]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Development Tools ━━━${NF}\n\n"
    info "Installing gcc, build-essential..."
    run apt-get -y install gcc build-essential
    success "Development tools installed."
}

# ─── Step: Install Docker ───────────────────────────────
step_install_docker() {
    if [[ "${PKG_SELECTED[docker]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Docker Engine ━━━${NF}\n\n"

    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        warn "Docker is already installed: $(docker --version)"
        if ! confirm "Reinstall Docker?"; then
            info "Skipping Docker installation."
            return
        fi
    fi

    # Install prerequisites
    info "Installing prerequisites..."
    run apt-get -y install ca-certificates curl gnupg

    # Add Docker's official GPG key
    info "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the Docker repository
    info "Adding Docker apt repository..."
    source /etc/os-release
    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-${VERSION_CODENAME}}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    # Install Docker Engine
    info "Installing Docker Engine, CLI, and Compose plugin..."
    run apt-get update
    run apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    systemctl enable docker >> "${LOG_FILE}" 2>&1
    systemctl start docker >> "${LOG_FILE}" 2>&1

    # Add limited user to docker group
    if [[ -n "${LIMITED_USER}" ]]; then
        usermod -aG docker "${LIMITED_USER}"
        info "Added '${LIMITED_USER}' to the docker group."
    fi

    success "Docker installed: $(docker --version)"
    info "Docker Compose: $(docker compose version)"
}

# ─── Step: Install Tailscale ────────────────────────────
step_install_tailscale() {
    if [[ "${PKG_SELECTED[tailscale]}" -ne 1 ]]; then
        return
    fi

    printf "\n${WHITE}━━━ Installing Tailscale ━━━${NF}\n\n"

    # Check if already installed
    if command -v tailscale &>/dev/null; then
        warn "Tailscale is already installed: $(tailscale version | head -1)"
        if ! confirm "Reinstall Tailscale?"; then
            info "Skipping Tailscale installation."
            return
        fi
    fi

    info "Installing Tailscale via official installer..."
    curl -fsSL https://tailscale.com/install.sh | sh >> "${LOG_FILE}" 2>&1

    # Enable and start
    systemctl enable tailscaled >> "${LOG_FILE}" 2>&1
    systemctl start tailscaled >> "${LOG_FILE}" 2>&1

    success "Tailscale installed: $(tailscale version | head -1)"

    printf "\n${BOLD}To authenticate this machine, run:${NF}\n"
    printf "  ${WHITE}sudo tailscale up${NF}\n"
    if confirm "Run 'tailscale up' now?"; then
        tailscale up
        success "Tailscale connected."
    else
        info "Run 'sudo tailscale up' later to connect."
    fi
}

# ─── Summary ────────────────────────────────────────────
print_summary() {
    printf "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NF}\n"
    printf "${GREEN}${BOLD}  Setup Complete${NF}\n"
    printf "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NF}\n\n"

    printf "${BOLD}Hostname:${NF}  %s\n" "$(hostname)"
    printf "${BOLD}Timezone:${NF}  %s\n" "$(timedatectl show --property=Timezone --value 2>/dev/null || echo 'unknown')"

    if [[ -n "${LIMITED_USER}" ]]; then
        printf "${BOLD}User:${NF}      %s\n" "${LIMITED_USER}"
    fi
    if [[ -n "${RECOVERY_USER}" ]]; then
        printf "${BOLD}Recovery:${NF}  %s\n" "${RECOVERY_USER}"
    fi

    printf "\n${BOLD}Installed:${NF}\n"
    for key in essentials fish remote monitoring security dev docker tailscale; do
        if [[ "${PKG_SELECTED[$key]}" -eq 1 ]]; then
            printf "  ${GREEN}✓${NF} %s\n" "${key}"
        fi
    done

    printf "\n${BOLD}Log file:${NF}  %s\n" "${LOG_FILE}"

    if [[ "${PKG_SELECTED[tailscale]}" -eq 1 ]]; then
        printf "\n${BOLD}Reminder:${NF} Run ${WHITE}sudo tailscale up${NF} if you haven't authenticated yet.\n"
    fi

    if [[ -n "${LIMITED_USER}" ]]; then
        printf "\n${BOLD}Next steps:${NF}\n"
        printf "  1. Log out and log back in as ${WHITE}${LIMITED_USER}${NF}\n"
        printf "  2. Verify SSH key authentication works before closing this session\n"
        if [[ "${PKG_SELECTED[docker]}" -eq 1 ]]; then
            printf "  3. Run ${WHITE}docker run hello-world${NF} to verify Docker\n"
        fi
    fi

    printf "\n${BOLD}${WHITE}Enjoy your machine.${NF}\n\n"
}

# ─── Main ────────────────────────────────────────────────
main() {
    printf "\n${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NF}\n"
    printf "${WHITE}${BOLD}  Ubuntu Server Setup Script v2.0${NF}\n"
    printf "${WHITE}${BOLD}  Jayden Kerr — 2026${NF}\n"
    printf "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NF}\n\n"

    preflight_checks

    # Phase 1: Package selection
    select_packages

    # Phase 2: System configuration
    step_root_password
    step_limited_user
    step_recovery_user
    step_ssh_keys
    step_hostname
    step_timezone

    # Phase 3: Update system
    step_update

    # Phase 4: Install selected packages
    step_install_essentials
    step_dotfiles
    step_install_fish
    step_install_remote
    step_install_monitoring
    step_install_dev

    # Phase 5: Docker & Tailscale
    step_install_docker
    step_install_tailscale

    # Phase 6: Security hardening (after all installs so firewall rules account for selections)
    step_install_security
    step_ssh_hardening

    # Done
    print_summary
}

main "$@"
