#!/usr/bin/env bash
# Ubuntu 22.04 Media Server Setup Script
# GitHub-compatible version with modular structure & improved portability
# Author: Omega
# Repository: https://github.com/your-username/media-server-setup

set -euo pipefail

# ===== CONFIGURATION VARIABLES =====
CONFIG_DIR="./config"
LOG_DIR="./logs"
LOG_FILE="$LOG_DIR/setup.log"
NETPLAN_CONFIG="$CONFIG_DIR/netplan.yaml"
UFW_RULES="$CONFIG_DIR/ufw.rules"
DOCKER_COMPOSE="./docker/docker-compose.yml"

# Load environment variables from .env file (if exists)
if [[ -f ".env" ]]; then
    source ".env"
else
    echo "No .env file found. Using default values."
    STATIC_IP="192.168.8.160"
    GATEWAY="192.168.8.1"
    DNS1="192.168.8.1"
    DNS2="8.8.8.8"
    NETWORK_INTERFACE="eth0"
fi

# ===== FUNCTIONS =====
log() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') [INFO] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

update_system() {
    log "Updating system packages..."
    sudo apt-get update -y && sudo apt-get upgrade -y
}

install_casaos() {
    log "Installing CasaOS..."
    curl -fsSL https://get.casaos.io | sudo bash || error_exit "CasaOS installation failed."
}

configure_static_ip() {
    log "Configuring static IP..."
    sudo cp "$NETPLAN_CONFIG" /etc/netplan/01-static-ip.yaml
    sudo sed -i "s/<INTERFACE>/$NETWORK_INTERFACE/g" /etc/netplan/01-static-ip.yaml
    sudo sed -i "s/<STATIC_IP>/$STATIC_IP/g" /etc/netplan/01-static-ip.yaml
    sudo sed -i "s/<GATEWAY>/$GATEWAY/g" /etc/netplan/01-static-ip.yaml
    sudo sed -i "s/<DNS1>/$DNS1/g" /etc/netplan/01-static-ip.yaml
    sudo sed -i "s/<DNS2>/$DNS2/g" /etc/netplan/01-static-ip.yaml"
    sudo netplan apply || error_exit "Failed to apply netplan configuration."
}

install_docker() {
    log "Installing Docker..."
    sudo apt-get install -y docker.io docker-compose || error_exit "Failed to install Docker."
    sudo systemctl enable --now docker
}

deploy_docker_services() {
    log "Deploying Docker services..."
    mkdir -p "$LOG_DIR"
    sudo docker-compose -f "$DOCKER_COMPOSE" up -d || error_exit "Docker deployment failed."
}

configure_firewall() {
    log "Configuring firewall (UFW)..."
    sudo cp "$UFW_RULES" /etc/ufw/ufw.rules
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow from 192.168.8.0/24
    sudo ufw --force enable || error_exit "Failed to enable UFW."
}

set_performance_mode() {
    log "Setting CPU governor to performance mode..."
    for CPU in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo performance | sudo tee "$CPU" || true
    done
}

# ===== MAIN EXECUTION =====
mkdir -p "$LOG_DIR"
log "Starting media server setup..."

update_system
install_casaos
configure_static_ip
install_docker
deploy_docker_services
configure_firewall
set_performance_mode

log "Setup complete! Access services at:"
log " - CasaOS: http://$STATIC_IP"
log " - Radarr: http://$STATIC_IP:7878"
log " - Sonarr: http://$STATIC_IP:8989"
log " - qBittorrent: http://$STATIC_IP:8081"
log " - Bazarr: http://$STATIC_IP:6767"
log " - Jackett: http://$STATIC_IP:9117"
log " - Jellyfin: http://$STATIC_IP:8096"

log "Reboot recommended for all changes to take effect."
