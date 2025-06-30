const readline = require('readline');
const fs = require('fs');
const { exec, execSync } = require('child_process');
const path = require('path');

const CONFIG_FILE = 'config.toml';
const BACKHAUL_EXECUTABLE = './backhaul';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

/**
 * Prompts the user for input with a default value.
 * @param {string} prompt - The prompt message.
 * @param {string} defaultValue - The default value to suggest.
 * @returns {Promise<string>} The user's input or the default value.
 */
function getInputWithDefault(prompt, defaultValue) {
    return new Promise(resolve => {
        rl.question(`${prompt} (Default: ${defaultValue}): `, input => {
            resolve(input || defaultValue);
        });
    });
}

/**
 * Prompts the user for port input, allowing multiple entries.
 * @param {string} prompt - The prompt message.
 * @returns {Promise<string[]>} An array of valid port numbers as strings.
 */
async function getPortInput(prompt) {
    const ports = [];
    while (true) {
        const port = await getInputWithDefault(prompt, '');
        if (!port) {
            break; // User pressed Enter without input
        }

        const portNum = parseInt(port, 10);
        if (isNaN(portNum) || portNum < 1 || portNum > 65535) {
            console.log("Invalid input. Please enter a valid port number (1-65535) or leave empty to finish.");
        } else {
            ports.push(`"${port}"`); // Store as string with quotes for TOML
            const addMore = await getInputWithDefault("Do you want to add another port? (y/n)", "n");
            if (addMore.toLowerCase() !== 'y') {
                break;
            }
        }
    }
    return `[${ports.join(',')}]`;
}

/**
 * Executes a shell command.
 * @param {string} command - The command to execute.
 * @returns {Promise<string>} The stdout of the command.
 */
function executeCommand(command) {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                console.error(`Error executing command: ${command}\n${stderr}`);
                return reject(error);
            }
            resolve(stdout.trim());
        });
    });
}

/**
 * Main function to run the configuration script.
 */
async function main() {
    console.log("Detecting processor architecture and downloading Backhaul...");

    let arch;
    try {
        arch = execSync('uname -m').toString().trim();
    } catch (error) {
        console.error("Failed to detect architecture. Please ensure 'uname' is available.");
        process.exit(1);
    }

    let downloadUrl = '';
    if (arch === 'x86_64') {
        console.log("Detected x86_64 architecture. Downloading from https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz");
        downloadUrl = "https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz";
    } else if (arch === 'aarch64' || arch === 'armv7l' || arch === 'armv8l') {
        console.log("Detected ARM architecture. Downloading from https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_arm64.tar.gz");
        downloadUrl = "https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_arm64.tar.gz";
    } else {
        console.log(`Unsupported architecture: ${arch}. Please download Backhaul manually.`);
        rl.close();
        process.exit(1);
    }

    try {
        console.log(`Downloading Backhaul to ${BACKHAUL_EXECUTABLE}...`);
        execSync(`wget -q --show-progress -O ${BACKHAUL_EXECUTABLE} ${downloadUrl}`);
        fs.chmodSync(BACKHAUL_EXECUTABLE, '755'); // rwx for owner, rx for others
        console.log("Backhaul downloaded and made executable successfully.");
    } catch (error) {
        console.error("Failed to download Backhaul. Please check the URL or your network connection.");
        rl.close();
        process.exit(1);
    }

    console.log("---");

    console.log("Select Transport Type:");
    console.log("1. TCP");
    console.log("2. TCP Multiplexing");
    console.log("3. UDP");
    console.log("4. WebSocket");
    console.log("5. Secure WebSocket");
    console.log("6. WS Multiplexing");
    console.log("7. WSS Multiplexing");

    const transportChoice = await getInputWithDefault("Please enter the number of your desired option", "1");
    let transport = "";
    switch (transportChoice) {
        case '1': transport = "tcp"; break;
        case '2': transport = "tcpmux"; break;
        case '3': transport = "udp"; break;
        case '4': transport = "ws"; break;
        case '5': transport = "wss"; break;
        case '6': transport = "ws_multiplexing"; break;
        case '7': transport = "wss_multiplexing"; break;
        default: console.log("Invalid choice."); rl.close(); process.exit(1);
    }

    console.log("---");

    console.log("Select Mode (Server or Client):");
    console.log("1. Server");
    console.log("2. Client");

    const modeChoice = await getInputWithDefault("Please enter the number of your desired option", "1");
    let mode = "";
    switch (modeChoice) {
        case '1': mode = "server"; break;
        case '2': mode = "client"; break;
        default: console.log("Invalid choice."); rl.close(); process.exit(1);
    }

    console.log("---");

    let configContent = "# Backhaul Configuration\n\n";

    if (mode === "server") {
        configContent += "[server]\n";
        configContent += `bind_addr = "${await getInputWithDefault("Bind address and port (bind_addr)", "0.0.0.0:3080")}"\n`;
        configContent += `transport = "${transport}"\n`;

        if (transport === "tcp" || transport === "udp") {
            configContent += `accept_udp = ${await getInputWithDefault("Accept UDP? (true/false)", "false")}\n`;
        }

        configContent += `token = "${await getInputWithDefault("Token (token)", "your_token")}"\n`;
        configContent += `keepalive_period = ${await getInputWithDefault("Keepalive Period (seconds) (keepalive_period)", "75")}\n`;
        configContent += `nodelay = ${await getInputWithDefault("Enable Nodelay? (true/false)", "true")}\n`;
        configContent += `heartbeat = ${await getInputWithDefault("Heartbeat (seconds) (heartbeat)", "40")}\n`;
        configContent += `channel_size = ${await getInputWithDefault("Channel Size (channel_size)", "2048")}\n`;

        if (transport === "tcpmux") {
            configContent += `mux_con = ${await getInputWithDefault("Max multiplexed connections (mux_con)", "8")}\n`;
            configContent += `mux_version = ${await getInputWithDefault("Multiplexing version (mux_version)", "1")}\n`;
            configContent += `mux_framesize = ${await getInputWithDefault("Multiplexing frame size (mux_framesize)", "32768")}\n`;
            configContent += `mux_recievebuffer = ${await getInputWithDefault("Multiplexing receive buffer size (mux_recievebuffer)", "4194304")}\n`;
            configContent += `mux_streambuffer = ${await getInputWithDefault("Multiplexing stream buffer size (mux_streambuffer)", "65536")}\n`;
        }

        configContent += `sniffer = ${await getInputWithDefault("Enable Sniffer? (true/false)", "false")}\n`;
        configContent += `web_port = ${await getInputWithDefault("Web Port (web_port)", "2060")}\n`;
        configContent += `sniffer_log = "${await getInputWithDefault("Sniffer Log File Path (sniffer_log)", "/root/backhaul.json")}"\n`;
        configContent += `log_level = "${await getInputWithDefault("Log Level (log_level) (debug, info, warn, error)", "info")}"\n`;
        configContent += `ports = ${await getPortInput("Ports to monitor (e.g., 80,443). Leave empty to finish.")}\n`;

    } else if (mode === "client") {
        configContent += "[client]\n";
        configContent += `remote_addr = "${await getInputWithDefault("Remote address and port (remote_addr)", "0.0.0.0:3080")}"\n`;
        configContent += `transport = "${transport}"\n`;
        configContent += `token = "${await getInputWithDefault("Token (token)", "your_token")}"\n`;
        configContent += `connection_pool = ${await getInputWithDefault("Connection Pool Size (connection_pool)", "8")}\n`;
        configContent += `aggressive_pool = ${await getInputWithDefault("Enable Aggressive Pool? (true/false)", "false")}\n`;
        configContent += `keepalive_period = ${await getInputWithDefault("Keepalive Period (seconds) (keepalive_period)", "75")}\n`;
        configContent += `dial_timeout = ${await getInputWithDefault("Dial Timeout (seconds) (dial_timeout)", "10")}\n`;
        configContent += `retry_interval = ${await getInputWithDefault("Retry Interval (seconds) (retry_interval)", "3")}\n`;
        configContent += `nodelay = ${await getInputWithDefault("Enable Nodelay? (true/false)", "true")}\n`;

        if (transport === "tcpmux") {
            configContent += `mux_version = ${await getInputWithDefault("Multiplexing version (mux_version)", "1")}\n`;
            configContent += `mux_framesize = ${await getInputWithDefault("Multiplexing frame size (mux_framesize)", "32768")}\n`;
            configContent += `mux_recievebuffer = ${await getInputWithDefault("Multiplexing receive buffer size (mux_recievebuffer)", "4194304")}\n`;
            configContent += `mux_streambuffer = ${await getInputWithDefault("Multiplexing stream buffer size (mux_streambuffer)", "65536")}\n`;
        }

        configContent += `sniffer = ${await getInputWithDefault("Enable Sniffer? (true/false)", "false")}\n`;
        configContent += `web_port = ${await getInputWithDefault("Web Port (web_port)", "2060")}\n`;
        configContent += `sniffer_log = "${await getInputWithDefault("Sniffer Log File Path (sniffer_log)", "/root/backhaul.json")}"\n`;
        configContent += `log_level = "${await getInputWithDefault("Log Level (log_level) (debug, info, warn, error)", "info")}"\n`;
    }

    try {
        fs.writeFileSync(CONFIG_FILE, configContent);
        console.log("---");
        console.log(`Configuration file (${CONFIG_FILE}) created successfully:`);
        console.log("---");
        console.log(configContent);
        console.log("---");

        console.log("Running Backhaul with the new configuration file...");
        if (fs.existsSync(BACKHAUL_EXECUTABLE)) {
            // Using spawn for long-running processes
            const backhaulProcess = exec(`${BACKHAUL_EXECUTABLE} -c ${CONFIG_FILE}`);

            backhaulProcess.stdout.on('data', (data) => {
                process.stdout.write(data);
            });

            backhaulProcess.stderr.on('data', (data) => {
                process.stderr.write(data);
            });

            backhaulProcess.on('close', (code) => {
                console.log(`Backhaul process exited with code ${code}`);
                rl.close();
            });

            // You might want to add a listener for Ctrl+C to gracefully close rl
            rl.on('SIGINT', () => {
                console.log('\nCtrl+C detected, stopping Backhaul and exiting.');
                backhaulProcess.kill('SIGINT'); // Send SIGINT to backhaul
                rl.close();
            });

        } else {
            console.error(`Error: Backhaul executable not found at ${BACKHAUL_EXECUTABLE}. Please check the download or path.`);
            rl.close();
            process.exit(1);
        }

    } catch (error) {
        console.error("Error creating or running configuration:", error);
        rl.close();
        process.exit(1);
    }
}

main();
