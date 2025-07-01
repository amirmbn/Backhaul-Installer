#!/bin/bash

CONFIG_FILE="config.toml"

# Function to get user input with a default value
get_input_with_default() {
    local prompt="$1"
    local default_value="$2"
    read -rp "$prompt (Default: $default_value): " user_input
    echo "${user_input:-$default_value}"
}

# Function to get boolean input
get_boolean_input() {
    local prompt="$1"
    local default_value="$2"
    local input
    while true; do
        input=$(get_input_with_default "$prompt" "$default_value")
        if [[ "$input" =~ ^(true|false)$ ]]; then
            echo "$input"
            break
        else
            echo "Invalid input. Please enter 'true' or 'false'."
        fi
    done
}

# Function to get port input
get_port_input() {
    local prompt="$1"
    local default_value="$2"
    local ports_array=()
    while true; do
        port=$(get_input_with_default "$prompt" "$default_value")
        if [[ -z "$port" ]]; then
            break
        elif [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
            ports_array+=("\"$port\"")
            read -rp "Do you want to add another port? (y/n): " add_more
            if [[ "$add_more" != "y" && "$add_more" != "Y" ]]; then
                break
            fi
        else
            echo "Invalid input. Please enter a valid port number (1-65535) or leave empty to finish."
        fi
    done
    if [[ ${#ports_array[@]} -gt 0 ]]; then
        echo "[$(IFS=,; echo "${ports_array[*]}") ]"
    else
        echo "[]"
    fi
}

# --- Check Processor Architecture and Download Backhaul ---
clear # Clear screen before initial messages
echo "Detecting processor architecture and downloading Backhaul..."

ARCH=$(uname -m)
DOWNLOAD_URL=""
DOWNLOADED_FILENAME="" # To store the name of the downloaded .tar.gz file

if [[ "$ARCH" == "x86_64" ]]; then
    echo "Detected x86_64 architecture. Downloading from https://github.com/amirmbn/Backhaul-Installer/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz"
    DOWNLOAD_URL="https://github.com/amirmbn/Backhaul-Installer/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz"
    DOWNLOADED_FILENAME="backhaul_linux_amd64.tar.gz"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "armv7l" || "$ARCH" == "armv8l" ]]; then
    echo "Detected ARM architecture. Downloading from https://github.com/amirmbn/Backhaul-Installer/releases/download/v0.6.5/backhaul_linux_arm64.tar.gz"
    DOWNLOAD_URL="https://github.com/amirmbn/Backhaul-Installer/releases/download/v0.6.5/backhaul_linux_arm64.tar.gz"
    DOWNLOADED_FILENAME="backhaul_linux_arm64.tar.gz"
else
    echo "Unsupported architecture: $ARCH. Please download Backhaul manually."
    exit 1
fi

# Define the full path for the downloaded tar.gz file
DOWNLOAD_PATH="/tmp/$DOWNLOADED_FILENAME" # Using /tmp for temporary storage

# Download, extract, and clean up
if [ -n "$DOWNLOAD_URL" ]; then
    echo "Downloading $DOWNLOADED_FILENAME..."
    wget -q --show-progress -O "$DOWNLOAD_PATH" "$DOWNLOAD_URL"
    
    if [ $? -eq 0 ]; then
        echo "Download complete. Extracting $DOWNLOADED_FILENAME..."
        # Extract the contents of the tar.gz file to the current directory
        tar -xzf "$DOWNLOAD_PATH"
        
        if [ $? -eq 0 ]; then
            echo "Extraction complete. Cleaning up downloaded file..."
            rm "$DOWNLOAD_PATH" # Remove the downloaded tar.gz file
            
            if [ -f "backhaul" ]; then
                chmod +x "backhaul"
                echo "Backhaul extracted and made executable successfully."
            else
                echo "Warning: 'backhaul' executable not found after extraction. Please check the contents of the tar.gz file."
            fi
        else
            echo "Failed to extract $DOWNLOADED_FILENAME."
            exit 1
        fi
    else
        echo "Failed to download Backhaul. Please check the URL or your network connection."
        exit 1
    fi
else
    echo "No download URL specified for this architecture. Exiting."
    exit 1
fi

echo "---"

clear # Clear screen before main menu
# Main menu
echo "Select Transport Type:"
echo "1. TCP"
echo "2. TCP Multiplexing"
echo "3. UDP"
echo "4. WebSocket"
echo "5. Secure WebSocket"
echo "6. WS Multiplexing"
echo "7. WSS Multiplexing"

read -rp "Please enter the number of your desired option: " transport_choice

TRANSPORT=""
case $transport_choice in
    1) TRANSPORT="tcp" ;;
    2) TRANSPORT="tcpmux" ;;
    3) TRANSPORT="udp" ;;
    4) TRANSPORT="ws" ;;
    5) TRANSPORT="wss" ;;
    6) TRANSPORT="wsmux" ;;
    7) TRANSPORT="wssmux" ;;
    *) echo "Invalid choice."; exit 1 ;;
esac

echo "---"

clear # Clear screen before mode selection
echo "Select Mode (Server or Client):"
echo "1. Server"
echo "2. Client"

read -rp "Please enter the number of your desired option: " mode_choice

MODE=""
case $mode_choice in
    1) MODE="server" ;;
    2) MODE="client" ;;
    *) echo "Invalid choice."; exit 1 ;;
esac

echo "---"

# Start creating config.toml
if [[ "$MODE" == "server" ]]; then
    clear # Clear screen before server configuration
    echo "[server]" >> "$CONFIG_FILE"

    case "$TRANSPORT" in
        "tcp")
            BIND_ADDR=$(get_input_with_default "Bind address and port (bind_addr)" "0.0.0.0:3080")
            echo "bind_addr = \"$BIND_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            ACCEPT_UDP=$(get_boolean_input "Accept UDP? (true/false)" "false")
            echo "accept_udp = $ACCEPT_UDP" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            HEARTBEAT=$(get_input_with_default "Heartbeat (seconds) (heartbeat)" "40")
            echo "heartbeat = $HEARTBEAT" >> "$CONFIG_FILE"
            CHANNEL_SIZE=$(get_input_with_default "Channel Size (channel_size)" "2048")
            echo "channel_size = $CHANNEL_SIZE" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            PORTS=$(get_port_input "Ports to monitor (e.g., 80,443). Leave empty to finish." "")
            echo "ports = $PORTS" >> "$CONFIG_FILE"
            ;;
        "tcpmux")
            BIND_ADDR=$(get_input_with_default "Bind address and port (bind_addr)" "0.0.0.0:3080")
            echo "bind_addr = \"$BIND_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            HEARTBEAT=$(get_input_with_default "Heartbeat (seconds) (heartbeat)" "40")
            echo "heartbeat = $HEARTBEAT" >> "$CONFIG_FILE"
            CHANNEL_SIZE=$(get_input_with_default "Channel Size (channel_size)" "2048")
            echo "channel_size = $CHANNEL_SIZE" >> "$CONFIG_FILE"
            MUX_CON=$(get_input_with_default "Max multiplexed connections (mux_con)" "8")
            echo "mux_con = $MUX_CON" >> "$CONFIG_FILE"
            MUX_VERSION=$(get_input_with_default "Multiplexing version (mux_version)" "1")
            echo "mux_version = $MUX_VERSION" >> "$CONFIG_FILE"
            MUX_FRAMESIZE=$(get_input_with_default "Multiplexing frame size (mux_framesize)" "32768")
            echo "mux_framesize = $MUX_FRAMESIZE" >> "$CONFIG_FILE"
            MUX_RECEIVEBUFFER=$(get_input_with_default "Multiplexing receive buffer size (mux_recievebuffer)" "4194304")
            echo "mux_recievebuffer = $MUX_RECEIVEBUFFER" >> "$CONFIG_FILE"
            MUX_STREAMBUFFER=$(get_input_with_default "Multiplexing stream buffer size (mux_streambuffer)" "65536")
            echo "mux_streambuffer = $MUX_STREAMBUFFER" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            PORTS=$(get_port_input "Ports to monitor (e.g., 80,443). Leave empty to finish." "")
            echo "ports = $PORTS" >> "$CONFIG_FILE"
            ;;
        "udp")
            BIND_ADDR=$(get_input_with_default "Bind address and port (bind_addr)" "0.0.0.0:3080")
            echo "bind_addr = \"$BIND_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            HEARTBEAT=$(get_input_with_default "Heartbeat (seconds) (heartbeat)" "20")
            echo "heartbeat = $HEARTBEAT" >> "$CONFIG_FILE"
            CHANNEL_SIZE=$(get_input_with_default "Channel Size (channel_size)" "2048")
            echo "channel_size = $CHANNEL_SIZE" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            PORTS=$(get_port_input "Ports to monitor (e.g., 80,443). Leave empty to finish." "")
            echo "ports = $PORTS" >> "$CONFIG_FILE"
            ;;
        "ws")
            BIND_ADDR=$(get_input_with_default "Bind address and port (bind_addr)" "0.0.0.0:8080")
            echo "bind_addr = \"$BIND_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CHANNEL_SIZE=$(get_input_with_default "Channel Size (channel_size)" "2048")
            echo "channel_size = $CHANNEL_SIZE" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            HEARTBEAT=$(get_input_with_default "Heartbeat (seconds) (heartbeat)" "40")
            echo "heartbeat = $HEARTBEAT" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFILE" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            PORTS=$(get_port_input "Ports to monitor (e.g., 80,443). Leave empty to finish." "")
            echo "ports = $PORTS" >> "$CONFIG_FILE"
            ;;
        "wss")
            BIND_ADDR=$(get_input_with_default "Bind address and port (bind_addr)" "0.0.0.0:8443")
            echo "bind_addr = \"$BIND_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CHANNEL_SIZE=$(get_input_with_default "Channel Size (channel_size)" "2048")
            echo "channel_size = $CHANNEL_SIZE" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            TLS_CERT=$(get_input_with_default "TLS Certificate Path (tls_cert)" "/root/server.crt")
            echo "tls_cert = \"$TLS_CERT\"" >> "$CONFIG_FILE"
            TLS_KEY=$(get_input_with_default "TLS Key Path (tls_key)" "/root/server.key")
            echo "tls_key = \"$TLS_KEY\"" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            PORTS=$(get_port_input "Ports to monitor (e.g., 80,443). Leave empty to finish." "")
            echo "ports = $PORTS" >> "$CONFIG_FILE"
            ;;
        "wsmux")
            BIND_ADDR=$(get_input_with_default "Bind address and port (bind_addr)" "0.0.0.0:3080")
            echo "bind_addr = \"$BIND_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            HEARTBEAT=$(get_input_with_default "Heartbeat (seconds) (heartbeat)" "40")
            echo "heartbeat = $HEARTBEAT" >> "$CONFIG_FILE"
            CHANNEL_SIZE=$(get_input_with_default "Channel Size (channel_size)" "2048")
            echo "channel_size = $CHANNEL_SIZE" >> "$CONFIG_FILE"
            MUX_CON=$(get_input_with_default "Max multiplexed connections (mux_con)" "8")
            echo "mux_con = $MUX_CON" >> "$CONFIG_FILE"
            MUX_VERSION=$(get_input_with_default "Multiplexing version (mux_version)" "1")
            echo "mux_version = $MUX_VERSION" >> "$CONFIG_FILE"
            MUX_FRAMESIZE=$(get_input_with_default "Multiplexing frame size (mux_framesize)" "32768")
            echo "mux_framesize = $MUX_FRAMESIZE" >> "$CONFIG_FILE"
            MUX_RECEIVEBUFFER=$(get_input_with_default "Multiplexing receive buffer size (mux_recievebuffer)" "4194304")
            echo "mux_recievebuffer = $MUX_RECEIVEBUFFER" >> "$CONFIG_FILE"
            MUX_STREAMBUFFER=$(get_input_with_default "Multiplexing stream buffer size (mux_streambuffer)" "65536")
            echo "mux_streambuffer = $MUX_STREAMBUFFER" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            PORTS=$(get_port_input "Ports to monitor (e.g., 80,443). Leave empty to finish." "")
            echo "ports = $PORTS" >> "$CONFIG_FILE"
            ;;
        "wssmux")
            BIND_ADDR=$(get_input_with_default "Bind address and port (bind_addr)" "0.0.0.0:443")
            echo "bind_addr = \"$BIND_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            HEARTBEAT=$(get_input_with_default "Heartbeat (seconds) (heartbeat)" "40")
            echo "heartbeat = $HEARTBEAT" >> "$CONFIG_FILE"
            CHANNEL_SIZE=$(get_input_with_default "Channel Size (channel_size)" "2048")
            echo "channel_size = $CHANNEL_SIZE" >> "$CONFIG_FILE"
            MUX_CON=$(get_input_with_default "Max multiplexed connections (mux_con)" "8")
            echo "mux_con = $MUX_CON" >> "$CONFIG_FILE"
            MUX_VERSION=$(get_input_with_default "Multiplexing version (mux_version)" "1")
            echo "mux_version = $MUX_VERSION" >> "$CONFIG_FILE"
            MUX_FRAMESIZE=$(get_input_with_default "Multiplexing frame size (mux_framesize)" "32768")
            echo "mux_framesize = $MUX_FRAMESIZE" >> "$CONFIG_FILE"
            MUX_RECEIVEBUFFER=$(get_input_with_default "Multiplexing receive buffer size (mux_recievebuffer)" "4194304")
            echo "mux_recievebuffer = $MUX_RECEIVEBUFFER" >> "$CONFIG_FILE"
            MUX_STREAMBUFFER=$(get_input_with_default "Multiplexing stream buffer size (mux_streambuffer)" "65536")
            echo "mux_streambuffer = $MUX_STREAMBUFFER" >> "$CONFIG_FILE"
            TLS_CERT=$(get_input_with_default "TLS Certificate Path (tls_cert)" "/root/server.crt")
            echo "tls_cert = \"$TLS_CERT\"" >> "$CONFIG_FILE"
            TLS_KEY=$(get_input_with_default "TLS Key Path (tls_key)" "/root/server.key")
            echo "tls_key = \"$TLS_KEY\"" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            PORTS=$(get_port_input "Ports to monitor (e.g., 80,443). Leave empty to finish." "")
            echo "ports = $PORTS" >> "$CONFIG_FILE"
            ;;
    esac

elif [[ "$MODE" == "client" ]]; then
    clear # Clear screen before client configuration
    echo "[client]" >> "$CONFIG_FILE"

    case "$TRANSPORT" in
        "tcp")
            REMOTE_ADDR=$(get_input_with_default "Enter IR VPS IP address and port (remote_addr)" "0.0.0.0:3080")
            echo "remote_addr = \"$REMOTE_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CONNECTION_POOL=$(get_input_with_default "Connection Pool Size (connection_pool)" "8")
            echo "connection_pool = $CONNECTION_POOL" >> "$CONFIG_FILE"
            AGGRESSIVE_POOL=$(get_boolean_input "Enable Aggressive Pool? (true/false)" "false")
            echo "aggressive_pool = $AGGRESSIVE_POOL" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            DIAL_TIMEOUT=$(get_input_with_default "Dial Timeout (seconds) (dial_timeout)" "10")
            echo "dial_timeout = $DIAL_TIMEOUT" >> "$CONFIG_FILE"
            RETRY_INTERVAL=$(get_input_with_default "Retry Interval (seconds) (retry_interval)" "3")
            echo "retry_interval = $RETRY_INTERVAL" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            ;;
        "tcpmux")
            REMOTE_ADDR=$(get_input_with_default "Enter IR VPS IP address and port (remote_addr)" "0.0.0.0:3080")
            echo "remote_addr = \"$REMOTE_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CONNECTION_POOL=$(get_input_with_default "Connection Pool Size (connection_pool)" "8")
            echo "connection_pool = $CONNECTION_POOL" >> "$CONFIG_FILE"
            AGGRESSIVE_POOL=$(get_boolean_input "Enable Aggressive Pool? (true/false)" "false")
            echo "aggressive_pool = $AGGRESSIVE_POOL" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            DIAL_TIMEOUT=$(get_input_with_default "Dial Timeout (seconds) (dial_timeout)" "10")
            echo "dial_timeout = $DIAL_TIMEOUT" >> "$CONFIG_FILE"
            RETRY_INTERVAL=$(get_input_with_default "Retry Interval (seconds) (retry_interval)" "3")
            echo "retry_interval = $RETRY_INTERVAL" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            MUX_VERSION=$(get_input_with_default "Multiplexing version (mux_version)" "1")
            echo "mux_version = $MUX_VERSION" >> "$CONFIG_FILE"
            MUX_FRAMESIZE=$(get_input_with_default "Multiplexing frame size (mux_framesize)" "32768")
            echo "mux_framesize = $MUX_FRAMESIZE" >> "$CONFIG_FILE"
            MUX_RECEIVEBUFFER=$(get_input_with_default "Multiplexing receive buffer size (mux_recievebuffer)" "4194304")
            echo "mux_recievebuffer = $MUX_RECEIVEBUFFER" >> "$CONFIG_FILE"
            MUX_STREAMBUFFER=$(get_input_with_default "Multiplexing stream buffer size (mux_streambuffer)" "65536")
            echo "mux_streambuffer = $MUX_STREAMBUFFER" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            ;;
        "udp")
            REMOTE_ADDR=$(get_input_with_default "Enter IR VPS IP address and port (remote_addr)" "0.0.0.0:3080")
            echo "remote_addr = \"$REMOTE_ADDR\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CONNECTION_POOL=$(get_input_with_default "Connection Pool Size (connection_pool)" "8")
            echo "connection_pool = $CONNECTION_POOL" >> "$CONFIG_FILE"
            AGGRESSIVE_POOL=$(get_boolean_input "Enable Aggressive Pool? (true/false)" "false")
            echo "aggressive_pool = $AGGRESSIVE_POOL" >> "$CONFIG_FILE"
            RETRY_INTERVAL=$(get_input_with_default "Retry Interval (seconds) (retry_interval)" "3")
            echo "retry_interval = $RETRY_INTERVAL" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            ;;
        "ws")
            REMOTE_ADDR=$(get_input_with_default "Enter IR VPS IP address and port (remote_addr)" "0.0.0.0:8080")
            echo "remote_addr = \"$REMOTE_ADDR\"" >> "$CONFIG_FILE"
            EDGE_IP=$(get_input_with_default "Edge IP (edge_ip)" "")
            echo "edge_ip = \"$EDGE_IP\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CONNECTION_POOL=$(get_input_with_default "Connection Pool Size (connection_pool)" "8")
            echo "connection_pool = $CONNECTION_POOL" >> "$CONFIG_FILE"
            AGGRESSIVE_POOL=$(get_boolean_input "Enable Aggressive Pool? (true/false)" "false")
            echo "aggressive_pool = $AGGRESSIVE_POOL" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            DIAL_TIMEOUT=$(get_input_with_default "Dial Timeout (seconds) (dial_timeout)" "10")
            echo "dial_timeout = $DIAL_TIMEOUT" >> "$CONFIG_FILE"
            RETRY_INTERVAL=$(get_input_with_default "Retry Interval (seconds) (retry_interval)" "3")
            echo "retry_interval = $RETRY_INTERVAL" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            ;;
        "wss")
            REMOTE_ADDR=$(get_input_with_default "Enter IR VPS IP address and port (remote_addr)" "0.0.0.0:8443")
            echo "remote_addr = \"$REMOTE_ADDR\"" >> "$CONFIG_FILE"
            EDGE_IP=$(get_input_with_default "Edge IP (edge_ip)" "")
            echo "edge_ip = \"$EDGE_IP\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CONNECTION_POOL=$(get_input_with_default "Connection Pool Size (connection_pool)" "8")
            echo "connection_pool = $CONNECTION_POOL" >> "$CONFIG_FILE"
            AGGRESSIVE_POOL=$(get_boolean_input "Enable Aggressive Pool? (true/false)" "false")
            echo "aggressive_pool = $AGGRESSIVE_POOL" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            DIAL_TIMEOUT=$(get_input_with_default "Dial Timeout (seconds) (dial_timeout)" "10")
            echo "dial_timeout = $DIAL_TIMEOUT" >> "$CONFIG_FILE"
            RETRY_INTERVAL=$(get_input_with_default "Retry Interval (seconds) (retry_interval)" "3")
            echo "retry_interval = $RETRY_INTERVAL" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            ;;
        "wsmux")
            REMOTE_ADDR=$(get_input_with_default "Enter IR VPS IP address and port (remote_addr)" "0.0.0.0:3080")
            echo "remote_addr = \"$REMOTE_ADDR\"" >> "$CONFIG_FILE"
            EDGE_IP=$(get_input_with_default "Edge IP (edge_ip)" "")
            echo "edge_ip = \"$EDGE_IP\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            CONNECTION_POOL=$(get_input_with_default "Connection Pool Size (connection_pool)" "8")
            echo "connection_pool = $CONNECTION_POOL" >> "$CONFIG_FILE"
            AGGRESSIVE_POOL=$(get_boolean_input "Enable Aggressive Pool? (true/false)" "false")
            echo "aggressive_pool = $AGGRESSIVE_POOL" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            DIAL_TIMEOUT=$(get_input_with_default "Dial Timeout (seconds) (dial_timeout)" "10")
            echo "dial_timeout = $DIAL_TIMEOUT" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            RETRY_INTERVAL=$(get_input_with_default "Retry Interval (seconds) (retry_interval)" "3")
            echo "retry_interval = $RETRY_INTERVAL" >> "$CONFIG_FILE"
            MUX_VERSION=$(get_input_with_default "Multiplexing version (mux_version)" "1")
            echo "mux_version = $MUX_VERSION" >> "$CONFIG_FILE"
            MUX_FRAMESIZE=$(get_input_with_default "Multiplexing frame size (mux_framesize)" "32768")
            echo "mux_framesize = $MUX_FRAMESIZE" >> "$CONFIG_FILE"
            MUX_RECEIVEBUFFER=$(get_input_with_default "Multiplexing receive buffer size (mux_recievebuffer)" "4194304")
            echo "mux_recievebuffer = $MUX_RECEIVEBUFFER" >> "$CONFIG_FILE"
            MUX_STREAMBUFFER=$(get_input_with_default "Multiplexing stream buffer size (mux_streambuffer)" "65536")
            echo "mux_streambuffer = $MUX_STREAMBUFFER" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            ;;
        "wssmux")
            REMOTE_ADDR=$(get_input_with_default "Enter IR VPS IP address and port (remote_addr)" "0.0.0.0:443")
            echo "remote_addr = \"$REMOTE_ADDR\"" >> "$CONFIG_FILE"
            EDGE_IP=$(get_input_with_default "Edge IP (edge_ip)" "")
            echo "edge_ip = \"$EDGE_IP\"" >> "$CONFIG_FILE"
            echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE"
            TOKEN=$(get_input_with_default "Token (token)" "your_token")
            echo "token = \"$TOKEN\"" >> "$CONFIG_FILE"
            KEEPALIVE_PERIOD=$(get_input_with_default "Keepalive Period (seconds) (keepalive_period)" "75")
            echo "keepalive_period = $KEEPALIVE_PERIOD" >> "$CONFIG_FILE"
            DIAL_TIMEOUT=$(get_input_with_default "Dial Timeout (seconds) (dial_timeout)" "10")
            echo "dial_timeout = $DIAL_TIMEOUT" >> "$CONFIG_FILE"
            NODELAY=$(get_boolean_input "Enable Nodelay? (true/false)" "true")
            echo "nodelay = $NODELAY" >> "$CONFIG_FILE"
            RETRY_INTERVAL=$(get_input_with_default "Retry Interval (seconds) (retry_interval)" "3")
            echo "retry_interval = $RETRY_INTERVAL" >> "$CONFIG_FILE"
            CONNECTION_POOL=$(get_input_with_default "Connection Pool Size (connection_pool)" "8")
            echo "connection_pool = $CONNECTION_POOL" >> "$CONFIG_FILE"
            AGGRESSIVE_POOL=$(get_boolean_input "Enable Aggressive Pool? (true/false)" "false")
            echo "aggressive_pool = $AGGRESSIVE_POOL" >> "$CONFIG_FILE"
            MUX_VERSION=$(get_input_with_default "Multiplexing version (mux_version)" "1")
            echo "mux_version = $MUX_VERSION" >> "$CONFIG_FILE"
            MUX_FRAMESIZE=$(get_input_with_default "Multiplexing frame size (mux_framesize)" "32768")
            echo "mux_framesize = $MUX_FRAMESIZE" >> "$CONFIG_FILE"
            MUX_RECEIVEBUFFER=$(get_input_with_default "Multiplexing receive buffer size (mux_recievebuffer)" "4194304")
            echo "mux_recievebuffer = $MUX_RECEIVEBUFFER" >> "$CONFIG_FILE"
            MUX_STREAMBUFFER=$(get_input_with_default "Multiplexing stream buffer size (mux_streambuffer)" "65536")
            echo "mux_streambuffer = $MUX_STREAMBUFFER" >> "$CONFIG_FILE"
            SNIFFER=$(get_boolean_input "Enable Sniffer? (true/false)" "false")
            echo "sniffer = $SNIFFER" >> "$CONFIG_FILE"
            WEB_PORT=$(get_input_with_default "Web Port (web_port)" "2060")
            echo "web_port = $WEB_PORT" >> "$CONFIG_FILE"
            SNIFFER_LOG=$(get_input_with_default "Sniffer Log File Path (sniffer_log)" "/root/backhaul.json")
            echo "sniffer_log = \"$SNIFFER_LOG\"" >> "$CONFIG_FILE"
            LOG_LEVEL=$(get_input_with_default "Log Level (log_level) (debug, info, warn, error)" "info")
            echo "log_level = \"$LOG_LEVEL\"" >> "$CONFIG_FILE"
            ;;
    esac
fi

clear # Clear screen before displaying the final config and running Backhaul
echo "---"
echo "Configuration file ($CONFIG_FILE) created successfully:"
echo "---"
cat "$CONFIG_FILE" # Display the generated config file
echo ""

# Create the systemd service file
SERVICE_FILE="/etc/systemd/system/backhaul.service"
echo "[Unit]
Description=Backhaul Reverse Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/root/backhaul -c /root/config.toml
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target" | sudo tee "$SERVICE_FILE" > /dev/null

echo "Systemd service file created at $SERVICE_FILE"

# Reload systemd, enable, and start the service
sudo systemctl daemon-reload
sudo systemctl enable backhaul.service
sudo systemctl start backhaul.service

echo "Backhaul service enabled and started."