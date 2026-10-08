#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "🚀 Starting Desktop Configuration..."

echo "📦 Updating package lists..."
sudo apt-get update -y

echo "🖥️ Installing Ubuntu Desktop (this will take a few minutes)..."
sudo apt-get install -y ubuntu-desktop

echo "🌐 Downloading Chrome Remote Desktop..."
wget -q https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb

echo "🛠️ Installing Chrome Remote Desktop and dependencies..."
sudo apt-get install -y ./chrome-remote-desktop_current_amd64.deb
sudo apt-get install -f -y

echo "✅ Setup complete!"
echo ""
echo "Next steps to link your account:"
echo "1. On your LOCAL computer, go to: https://remotedesktop.google.com/headless"
echo "2. Follow the 'Begin' -> 'Next' -> 'Authorize' flow."
echo "3. Copy the 'Debian Linux' command and run it here in this terminal."
echo "4. Set your 6-digit PIN."
echo "5. Finally, run: sudo reboot"
