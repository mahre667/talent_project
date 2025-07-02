#!/bin/bash

# ─────────────[ COLOR CODES ]─────────────
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
BOLD='\033[1m'
RESET='\033[0m'

# Prompt for sudo user creation
read -p "👤 Enter sudo username [talent]: " SUDO_USER
SUDO_USER=${SUDO_USER:-talent}

# Prompt for sudo user password (hide input)
read -s -p "🔑 Enter password for user '$SUDO_USER' [test..123]: " SUDO_PASS
echo
if [ -z "$SUDO_PASS" ]; then
  SUDO_PASS="test..123"
fi

# ─────────────[ ASCII TITLE ]─────────────
clear
echo -e "${MAGENTA}${BOLD}"
cat << "EOF"
╔════════════════════════════════════════════╗
║    🚀  LXC + Docker App Deployer v69 💦     ║
╚════════════════════════════════════════════╝
EOF
echo -e "${RESET}"
sleep 1

# ─────────────[ WHIPTAIL CHECK ]─────────────
if ! command -v whiptail &>/dev/null; then
  echo -e "${YELLOW}⚠️  'whiptail' not found. Installing...${RESET}"
  apt update -y && apt install -y whiptail
  if ! command -v whiptail &>/dev/null; then
    echo -e "${RED}❌ Failed to install whiptail. Exiting.${RESET}"
    exit 1
  fi
  echo -e "${GREEN}✅ whiptail installed successfully.${RESET}"
fi

# ─────────────[ USER INPUTS ]─────────────
DEFAULT_CTID=101
DEFAULT_HOSTNAME="mycontainer"
DEFAULT_STORAGE="ProxmoxHDD"
DEFAULT_DISK_SIZE="8"
ROOT_PASSWORD="test..123"
export SUDO_USER=$SUDO_USER

CTID=$(whiptail --inputbox "🔥 Enter Container ID:" 10 50 "$DEFAULT_CTID" --title "Container Setup" 3>&1 1>&2 2>&3)
HOSTNAME=$(whiptail --inputbox "🖥️  Enter Hostname:" 10 50 "$DEFAULT_HOSTNAME" --title "Container Setup" 3>&1 1>&2 2>&3)
STORAGE=$(whiptail --inputbox "💾 Enter Storage Name:" 10 50 "$DEFAULT_STORAGE" --title "Container Setup" 3>&1 1>&2 2>&3)
DISK_SIZE=$(whiptail --inputbox "📦 Enter Disk Size (GB):" 10 50 "$DEFAULT_DISK_SIZE" --title "Container Setup" 3>&1 1>&2 2>&3)

# ─────────────[ TEMPLATE SELECTION ]─────────────
TEMPLATE=$(whiptail --title "OS Template" --menu "Choose Template:" 15 60 4 \
"ubuntu-22.04-standard_22.04-1_amd64.tar.zst" "🐧 Ubuntu 22.04" \
"debian-12-standard_12.0-1_amd64.tar.zst" "🎩 Debian 12" \
"ubuntu-20.04-standard_20.04-1_amd64.tar.zst" "🐧 Ubuntu 20.04" \
"custom" "🛠️  Enter manually" \
3>&1 1>&2 2>&3)

if [ "$TEMPLATE" == "custom" ]; then
  TEMPLATE=$(whiptail --inputbox "🛠️ Enter template filename:" 10 60 "" --title "Manual Template" 3>&1 1>&2 2>&3)
fi

# ─────────────[ APP SELECTION ]─────────────
APP_SELECTION=$(whiptail --title "🎛️  Choose Apps to Deploy" --checklist \
"Use SPACE to select apps and ENTER to confirm:" 20 78 12 \
"qbittorrent" "🔽 Torrent downloader" OFF \
"sonarr"      "📺 TV show manager"     OFF \
"radarr"      "🎬 Movie manager"       OFF \
"prowlarr"    "🧭 Indexer"             OFF \
"jellyfin"    "🍿 Media streaming server" OFF \
"organizr"    "🍿 Dashboard" OFF \
3>&1 1>&2 2>&3)

if [ -z "$APP_SELECTION" ]; then
  echo -e "${RED}❌ No apps selected. Exiting.${RESET}"
  exit 1
fi

echo -e "${CYAN}📦 Selected apps: ${APP_SELECTION}${RESET}"
sleep 1

# ─────────────[ CREATE LXC CONTAINER ]─────────────
echo -e "${YELLOW}⚙️  Creating LXC container $CTID...${RESET}"
pct create "$CTID" "$STORAGE:vztmpl/$TEMPLATE" \
  -hostname "$HOSTNAME" \
  -net0 name=eth0,bridge=vmbr0,ip=dhcp \
  -onboot 1 -cores 2 -memory 2048 -unprivileged 1 \
  -features nesting=1 \
  -rootfs "$STORAGE:$DISK_SIZE" -password "$ROOT_PASSWORD"

pct start "$CTID"
echo -e "${GREEN}✅ Container started!${RESET}"
sleep 1





# ─────────────[ INSTALL DOCKER INSIDE LXC ]─────────────
echo -e "${YELLOW}🐳 Installing Docker inside LXC...${RESET}"
pct exec "$CTID" -- bash -c "
apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release git && \
mkdir -p /etc/apt/keyrings && \
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
echo \
\"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" \
> /etc/apt/sources.list.d/docker.list && \
apt-get update && \
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
"
# ─────────────[ CREATE SUDO USER INSIDE LXC ]─────────────
echo -e "${YELLOW}👤 Creating sudo user '$SUDO_USER' inside LXC...${RESET}"
pct exec "$CTID" -- bash -c "
  useradd -m -s /bin/bash $SUDO_USER && \
  echo '$SUDO_USER:$SUDO_PASS' | chpasswd && \
  usermod -aG sudo $SUDO_USER && \
  echo '$SUDO_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$SUDO_USER && \
  chmod 440 /etc/sudoers.d/$SUDO_USER
"
pct exec "$CTID" -- bash -c "echo 'export $SUDO_USER=$SUDO_USER' >> /home/$SUDO_USER/.bashrc && chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.bashrc"

# Verify user creation
echo -e "${CYAN}🔍 Verifying user '$SUDO_USER' exists inside LXC...${RESET}"
pct exec "$CTID" -- bash -c "
  id $SUDO_USER > /dev/null 2>&1
"
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to create user '$SUDO_USER'. Exiting.${RESET}"
  exit 1
fi

# ─────────────[ Export SUDO_USER inside the container ]─────────────
pct exec "$CTID" -- bash -c "echo 'export SUDO_USER=$SUDO_USER' >> /etc/profile.d/sudo_user.sh"
pct exec "$CTID" -- bash -c "chmod +x /etc/profile.d/sudo_user.sh"

# Add user to Docker group
pct exec $CTID -- groupadd docker || true
pct exec $CTID -- usermod -aG docker "$SUDO_USER"


# Restart the container to apply group membership changes
echo -e "${YELLOW}🔄 Restarting container to apply group changes...${RESET}"
pct stop "$CTID"
pct start "$CTID"

# Verify Docker permissions for the user
echo -e "${CYAN}🔍 Verifying Docker permissions for user '$SUDO_USER'...${RESET}"
pct exec "$CTID" -- su - "$SUDO_USER" -c "
  docker info > /dev/null 2>&1
"
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Docker permissions issue for user '$SUDO_USER'. Exiting.${RESET}"
  exit 1
fi

# ...existing code...

# ─────────────[ CLONE GITHUB REPO ]─────────────
GITHUB_REPO="https://github.com/mahre667/talent_project"
APP_DIR="/home/$SUDO_USER/app"
COMPOSE_DIR="$APP_DIR/compose_files"
MASTER_COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"

pct exec "$CTID" -- su - "$SUDO_USER" -c "
  git clone $GITHUB_REPO $APP_DIR
"

# Replace all occurrences of \${SUDO_USER} with actual username in YAML files
pct exec "$CTID" -- bash -c "
  find $COMPOSE_DIR -type f -name '*.yml' -exec sed -i \"s|\\\${SUDO_USER}|$SUDO_USER|g; s|\\\$SUDO_USER|$SUDO_USER|g\" {} +
"

pct exec "$CTID" -- chown -R "$SUDO_USER:$SUDO_USER" "$APP_DIR"

# 🔧 Fix ownership of everything inside /configs/
# pct exec "$CTID" -- bash -c "chown -R $SUDO_USER:$SUDO_USER $APP_DIR/configs"

# ...existing code...

# ─────────────[ MERGE SELECTED APPS INTO ONE COMPOSE FILE ]─────────────
echo -e "${YELLOW}📂 Merging selected app Compose files into one...${RESET}"
eval "selected_apps=($APP_SELECTION)"

pct exec "$CTID" -- bash -c "
  echo 'services:' >> $MASTER_COMPOSE_FILE
"

for app in "${selected_apps[@]}"; do
  app_cleaned=$(echo $app | tr -d '"')
  COMPOSE_FILE="$COMPOSE_DIR/${app_cleaned}.yml"

  echo -e "${CYAN}📂 Adding app: $app_cleaned to master Compose file...${RESET}"

  pct exec "$CTID" -- bash -c "[ -f '$COMPOSE_FILE' ]"
  if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️ Compose file for $app_cleaned not found at $COMPOSE_FILE, skipping.${RESET}"
    continue
  fi

  pct exec "$CTID" -- bash -c "
  echo -e \"  $app_cleaned:\" >> $MASTER_COMPOSE_FILE
    sed '/^version:/d' $COMPOSE_FILE | sed '/^services:/d' | sed '1d' | sed 's/^/  /' >> $MASTER_COMPOSE_FILE
  "

  # Append the app's service definition to the master Compose file with proper indentation


  # Append additional configurations (e.g., volumes, environment) to the service block with proper indentation
 
done


# Validate the master Compose file
echo -e "${CYAN}🔍 Validating master Compose file...${RESET}"
pct exec "$CTID" -- su - "$SUDO_USER" -c "
  docker compose -f $MASTER_COMPOSE_FILE config > /dev/null 2>&1
"
if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Invalid master Docker Compose file. Please fix it manually.${RESET}"
  exit 1
fi

# ─────────────[ RUN MASTER COMPOSE FILE ]─────────────

# Fix ownership inside the container
echo -e "${YELLOW}🔧 Fixing file permissions...${RESET}"
pct exec "$CTID" -- bash -c "chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER"



echo -e "${CYAN}🚀 Starting Docker Compose with the master file...${RESET}"
pct exec "$CTID" -- su - "$SUDO_USER" -c "
  docker compose -f $MASTER_COMPOSE_FILE up -d
"

# ─────────────[ DONE ]─────────────
lxc_ip=$(pct exec "$CTID" -- hostname -I | awk '{print $1}')
echo -e "\n${GREEN}✨ Your LXC is live at: ${CYAN}http://$lxc_ip${RESET}"
echo -e "${YELLOW}🔐 SSH: ssh root@$lxc_ip (password: ${ROOT_PASSWORD})${RESET}"
echo -e "${MAGENTA}🔥 Done. Go enjoy your media empire, king. 👑${RESET}"