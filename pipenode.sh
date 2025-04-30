#!/bin/bash

# Define colors
GREEN="\033[0;32m"
RESET="\033[0m"

# Paths
NODE_INFO_FILE=~/pipe-node/node_info.json
PUBKEY_FILE="/root/.pubkey"
REFERRAL_CODE="4bdd5692e072c6b9"  # Default referral code
NODE_DIR=~/pipe-node
PIPE_STATUS_SCRIPT_URL="https://raw.githubusercontent.com/abhiag/PipePoPDevNet/main/pipe_status.sh"
PIPE_STATUS_SCRIPT="$NODE_DIR/pipe_status.sh"
BACKUP_DIR=~/pipe-node-backups

# Detect system's total RAM (in GB)
TOTAL_RAM=$(free -g | awk '/^Mem:/ {print $2}')
RAM=$TOTAL_RAM  # Assign detected RAM
DISK=100        # Default Disk allocation

# Function to create node_info.json if it doesn't exist
create_node_info_file() {
    if [[ ! -f "$NODE_INFO_FILE" ]]; then
        echo "🔄 Creating node_info.json file..."
        mkdir -p "$(dirname "$NODE_INFO_FILE")"  # Ensure the directory exists
        cat <<EOF > "$NODE_INFO_FILE"
{
    "node_id": "",
    "registered": false,
    "token": ""
}
EOF
        echo "✅ node_info.json created!"
    else
        echo "✅ node_info.json already exists."
    fi
}

# Function to backup node data
backup_node_data() {
    echo "🔄 Creating backup of node data..."
    mkdir -p "$BACKUP_DIR"
    timestamp=$(date +%Y%m%d%H%M%S)
    backup_file="$BACKUP_DIR/pipe-node-backup-$timestamp.tar.gz"
    
    # Backup node info and logs
    tar -czvf "$backup_file" "$NODE_INFO_FILE" "$NODE_DIR/pop.log"
    
    if [[ -f "$backup_file" ]]; then
        echo "✅ Backup successful! Backup saved to: $backup_file"
    else
        echo "❌ Backup failed!"
    fi
}

# Function to start the node
start_node() {
    if [[ ! -f "$NODE_INFO_FILE" ]]; then
        echo "❌ Node info not found! Please install or restore first."
        return
    fi

    PUBKEY=$(cat "$PUBKEY_FILE")
    echo "🚀 Starting node..."
    cd "$NODE_DIR"
    sudo ./pop --ram "$RAM" --max-disk "$DISK" --cache-dir /data --pubKey "$PUBKEY" >> pop.log 2>&1 &
    echo "✅ Node started."
}

# Function to pause the node
pause_node() {
    pkill pop && echo "⏸️ Node paused." || echo "❌ Node was not running."
}

# Function to install the node
install_node() {
    echo -e "\n🔄 Updating system packages..."
    sudo apt update -y && sudo apt upgrade -y

    echo -e "\n⚙️ Installing required dependencies..."
    sudo apt install -y curl wget jq unzip screen cron

    echo -e "\n📂 Setting up PiPe node directory..."
    mkdir -p "$NODE_DIR" && cd "$NODE_DIR"

    echo -e "\n⬇️ Downloading PiPe Network node..."
    curl -L -o pop "https://dl.pipecdn.app/v0.2.8/pop"

    echo -e "\n🔧 Making binary executable..."
    chmod +x pop

    echo -e "\n🔍 Verifying pop binary..."
    ./pop --version || { echo "❌ Error: pop binary is not working!"; exit 1; }

    echo -e "\n📂 Creating download cache directory..."
    mkdir -p download_cache

    # Restore Public Key if it exists, otherwise ask user
    if [[ -f "$PUBKEY_FILE" ]]; then
        PUBKEY=$(cat "$PUBKEY_FILE")
        echo -e "🔑 Using saved Solana wallet address: $PUBKEY"
    else
        read -p "🔑 Enter your Solana wallet Address: " PUBKEY
        echo "$PUBKEY" | sudo tee "$PUBKEY_FILE" > /dev/null
        echo "✅ Public key saved for future use!"
    fi

    # Sign up using the referral code (only if no existing node_info.json)
    if [[ ! -f "$NODE_INFO_FILE" ]]; then
        echo -e "\n📌 Signing up for PiPe Network using referral..."
        ./pop --signup-by-referral-route "$REFERRAL_CODE"
        if [ $? -ne 0 ]; then
            echo "❌ Error: Signup failed!"
            exit 1
        fi
    fi

    echo -e "\n🚀 Starting PiPe Network node..."
    sudo ./pop --ram "$RAM" --max-disk "$DISK" --cache-dir /data --pubKey "$PUBKEY" &

    # Add a cron job to check and restart pop every 2 minutes
    CRON_JOB="*/2 * * * * pgrep pop > /dev/null || (cd $NODE_DIR && sudo ./pop --ram $RAM --max-disk $DISK --cache-dir /data --pubKey \"\$(cat /root/.pubkey)\" &)"
    (crontab -l 2>/dev/null | grep -F "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

    echo -e "\n✅ PiPe Node installation and setup completed!"
}

# Function to check node status using pipe_status.sh
check_node_status() {
    echo -e "\n⬇️ Downloading pipe_status.sh script..."
    curl -L -o "$PIPE_STATUS_SCRIPT" "$PIPE_STATUS_SCRIPT_URL" || { echo "❌ Failed to download pipe_status.sh"; return 1; }
    chmod +x "$PIPE_STATUS_SCRIPT"

    echo -e "\n🔍 Checking PiPe Node status..."
    "$PIPE_STATUS_SCRIPT"
}

# Main menu
while true; do
    echo "==============================================================="
    echo -e "\e[1;36m🚀🚀 PIPE NODE INSTALLER Tool-Kit \e[0m"
    echo "==============================================================="
    echo -e "\e[1;85m📢 Stay updated\e[0m"

    echo -e "\n📋 PiPe Node Management Menu:"
    echo "1. Install PiPe Node"
    echo "2. Start Node"
    echo "3. Pause Node"
    echo "4. Backup Node Data"
    echo "5. Check Node Status"
    echo "6. Exit"
    read -p "🔢 Choose an option (1-6): " CHOICE

    case $CHOICE in
        1) install_node ;;
        2) start_node ;;
        3) pause_node ;;
        4) backup_node_data ;;
        5) check_node_status ;;
        6) echo "👋 Exiting..."; exit 0 ;;
        *) echo "❌ Invalid choice. Please try again." ;;
    esac
done
