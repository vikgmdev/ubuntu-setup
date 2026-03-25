#!/bin/bash
# Ubuntu 24.04 Post-Install Optimization Script
# Run via: sh -c "$(curl -fsSL https://raw.githubusercontent.com/vikgmdev/ubuntu-setup/main/install.sh)"
set -e

HOME_DIR="$HOME"
DOWNLOADS="$HOME_DIR/Downloads"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="$SCRIPT_DIR/configs"

echo "=== Ubuntu Post-Install Optimizer ==="
echo ""

# ─── 1. SWAPPINESS ───
echo "[1/15] Setting swappiness to 10..."
sudo sysctl vm.swappiness=10
grep -q "vm.swappiness" /etc/sysctl.conf || echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf

# ─── 2. FORCE WAYLAND WITH NVIDIA ───
echo "[2/15] Enabling Wayland for NVIDIA..."
sudo sed -i 's/#WaylandEnable=false/WaylandEnable=true/' /etc/gdm3/custom.conf
sudo sed -i 's/WaylandEnable=false/WaylandEnable=true/' /etc/gdm3/custom.conf
sudo ln -sf /dev/null /etc/udev/rules.d/61-gdm.rules

# ─── 3. DISABLE TRACKER INDEXER ───
echo "[3/15] Disabling tracker file indexer..."
systemctl --user mask tracker-miner-fs-3 2>/dev/null || true
systemctl --user mask tracker-extract-3 2>/dev/null || true
tracker3 reset -rs 2>/dev/null || true

# ─── 4. DISABLE UNNECESSARY SERVICES ───
echo "[4/15] Disabling unnecessary GNOME services..."
systemctl --user mask evolution-addressbook-factory.service 2>/dev/null || true
systemctl --user mask evolution-calendar-factory.service 2>/dev/null || true
systemctl --user mask evolution-source-registry.service 2>/dev/null || true
systemctl --user mask gvfs-goa-volume-monitor.service 2>/dev/null || true

# ─── 5. INSTALL TLP (laptop power/thermal management) ───
echo "[5/15] Installing TLP..."
sudo apt install -y tlp tlp-rdw
sudo systemctl enable tlp

# ─── 6. GNOME OPTIMIZATIONS ───
echo "[6/15] Optimizing GNOME..."
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gnome-extensions disable ding@rastersoft.com 2>/dev/null || true

# ─── 7. REMOVE SNAPS + BLOCK SNAPD ───
echo "[7/15] Removing snapd..."
snap list 2>/dev/null || true

for snap in $(snap list 2>/dev/null | awk 'NR>1 {print $1}' | tac); do
    sudo snap remove --purge "$snap" 2>/dev/null || true
done

sudo apt remove --purge -y snapd 2>/dev/null || true
sudo apt-mark hold snapd 2>/dev/null || true
sudo rm -rf /snap /var/snap /var/lib/snapd ~/snap

cat <<'SNAPBLOCK' | sudo tee /etc/apt/preferences.d/no-snapd
Package: snapd
Pin: release a=*
Pin-Priority: -10
SNAPBLOCK

# ─── 8. INSTALL AND CONFIGURE GHOSTTY ───
echo "[8/15] Installing and configuring Ghostty..."
if ! command -v ghostty &>/dev/null; then
    GHOSTTY_DEB=$(ls "$DOWNLOADS"/ghostty_*_amd64.deb 2>/dev/null | sort -V | tail -1)
    if [ -z "$GHOSTTY_DEB" ]; then
        echo "  [Ghostty] Not found in ~/Downloads"
        echo "  Download from: https://ghostty.org/download"
        echo ""
        read -p "  Press Enter once downloaded (or 's' to skip): " choice
        if [ "$choice" != "s" ] && [ "$choice" != "S" ]; then
            GHOSTTY_DEB=$(ls "$DOWNLOADS"/ghostty_*_amd64.deb 2>/dev/null | sort -V | tail -1)
        fi
    fi
    if [ -n "$GHOSTTY_DEB" ]; then
        sudo dpkg -i "$GHOSTTY_DEB" || sudo apt -f install -y
        echo "  Ghostty installed"
    else
        echo "  Skipping Ghostty install"
    fi
else
    echo "  Ghostty already installed"
fi

mkdir -p "$HOME_DIR/.config/ghostty"
cp "$CONFIGS/ghostty/config" "$HOME_DIR/.config/ghostty/config"
cp "$CONFIGS/ghostty/config.ghostty" "$HOME_DIR/.config/ghostty/config.ghostty"
echo "  Ghostty config synced from repo"

# ─── 9. INSTALL APPS AS .DEB (replace snaps) ───
echo "[9/15] Setting up .deb repositories and installing apps..."

sudo install -d -m 0755 /etc/apt/keyrings

# Firefox from Mozilla repo
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
echo 'Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000' | sudo tee /etc/apt/preferences.d/mozilla > /dev/null

# VSCode from Microsoft repo
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

# Beekeeper Studio
curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key | sudo gpg --dearmor --output /usr/share/keyrings/beekeeper.gpg
sudo chmod go+r /usr/share/keyrings/beekeeper.gpg
echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main" | sudo tee /etc/apt/sources.list.d/beekeeper-studio-app.list > /dev/null

# kubectl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt update
sudo apt install -y firefox code beekeeper-studio kubectl google-chrome-stable gh

# ─── 10. INSTALL DOWNLOADED .DEB AND .TAR.GZ APPS ───
echo "[10/15] Installing Slack, Proton Pass, Postman, Android Studio..."
echo ""
echo "  This step installs apps from files in ~/Downloads."
echo "  Please download any missing ones now, then press Enter to continue."
echo ""

install_from_downloads() {
    local app_name="$1"
    local pattern="$2"
    local download_url="$3"

    local found
    found=$(ls $DOWNLOADS/$pattern 2>/dev/null | sort -V | tail -1)

    if [ -z "$found" ]; then
        echo "  [$app_name] Not found in ~/Downloads"
        echo "  Download from: $download_url"
        echo ""
        read -p "  Press Enter once downloaded (or 's' to skip): " choice
        if [ "$choice" = "s" ] || [ "$choice" = "S" ]; then
            echo "  Skipped $app_name"
            echo ""
            return 1
        fi
        found=$(ls $DOWNLOADS/$pattern 2>/dev/null | sort -V | tail -1)
        if [ -z "$found" ]; then
            echo "  Still not found, skipping $app_name"
            echo ""
            return 1
        fi
    fi

    echo "$found"
    return 0
}

# Slack
SLACK_DEB=$(install_from_downloads "Slack" "slack-desktop-*-amd64.deb" "https://slack.com/downloads/linux")
if [ $? -eq 0 ]; then
    sudo dpkg -i "$SLACK_DEB" || sudo apt -f install -y
    echo "  Slack installed"
fi

# Proton Pass
PROTON_DEB=$(install_from_downloads "Proton Pass" "proton-pass_*_amd64.deb" "https://proton.me/pass/download")
if [ $? -eq 0 ]; then
    sudo dpkg -i "$PROTON_DEB" || sudo apt -f install -y
    echo "  Proton Pass installed"
fi

# Postman
POSTMAN_TAR=$(install_from_downloads "Postman" "postman-linux-x64.tar.gz" "https://www.postman.com/downloads/")
if [ $? -eq 0 ]; then
    tar -xzf "$POSTMAN_TAR" -C /tmp
    sudo rm -rf /opt/Postman
    sudo mv /tmp/Postman /opt/Postman
    sudo ln -sf /opt/Postman/Postman /usr/local/bin/postman
    cat > "$HOME_DIR/.local/share/applications/postman.desktop" << 'POSTMANDESKTOP'
[Desktop Entry]
Name=Postman
Exec=/opt/Postman/Postman
Icon=/opt/Postman/app/resources/app/assets/icon.png
Type=Application
Categories=Development;
POSTMANDESKTOP
    echo "  Postman installed to /opt/Postman"
fi

# Android Studio
ANDROID_TAR=$(install_from_downloads "Android Studio" "android-studio-*-linux.tar.gz" "https://developer.android.com/studio")
if [ $? -eq 0 ]; then
    tar -xzf "$ANDROID_TAR" -C /tmp
    sudo rm -rf /opt/android-studio
    sudo mv /tmp/android-studio /opt/android-studio
    cat > "$HOME_DIR/.local/share/applications/android-studio.desktop" << 'ANDROIDDESKTOP'
[Desktop Entry]
Name=Android Studio
Exec=/opt/android-studio/bin/studio.sh
Icon=/opt/android-studio/bin/studio.svg
Type=Application
Categories=Development;IDE;
StartupWMClass=jetbrains-studio
ANDROIDDESKTOP
    echo "  Android Studio installed to /opt/android-studio"
fi

# ─── 11. SDKMAN + GRADLE + KOTLIN ───
echo "[11/15] Installing SDKMAN, Gradle, Kotlin..."
if [ ! -d "$HOME_DIR/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
    source "$HOME_DIR/.sdkman/bin/sdkman-init.sh"
    sdk install gradle
    sdk install kotlin
    echo "  SDKMAN + Gradle + Kotlin installed"
else
    echo "  SDKMAN already installed, skipping"
fi

# ─── 12. KUBECTL ZSH COMPLETION CACHING ───
echo "[12/15] Caching kubectl zsh completions..."
kubectl completion zsh > "$HOME_DIR/.kubectl-completion.zsh" 2>/dev/null || true
if ! grep -q "kubectl-completion.zsh" "$HOME_DIR/.zshrc" 2>/dev/null; then
    echo '# kubectl cached completions' >> "$HOME_DIR/.zshrc"
    echo 'source ~/.kubectl-completion.zsh' >> "$HOME_DIR/.zshrc"
    echo "  Added kubectl completion cache to .zshrc"
else
    echo "  kubectl completion cache already in .zshrc"
fi

# ─── 13. CHROME MULTI-PROFILE SETUP ───
echo "[13/15] Setting up Chrome profiles with separate data dirs and icons..."

mkdir -p "$HOME_DIR/.local/share/applications" "$HOME_DIR/.local/share/icons"

CHROME_PROFILES="$CONFIGS/chrome/profiles.conf"
if [ ! -f "$CHROME_PROFILES" ]; then
    echo ""
    echo "  No profiles.conf found. Creating from example..."
    echo "  Please edit ~/.ubuntu-setup/configs/chrome/profiles.conf with your Google accounts,"
    echo "  then re-run this script."
    cp "$CONFIGS/chrome/profiles.conf.example" "$CHROME_PROFILES"
    echo "  Skipping Chrome profile setup for now..."
elif [ ! -d "$HOME_DIR/.config/google-chrome/Default" ]; then
    echo ""
    echo "  Chrome profiles not found yet."
    echo "  Please open Chrome, sign into your Google accounts, then re-run this script."
    echo "  Skipping Chrome profile setup for now..."
else
    # Read profiles from config file
    while IFS='|' read -r profile_key profile_dir email label color_light color_mid color_dark; do
        # Skip comments and empty lines
        [[ "$profile_key" =~ ^#.*$ ]] && continue
        [ -z "$profile_key" ] && continue

        data_dir="$HOME_DIR/.config/$profile_key"

        if [ ! -d "$data_dir" ]; then
            echo "  Creating separate data dir for $label..."
            cp -r "$HOME_DIR/.config/google-chrome" "$data_dir"

            if [ "$profile_dir" != "Default" ]; then
                rm -rf "$data_dir/Default"
                mv "$data_dir/$profile_dir" "$data_dir/Default"
            fi
        fi

        cat > "$HOME_DIR/.local/share/applications/$profile_key.desktop" << DESKTOP
[Desktop Entry]
Version=1.0
Name=Chrome $label
GenericName=Web Browser
Comment=$label - $email
Exec=/usr/bin/google-chrome-stable --profile-directory=Default --class=$profile_key --user-data-dir=$data_dir %U
Terminal=false
Icon=$HOME_DIR/.local/share/icons/$profile_key.svg
Type=Application
Categories=Network;WebBrowser;
StartupWMClass=$profile_key
DESKTOP

        echo "  Created desktop entry for $label"
    done < "$CONFIGS/chrome/profiles.conf"

    # Generate Chrome-style icons with profile photo badges
    echo "  Generating Chrome-style icons..."
    python3 "$SCRIPT_DIR/chrome-icons.py"

    update-desktop-database "$HOME_DIR/.local/share/applications/" 2>/dev/null
fi

# ─── 14. VSCODE OPTIMIZATION ───
echo "[14/15] Configuring VSCode..."
VSCODE_SETTINGS="$HOME_DIR/.config/Code/User/settings.json"
if [ -f "$VSCODE_SETTINGS" ]; then
    python3 -c "
import json
with open('$VSCODE_SETTINGS') as f:
    s = json.load(f)
s['window.titleBarStyle'] = 'custom'
with open('$VSCODE_SETTINGS', 'w') as f:
    json.dump(s, f, indent=2)
print('  VSCode titleBarStyle set to custom')
"
else
    mkdir -p "$HOME_DIR/.config/Code/User"
    echo '{"window.titleBarStyle": "custom"}' > "$VSCODE_SETTINGS"
    echo "  Created VSCode settings with custom titlebar"
fi

# ─── 15. SLACK TITLE BAR FIX ───
echo "[15/15] Configuring Slack custom title bar..."
SLACK_CONFIG="$HOME_DIR/.config/Slack/storage/root-state.json"
if [ -f "$SLACK_CONFIG" ]; then
    python3 -c "
import json
with open('$SLACK_CONFIG') as f:
    d = json.load(f)
d.setdefault('settings', {})['useSystemTitleBar'] = False
with open('$SLACK_CONFIG', 'w') as f:
    json.dump(d, f, indent=2)
print('  Slack useSystemTitleBar set to false')
"
else
    echo "  Slack config not found yet — open Slack once, close it, then re-run this step"
fi

# ─── DONE ───
echo ""
echo "=== Optimization complete ==="
echo ""
echo "Manual steps remaining:"
echo "  1. Log out and select 'Ubuntu on Wayland' at login screen"
echo "  2. In Chrome: enable Memory Saver in chrome://settings/performance"
echo "  3. Pin Chrome Personal/Totem/Range icons to the dash"
echo "  4. Run: python3 ~/.ubuntu-setup/chrome-icons.py  (to refresh icons after profile photo changes)"
echo ""
