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

# Function to get port input (array of strings)
get_port_input() {
    local prompt="$1"
    local default_value="$2"
    local ports_array=()
    while true; do
        port=$(get_input_with_default "$prompt" "$default_value")
        if [[ -z "$port" ]]; then
            break # Exit loop if input is empty
        elif [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
            ports_array+=("\"$port\"") # Add with quotes for TOML array of strings
            # Loop continues until empty input
        else
            echo "Invalid input. Please enter a valid port number (1-65535) or leave empty to finish."
        fi
    done
    if [[ ${#ports_array[@]} -gt 0 ]]; then
        echo "[$(IFS=,; echo "${ports_array[*]}") ]" # Format as TOML array
    else
        echo "[]"
    fi
}

# Function to write a config entry based on type
# Parameters: param_name, prompt_text, default_value, input_type
write_config_entry() {
    local param_name="$1"
    local prompt_text="$2"
    local default_value="$3"
    local input_type="$4"
    local value

    case "$input_type" in
        "string")
            value=$(get_input_with_default "$prompt_text" "$default_value")
            echo "$param_name = \"$value\"" >> "$CONFIG_FILE"
            ;;
        "integer")
            value=$(get_input_with_default "$prompt_text" "$default_value")
            echo "$param_name = $value" >> "$CONFIG_FILE"
            ;;
        "boolean")
            value=$(get_boolean_input "$prompt_text" "$default_value")
            echo "$param_name = $value" >> "$CONFIG_FILE"
            ;;
        "port_array")
            value=$(get_port_input "$prompt_text" "$default_value")
            echo "$param_name = $value" >> "$CONFIG_FILE"
            ;;
        *)
            echo "Error: Unknown input type '$input_type' for parameter '$param_name'."
            exit 1
            ;;
    esac
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

# Remove existing config file if it exists
[ -f "$CONFIG_FILE" ] && rm "$CONFIG_FILE"

# Declare associative arrays for configuration parameters
declare -A SERVER_DEFAULTS
declare -A CLIENT_DEFAULTS

# Common server defaults (param_name:default_value:input_type)
SERVER_DEFAULTS=(
    ["token"]="your_token:string"
    ["channel_size"]="2048:integer"
    ["sniffer"]="false:boolean"
    ["web_port"]="2060:integer"
    ["sniffer_log"]="/root/backhaul.json:string"
    ["log_level"]="info:string"
    ["ports"]=":port_array" # Default empty for port array
)

# Common client defaults (param_name:default_value:input_type)
CLIENT_DEFAULTS=(
    ["token"]="your_token:string"
    ["connection_pool"]="8:integer"
    ["aggressive_pool"]="false:boolean"
    ["retry_interval"]="3:integer"
    ["sniffer"]="false:boolean"
    ["web_port"]="2060:integer"
    ["sniffer_log"]="/root/backhaul.json:string"
    ["log_level"]="info:string"
)

# Transport-specific overrides and additions for server
# Format: "param_name:default_value:input_type;param_name:default_value:input_type"
declare -A SERVER_TRANSPORT_CONFIG
SERVER_TRANSPORT_CONFIG=(
    ["tcp"]="bind_addr:0.0.0.0:3080:string;accept_udp:false:boolean;keepalive_period:75:integer;nodelay:true:boolean;heartbeat:40:integer"
    ["tcpmux"]="bind_addr:0.0.0.0:3080:string;keepalive_period:75:integer;nodelay:true:boolean;heartbeat:40:integer;mux_con:8:integer;mux_version:1:integer;mux_framesize:32768:integer;mux_recievebuffer:4194304:integer;mux_streambuffer:65536:integer"
    ["udp"]="bind_addr:0.0.0.0:3080:string;heartbeat:20:integer"
    ["ws"]="bind_addr:0.0.0.0:8080:string;keepalive_period:75:integer;heartbeat:40:integer;nodelay:true:boolean"
    ["wss"]="bind_addr:0.0.0.0:8443:string;keepalive_period:75:integer;heartbeat:40:integer;nodelay:true:boolean;tls_cert:/root/server.crt:string;tls_key:/root/server.key:string"
    ["wsmux"]="bind_addr:0.0.0.0:3080:string;keepalive_period:75:integer;nodelay:true:boolean;heartbeat:40:integer;mux_con:8:integer;mux_version:1:integer;mux_framesize:32768:integer;mux_recievebuffer:4194304:integer;mux_streambuffer:65536:integer"
    ["wssmux"]="bind_addr:0.0.0.0:443:string;keepalive_period:75:integer;nodelay:true:boolean;heartbeat:40:integer;mux_con:8:integer;mux_version:1:integer;mux_framesize:32768:integer;mux_recievebuffer:4194304:integer;mux_streambuffer:65536:integer;tls_cert:/root/server.crt:string;tls_key:/root/server.key:string"
)

# Transport-specific overrides and additions for client
# Format: "param_name:default_value:input_type;param_name:default_value:input_type"
declare -A CLIENT_TRANSPORT_CONFIG
CLIENT_TRANSPORT_CONFIG=(
    ["tcp"]="remote_addr:0.0.0.0:3080:string;keepalive_period:75:integer;dial_timeout:10:integer;nodelay:true:boolean"
    ["tcpmux"]="remote_addr:0.0.0.0:3080:string;keepalive_period:75:integer;dial_timeout:10:integer;nodelay:true:boolean;mux_version:1:integer;mux_framesize:32768:integer;mux_recievebuffer:4194304:integer;mux_streambuffer:65536:integer"
    ["udp"]="remote_addr:0.0.0.0:3080:string" # UDP client has fewer unique parameters
    ["ws"]="remote_addr:0.0.0.0:8080:string;edge_ip::string;keepalive_period:75:integer;dial_timeout:10:integer;nodelay:true:boolean"
    ["wss"]="remote_addr:0.0.0.0:8443:string;edge_ip::string;keepalive_period:75:integer;dial_timeout:10:integer;nodelay:true:boolean" # Heartbeat is not explicitly in original client WSS
    ["wsmux"]="remote_addr:0.0.0.0:3080:string;edge_ip::string;keepalive_period:75:integer;dial_timeout:10:integer;nodelay:true:boolean;mux_version:1:integer;mux_framesize:32768:integer;mux_recievebuffer:4194304:integer;mux_streambuffer:65536:integer"
    ["wssmux"]="remote_addr:0.0.0.0:443:string;edge_ip::string;keepalive_period:75:integer;dial_timeout:10:integer;nodelay:true:boolean;mux_version:1:integer;mux_framesize:32768:integer;mux_recievebuffer:4194304:integer;mux_streambuffer:65536:integer"
)

# Start creating config.toml
if [[ "$MODE" == "server" ]]; then
    clear # Clear screen before server configuration
    echo "[server]" >> "$CONFIG_FILE"
    echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE" # Transport is always written first

    # Collect all parameters for server
    declare -A current_config
    for entry in "${!SERVER_DEFAULTS[@]}"; do
        IFS=':' read -r param_name default_value input_type <<< "${SERVER_DEFAULTS[$entry]}"
        current_config["$param_name"]="$default_value:$input_type"
    done

    # Add transport-specific parameters, overriding defaults if necessary
    IFS=';' read -ra ADDR <<< "${SERVER_TRANSPORT_CONFIG[$TRANSPORT]}"
    for i in "${ADDR[@]}"; do
        IFS=':' read -r param_name default_value input_type <<< "$i"
        current_config["$param_name"]="$default_value:$input_type"
    done

    # Prompt and write to config file
    for param_name in "${!current_config[@]}"; do
        IFS=':' read -r default_value input_type <<< "${current_config[$param_name]}"
        # Special handling for 'ports' prompt to be more specific
        if [[ "$param_name" == "ports" ]]; then
            write_config_entry "$param_name" "Ports to monitor (e.g., 80,443). Leave empty to finish." "$default_value" "$input_type"
        else
            # Generate a user-friendly prompt from the parameter name
            prompt_text="$(tr '_' ' ' <<< "$param_name" | sed -e "s/\b\(.\)/\u\1/g") ($param_name)"
            write_config_entry "$param_name" "$prompt_text" "$default_value" "$input_type"
        fi
    done

elif [[ "$MODE" == "client" ]]; then
    clear # Clear screen before client configuration
    echo "[client]" >> "$CONFIG_FILE"
    echo "transport = \"$TRANSPORT\"" >> "$CONFIG_FILE" # Transport is always written first

    # Collect all parameters for client
    declare -A current_config
    for entry in "${!CLIENT_DEFAULTS[@]}"; do
        IFS=':' read -r param_name default_value input_type <<< "${CLIENT_DEFAULTS[$entry]}"
        current_config["$param_name"]="$default_value:$input_type"
    done

    # Add transport-specific parameters, overriding defaults if necessary
    IFS=';' read -ra ADDR <<< "${CLIENT_TRANSPORT_CONFIG[$TRANSPORT]}"
    for i in "${ADDR[@]}"; do
        IFS=':' read -r param_name default_value input_type <<< "$i"
        current_config["$param_name"]="$default_value:$input_type"
    done

    # Prompt and write to config file
    for param_name in "${!current_config[@]}"; do
        IFS=':' read -r default_value input_type <<< "${current_config[$param_name]}"
        # Special handling for 'remote_addr' and 'edge_ip' prompts
        if [[ "$param_name" == "remote_addr" ]]; then
            write_config_entry "$param_name" "Enter IR VPS IP address and port ($param_name)" "$default_value" "$input_type"
        elif [[ "$param_name" == "edge_ip" ]]; then
            write_config_entry "$param_name" "Edge IP ($param_name)" "$default_value" "$input_type"
        else
            # Generate a user-friendly prompt from the parameter name
            prompt_text="$(tr '_' ' ' <<< "$param_name" | sed -e "s/\b\(.\)/\u\1/g") ($param_name)"
            write_config_entry "$param_name" "$prompt_text" "$default_value" "$input_type"
        fi
    done
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
