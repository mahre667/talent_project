# LXC + Docker App Deployer Script

## Overview
This Bash script automates the deployment of an LXC (Linux Container) on a Proxmox server and sets up a Docker environment inside it. It allows users to create a container, install Docker, clone a GitHub repository, and deploy selected applications (e.g., qBittorrent, Sonarr, Radarr, etc.) using Docker Compose. The script is interactive, using `whiptail` for user input, and includes colorful output for better user experience.

## Features
- **Interactive Setup**: Prompts for container details (ID, hostname, storage, disk size, OS template) using `whiptail`.
- **Sudo User Creation**: Creates a sudo user inside the container with a specified username and password.
- **Docker Installation**: Installs Docker and Docker Compose inside the LXC container.
- **App Deployment**: Clones a GitHub repository and deploys selected applications by merging their Docker Compose files into a single master file.
- **Validation**: Verifies Docker permissions, user creation, and the master Compose file.
- **Networking**: Configures the container with DHCP networking and provides the IP address for access.

## Prerequisites
- **Proxmox VE**: The script assumes it is running on a Proxmox server with LXC support.
- **Root Access**: Must be run as `root` or with sufficient privileges to execute `pct` commands.
- **Internet Access**: Required for downloading templates, installing packages, and cloning the GitHub repository.
- **Storage**: A storage pool (e.g., `ProxmoxHDD`) must be configured in Proxmox.
- **GitHub Repository**: The repository at `https://github.com/mahre667/talent_project` must exist and contain valid Docker Compose files in the `compose_files` directory.

## Usage
1. **Save the Script**: Save the script as `run_this.sh` and make it executable:
   ```bash
   chmod +x run_this.sh
   ```
2. **Run the Script**: Execute the script as `root`:
   ```bash
   ./run_this.sh
   ```
3. **Follow Prompts**:
   - Enter a sudo username (default: `talent`) and password (default: `test..123`).
   - Provide container details (Container ID, hostname, storage name, disk size).
   - Select an OS template (e.g., Ubuntu 22.04, Debian 12, or custom).
   - Choose applications to deploy (e.g., qBittorrent, Jellyfin, etc.).
4. **Output**: Once complete, the script provides the container’s IP address and SSH details for access.

## Script Workflow
1. **Color Codes & ASCII Art**: Defines ANSI color codes and displays a title banner.
2. **Whiptail Check**: Installs `whiptail` if not present for interactive dialogs.
3. **User Inputs**: Collects container configuration via `whiptail` dialogs.
4. **LXC Creation**: Creates an unprivileged LXC container with specified parameters.
5. **Docker Setup**: Installs Docker and Docker Compose inside the container.
6. **Sudo User Setup**: Creates a sudo user and adds them to the Docker group.
7. **Repository Cloning**: Clones the specified GitHub repository to the user’s home directory.
8. **Compose File Merging**: Merges selected app Compose files into a master `docker-compose.yml`.
9. **Deployment**: Runs the master Compose file to start the selected applications.
10. **Final Output**: Displays the container’s IP and SSH details.

## Selected Applications
The script supports deploying the following applications (if their Compose files exist in the repository):
- **qBittorrent**: Torrent downloader.
- **Sonarr**: TV show manager.
- **Radarr**: Movie manager.
- **Prowlarr**: Indexer for torrents and Usenet.
- **Jellyfin**: Media streaming server.
- **Organizr**: Dashboard for managing media apps.

## Notes
- **Default Values**: If no input is provided, defaults are used (e.g., Container ID: `101`, Hostname: `mycontainer`, Disk Size: `8GB`).
- **Security**: The script sets a root password (`test..123` by default) and creates a sudo user with NOPASSWD privileges. Change these in production.
- **GitHub Repository**: Ensure the repository (`https://github.com/mahre667/talent_project`) contains valid Compose files in the `compose_files` directory.
- **Error Handling**: The script checks for `whiptail`, user creation, Docker permissions, and Compose file validity, exiting on critical errors.
- **Permissions**: Fixes ownership of files in the user’s home directory to ensure smooth Docker operation.

## Troubleshooting
- **Whiptail Not Found**: Ensure internet access for package installation.
- **Compose File Errors**: Verify that the GitHub repository contains valid `.yml` files for selected apps.
- **Docker Permissions**: If the user cannot run Docker commands, ensure they are in the `docker` group and the container has been restarted.
- **Network Issues**: Confirm the container’s network is configured correctly (`vmbr0` bridge with DHCP).

## Example Output
```bash
✨ Your LXC is live at: http://192.168.1.100
🔐 SSH: ssh root@192.168.1.100 (password: test..123)
🔥 Done. Go enjoy your media empire, king. 👑
```

## License
This script is provided as-is with no warranty. Use at your own risk.
