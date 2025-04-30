#!/bin/bash

# Define colors
GREEN="\033[0;32m"
RESET="\033[0m"

# Paths and config
NODE_INFO_FILE=~/pipe-node/node_info.json
PUBKEY_FILE="/root/.pubkey"
REFERRAL_CODE="4bdd5692e072c6b9"
NODE_DIR=~/pipe-node
PIPE_STATUS_SCRIPT_URL="https://raw.githubusercontent.com/abhiag/PipePoPDevNet/main/pipe_status.sh"
PIPE_STATUS_SCRIPT="$NODE_DIR/pipe_status.sh"

# Detect system RAM
TOTAL_RAM=$(free -g | awk '/^Mem:/ {print $2}')
RAM=${TOTAL_RAM:-4}
DISK=100

# Load public key from file
load_pubkey() {
    if [[ -f "$PUBKEY_FILE" ]]; then
        PUBKEY=$(cat "$PUBKEY_FILE")
    else
        read -p "🔑 Enter your Solana wallet Address: " PUBKEY
        echo "$PUBKEY" | sudo tee "$PUBKEY_FILE" > /dev/null
        echo "✅ Public key saved!"
    fi
}

# Create node_info.json if needed
create_node_info_file() {
    if [[ ! -f "$NODE_INFO_FILE" ]]; then
        mkdir -p "$(dirname "$NODE_INFO_FILE")"
        cat <<EOF > "$NODE_INFO_FILE"
{
  "node_id": "",
  "registered": false,
  "token": ""
}
EOF
        echo "✅ node_info.json created!"
    fi
}

# Restore node info
restore_node_info() {
    read -p "🔄 Do you have a backup of node_info.json? (y/n): " RESTORE_CHOICE
    if [[ "$RESTORE_CHOICE" == "y" ]]; then
        read -p "📌 Enter your previous Node ID: " NODE_ID
        read -p "🔑 Enter your authentication token: " TOKEN
        mkdir -p "$(dirname "$NODE_INFO_FILE")"
        cat <<EOF > "$NODE_INFO_FILE"
{
  "node_id": "$NODE_ID",
  "registered": true,
  "token": "$TOKEN"
}
EOF
        echo "✅ Node info restored!"
    else
        echo "⏭️ Skipping restore."
    fi
}

# Backup node info
backup_node_info() {
    if [[ -f "$NODE_INFO_FILE" ]]; then
        echo -e "\n📜 Copy this backup and save it safely:"
        cat "$NODE_INFO_FILE"
    else
        echo "❌ No node_info.json found!"
    fi
}

# Install node
install_node() {
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y curl wget jq unzip screen cron

    mkdir -p "$NODE_DIR" && cd "$NODE_DIR"
    curl -L -o pop "https://dl.pipecdn.app/v0.2.8/pop"
    chmod +x pop

    ./pop --version || { echo "❌ pop binary failed!"; exit 1; }

    mkdir -p download_cache
    load_pubkey
    create_node_info_file

    if [[ ! -f "$NODE_INFO_FILE" || $(jq -r .registered "$NODE_INFO_FILE") == "false" ]]; then
        ./pop --signup-by-referral-route "$REFERRAL_CODE" || {
            echo "❌ Signup failed."
            exit 1
        }
    fi

    echo "🚀 Starting node..."
    sudo ./pop --ram "$RAM" --max-disk "$DISK" --cache-dir /data --pubKey "$PUBKEY" &

    # Setup cron job
    CRON_JOB="*/2 * * * * cd $NODE_DIR && pgrep pop > /dev/null || (sudo ./pop --ram $RAM --max-disk $DISK --cache-dir /data --pubKey \"\\\$(cat /root/.pubkey)\" &)"
    (crontab -l 2>/dev/null | grep -F "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    echo "✅ Node installed and running!"
}

# Start node
start_node() {
    load_pubkey
    echo "🚀 Starting node..."
    cd "$NODE_DIR"
    sudo ./pop --ram "$RAM" --max-disk "$DISK" --cache-dir /data --pubKey "$PUBKEY" &
    echo "✅ Node started!"
}

# Stop node
stop_node() {
    if pgrep pop > /dev/null; then
        sudo pkill pop
        echo "⏸️ Node paused/stopped."
    else
        echo "⚠️ Node is not running."
    fi
}

# Check status
check_node_status() {
    curl -L -o "$PIPE_STATUS_SCRIPT" "$PIPE_STATUS_SCRIPT_URL" || {
        echo "❌ Failed to download status script."
        return 1
    }
    chmod +x "$PIPE_STATUS_SCRIPT"
    "$PIPE_STATUS_SCRIPT"
}

# Uninstall node
uninstall_node() {
    stop_node
    rm -rf "$NODE_DIR"
    crontab -l | grep -v "pgrep pop" | crontab -
    echo "🧹 Node uninstalled!"
}

# Menu
while true; do
    echo "==============================================================="
    echo -e "${GREEN}🚀 PiPe Node Installer by WEB3BYTE 🚀${RESET}"
    echo "==============================================================="
    echo "1. Install PiPe Node"
    echo "2. Start PiPe Node"
    echo "3. Pause PiPe Node"
    echo "4. Check Node Status"
    echo "5. Backup Node Info"
    echo "6. Restore Node Info"
    echo "7. Uninstall PiPe Node"
    echo "8. Exit"
    read -p "🔢 Choose an option (1-8): " CHOICE

    case "$CHOICE" in
        1) install_node ;;
        2) start_node ;;
        3) stop_node ;;
        4) check_node_status ;;
        5) backup_node_info ;;
        6) restore_node_info ;;
        7) uninstall_node ;;
        8) echo "👋 Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option. Try again." ;;
    esac
done
