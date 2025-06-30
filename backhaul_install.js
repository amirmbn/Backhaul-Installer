const readline = require('readline');
const fs = require('fs/promises'); // Use fs.promises for async file operations
const os = require('os');
const { exec } = require('child_process');
const path = require('path');

// Use node-fetch for Node.js versions < 18. For Node.js 18+, `fetch` is global.
const fetch = typeof globalThis.fetch === 'function' ? globalThis.fetch : require('node-fetch');

const CONFIG_FILE = 'config.toml';

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

/**
 * Prompts the user for input with a default value.
 * @param {string} prompt - The prompt message.
 * @param {string} defaultValue - The default value to use if no input is provided.
 * @returns {Promise<string>} The user's input or the default value.
 */
function getInputWithDefault(prompt, defaultValue) {
    return new Promise(resolve => {
        rl.question(`${prompt} (Default: ${defaultValue}): `, userInput => {
            resolve(userInput.trim() === '' ? defaultValue : userInput.trim());
        });
    });
}

/**
 * Prompts the user for port input, allowing multiple valid ports.
 * @param {string} prompt - The prompt message.
 * @param {string} defaultValue - The default value for the first port.
 * @returns {Promise<string>} A string representation of the ports array for TOML.
 */
async function getPortInput(prompt, defaultValue) {
    const portsArray = [];
    while (true) {
        const port = await getInputWithDefault(prompt, defaultValue);
        if (port === '') {
            break;
        }

        const portNum = parseInt(port, 10);
        if (isNaN(portNum) || portNum < 1 || portNum > 65535) {
            console.log("Invalid input. Please enter a valid port number (1-65535) or leave empty to finish.");
            continue;
        }

        portsArray.push(`"${portNum}"`);

        const addMore = await getInputWithDefault("Do you want to add another port? (y/n)", "n");
        if (addMore.toLowerCase() !== 'y') {
            break;
        }
    }
    return `[${portsArray.join(', ')}]`;
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
                console.error(`Error executing command: ${command}`);
                console.error(`stderr: ${stderr}`);
                return reject(error);
            }
            resolve(stdout);
        });
    });
}

/**
 * Main function to run the configuration and Backhaul setup.
 */
async function main() {
    console.log("Detecting processor architecture and downloading Backhaul...");

    const arch = os.arch();
    let downloadUrl = "";
    let downloadedFilename = "";

    if (arch === 'x64') {
        console.log("Detected x86_64 architecture. Downloading from https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz");
        downloadUrl = "https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_amd64.tar.gz";
        downloadedFilename = "backhaul_linux_amd64.tar.gz";
    } else if (arch === 'arm64' || arch === 'arm') { // 'arm' might catch armv7l/armv8l depending on Node.js build
        console.log("Detected ARM architecture. Downloading from https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_arm64.tar.gz");
        downloadUrl = "https://github.com/Musixal/Backhaul/releases/download/v0.6.5/backhaul_linux_arm64.tar.gz";
        downloadedFilename = "backhaul_linux_arm64.tar.gz";
    } else {
        console.error(`Unsupported architecture: ${arch}. Please download Backhaul manually.`);
        rl.close();
        process.exit(1);
    }

    const downloadPath = path.join(os.tmpdir(), downloadedFilename);

    if (downloadUrl) {
        try {
            console.log(`Downloading ${downloadedFilename}...`);
            const response = await fetch(downloadUrl);
            if (!response.ok) {
                throw new Error(`Failed to download: ${response.statusText}`);
            }

            const arrayBuffer = await response.arrayBuffer();
            await fs.writeFile(downloadPath, Buffer.from(arrayBuffer));
            console.log("Download complete.");

            console.log(`Extracting ${downloadedFilename}...`);
            await executeCommand(`tar -xzf "${downloadPath}"`);
            console.log("Extraction complete. Cleaning up downloaded file...");
            await fs.unlink(downloadPath);

            const backhaulExecutable = 'backhaul'; // Assuming the extracted executable is named 'backhaul'
            try {
                await fs.access(backhaulExecutable, fs.constants.F_OK); // Check if file exists
                await executeCommand(`chmod +x "${backhaulExecutable}"`);
                console.log("Backhaul extracted and made executable successfully.");
            } catch (error) {
                console.warn(`Warning: '${backhaulExecutable}' executable not found after extraction. Please check the contents of the tar.gz file.`);
            }

        } catch (error) {
            console.error("Failed to download or extract Backhaul:", error.message);
            rl.close();
            process.exit(1);
        }
    } else {
        console.log("No download URL specified for this architecture. Exiting.");
        rl.close();
        process.exit(1);
    }

    console.log("---");

    // --- Main menu ---
    console.log("Select Transport Type:");
    console.log("1. TCP");
    console.log("2. TCP Multiplexing");
    console.log("3. UDP");
    console.log("4. WebSocket");
    console.log("5. Secure WebSocket");
    console.log("6. WS Multiplexing");
    console.log("7. WSS Multiplexing");

    const transportChoice = await getInputWithDefault("Please enter the number of your desired option", "");

    let transport = "";
    switch (transportChoice) {
        case '1': transport = "tcp"; break;
        case '2': transport = "tcpmux"; break;
        case '3': transport = "udp"; break;
        case '4': transport = "ws"; break;
        case '5': transport = "wss"; break;
        case '6': transport = "ws_multiplexing"; break;
        case '7': transport = "wss_multiplexing"; break;
        default:
            console.error("Invalid choice.");
            rl.close();
            process.exit(1);
    }

    console.log("---");

    console.log("Select Mode (Server or Client):");
    console.log("1. Server");
    console.log("2. Client");

    const modeChoice = await getInputWithDefault("Please enter the number of your desired option", "");

    let mode = "";
    switch (modeChoice) {
        case '1': mode = "server"; break;
        case '2': mode = "client"; break;
        default:
            console.error("Invalid choice.");
            rl.close();
            process.exit(1);
    }

    console.log("---");

    // --- Start creating config.toml ---
    let configContent = '';
    if (mode === "server") {
        configContent += "[server]\n";
        const bindAddr = await getInputWithDefault("Bind address and port (bind_addr)", "0.0.0.0:3080");
        configContent += `bind_addr = "${bindAddr}"\n`;
        configContent += `transport = "${transport}"\n`;

        if (transport === "tcp" || transport === "udp") {
            const acceptUdp = await getInputWithDefault("Accept UDP? (true/false)", "false");
            configContent += `accept_udp = ${acceptUdp}\n`;
        }

        const token = await getInputWithDefault("Token (token)", "your_token");
        configContent += `token = "${token}"\n`;
        const keepalivePeriod = await getInputWithDefault("Keepalive Period (seconds) (keepalive_period)", "75");
        configContent += `keepalive_period = ${keepalivePeriod}\n`;
        const nodelay = await getInputWithDefault("Enable Nodelay? (true/false)", "true");
        configContent += `nodelay = ${nodelay}\n`;
        const heartbeat = await getInputWithDefault("Heartbeat (seconds) (heartbeat)", "40");
        configContent += `heartbeat = ${heartbeat}\n`;
        const channelSize = await getInputWithDefault("Channel Size (channel_size)", "2048");
        configContent += `channel_size = ${channelSize}\n`;

        if (transport === "tcpmux") {
            const muxCon = await getInputWithDefault("Max multiplexed connections (mux_con)", "8");
            configContent += `mux_con = ${muxCon}\n`;
            const muxVersion = await getInputWithDefault("Multiplexing version (mux_version)", "1");
            configContent += `mux_version = ${muxVersion}\n`;
            const muxFramesize = await getInputWithDefault("Multiplexing frame size (mux_framesize)", "32768");
            configContent += `mux_framesize = ${muxFramesize}\n`;
            const muxReceivebuffer = await getInputWithDefault("Multiplexing receive buffer size (mux_recievebuffer)", "4194304");
            configContent += `mux_recievebuffer = ${muxReceivebuffer}\n`;
            const muxStreambuffer = await getInputWithDefault("Multiplexing stream buffer size (mux_streambuffer)", "65536");
            configContent += `mux_streambuffer = ${muxStreambuffer}\n`;
        }

        const sniffer = await getInputWithDefault("Enable Sniffer? (true/false)", "false");
        configContent += `sniffer = ${sniffer}\n`;
        const webPort = await getInputWithDefault("Web Port (web_port)", "2060");
        configContent += `web_port = ${webPort}\n`;
        const snifferLog = await getInputWithDefault("Sniffer Log File Path (sniffer_log)", "/root/backhaul.json");
        configContent += `sniffer_log = "${snifferLog}"\n`;
        const logLevel = await getInputWithDefault("Log Level (log_level) (debug, info, warn, error)", "info");
        configContent += `log_level = "${logLevel}"\n`;
        const ports = await getPortInput("Ports to monitor (e.g., 80,443). Leave empty to finish.", "");
        configContent += `ports = ${ports}\n`;

    } else if (mode === "client") {
        configContent += "[client]\n";
        const remoteAddr = await getInputWithDefault("Enter IR VPS IP address and port (remote_addr)", "0.0.0.0:3080");
        configContent += `remote_addr = "${remoteAddr}"\n`;
        configContent += `transport = "${transport}"\n`;
        const token = await getInputWithDefault("Token (token)", "your_token");
        configContent += `token = "${token}"\n`;
        const connectionPool = await getInputWithDefault("Connection Pool Size (connection_pool)", "8");
        configContent += `connection_pool = ${connectionPool}\n`;
        const aggressivePool = await getInputWithDefault("Enable Aggressive Pool? (true/false)", "false");
        configContent += `aggressive_pool = ${aggressivePool}\n`;
        const keepalivePeriod = await getInputWithDefault("Keepalive Period (seconds) (keepalive_period)", "75");
        configContent += `keepalive_period = ${keepalivePeriod}\n`;
        const dialTimeout = await getInputWithDefault("Dial Timeout (seconds) (dial_timeout)", "10");
        configContent += `dial_timeout = ${dialTimeout}\n`;
        const retryInterval = await getInputWithDefault("Retry Interval (seconds) (retry_interval)", "3");
        configContent += `retry_interval = ${retryInterval}\n`;
        const nodelay = await getInputWithDefault("Enable Nodelay? (true/false)", "true");
        configContent += `nodelay = ${nodelay}\n`;

        if (transport === "tcpmux") {
            const muxVersion = await getInputWithDefault("Multiplexing version (mux_version)", "1");
            configContent += `mux_version = ${muxVersion}\n`;
            const muxFramesize = await getInputWithDefault("Multiplexing frame size (mux_framesize)", "32768");
            configContent += `mux_framesize = ${muxFramesize}\n`;
            const muxReceivebuffer = await getInputWithDefault("Multiplexing receive buffer size (mux_recievebuffer)", "4194304");
            configContent += `mux_recievebuffer = ${muxReceivebuffer}\n`;
            const muxStreambuffer = await getInputWithDefault("Multiplexing stream buffer size (mux_streambuffer)", "65536");
            configContent += `mux_streambuffer = ${muxStreambuffer}\n`;
        }

        const sniffer = await getInputWithDefault("Enable Sniffer? (true/false)", "false");
        configContent += `sniffer = ${sniffer}\n`;
        const webPort = await getInputWithDefault("Web Port (web_port)", "2060");
        configContent += `web_port = ${webPort}\n`;
        const snifferLog = await getInputWithDefault("Sniffer Log File Path (sniffer_log)", "/root/backhaul.json");
        configContent += `sniffer_log = "${snifferLog}"\n`;
        const logLevel = await getInputWithDefault("Log Level (log_level) (debug, info, warn, error)", "info");
        configContent += `log_level = "${logLevel}"\n`;
    }

    try {
        await fs.writeFile(CONFIG_FILE, configContent);
        console.log("---");
        console.log(`Configuration file (${CONFIG_FILE}) created successfully:`);
        console.log("---");
        console.log(configContent);
        console.log("---");

        console.log("Running Backhaul with the new configuration file...");
        // This will run the backhaul executable directly and show its output
        const backhaulProcess = exec(`./backhaul -c "${CONFIG_FILE}"`);

        backhaulProcess.stdout.on('data', (data) => {
            console.log(`Backhaul stdout: ${data}`);
        });

        backhaulProcess.stderr.on('data', (data) => {
            console.error(`Backhaul stderr: ${data}`);
        });

        backhaulProcess.on('close', (code) => {
            console.log(`Backhaul process exited with code ${code}`);
            rl.close();
        });

    } catch (error) {
        console.error("Failed to create config file or run Backhaul:", error.message);
        rl.close();
        process.exit(1);
    }
}

main();