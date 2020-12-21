#!/bin/bash

#**************************************************************************************************
# WebPageTest agent installation script for MacOS systems.

echo "Installing and configuring WebPageTest agent. Please make sure that Xcode is installed before running..."
echo

#**************************************************************************************************
# Configure Defaults
#**************************************************************************************************

set -eu
: ${WPT_SERVER:=''}
: ${WPT_LOCATION:=''}
: ${WPT_KEY:=''}
: ${AGENT_MODE:='desktop'}
: ${WPT_UPDATE_OS:='y'}
: ${WPT_UPDATE_OS_NOW:='y'}
: ${WPT_UPDATE_AGENT:='y'}

# Pre-prompt for the sudo authorization so it doesn't prompt later
echo "May prompt for sudo password..."
sudo date

while [[ $WPT_SERVER == '' ]]
do
read -p "WebPageTest server (i.e. www.webpagetest.org): " WPT_SERVER
done
while [[ $WPT_LOCATION == '' ]]
do
read -p "Location ID (i.e. Dulles): " WPT_LOCATION
done
while [[ $WPT_KEY == '' ]]
do
read -p "Location Key (if required): " WPT_KEY
done

#**************************************************************************************************
# System Update
#**************************************************************************************************

if [ $WPT_UPDATE_OS_NOW == 'y' ]; then
softwareupdate --install --recommended
fi

#**************************************************************************************************
# Agent code
#**************************************************************************************************

cd ~
rm -rf wptagent
until git clone --depth 1 --branch=release https://github.com/WPO-Foundation/wptagent.git
do
    sleep 1
done

#**************************************************************************************************
# Software Install
#**************************************************************************************************

# Grant sudo permission without prompting
echo "${USER} ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/wptagent"

# Install homebrew
CI=1 arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install the cli libraries
arch -x86_64 brew install libvpx ffmpeg imagemagick geckodriver ios-webkit-debug-proxy node git

# Install the python dependencies
pip3 install PyObjC ujson dnspython monotonic pillow psutil requests tornado wsaccel brotli fonttools selenium future usbmuxwrapper

# Install lighthouse
npm -g install lighthouse

#**************************************************************************************************
# Install Browsers
#**************************************************************************************************
echo "Installing Browsers..."
cd ~
git clone https://github.com/WPO-Foundation/browser-install.git
python3 ~/browser-install/browser_install_macos.py

#**************************************************************************************************
# Agent Script
#**************************************************************************************************

# build the agent script
KEY_OPTION=''
if [ $WPT_KEY != '' ]; then
  KEY_OPTION="--key $WPT_KEY"
fi
echo '#!/bin/zsh' > ~/agent.sh
echo 'cd $HOME' >> ~/agent.sh

# Wait for networking to become available and update the package list
echo 'sleep 10' >> ~/agent.sh

# Update the browsers
echo "python3 $HOME/browser-install/browser_install_macos.py" >> ~/agent.sh

# Lighthouse Update
if [ $WPT_UPDATE_AGENT == 'y' ]; then
    echo 'sudo npm i -g lighthouse' >> ~/agent.sh
fi

echo 'for i in `seq 1 24`' >> ~/agent.sh
echo 'do' >> ~/agent.sh

if [ $WPT_UPDATE_AGENT == 'y' ]; then
    echo "    cd $HOME/wptagent" >> ~/agent.sh
    echo '    git pull origin release' >> ~/agent.sh
    echo "    cd $HOME" >> ~/agent.sh
fi

# Agent invocation (depending on config)
if [ $AGENT_MODE == 'android' ]; then
    echo "    python3 $HOME/wptagent/wptagent.py -vvvv --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --android --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi
if [ $AGENT_MODE == 'ios' ]; then
    echo "    python3 $HOME/wptagent/wptagent.py -vvvv --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --iOS --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi
if [ $AGENT_MODE == 'desktop' ]; then
    echo "    python3 $HOME/wptagent/wptagent.py -vvvv --location $WPT_LOCATION $KEY_OPTION --server \"http://$WPT_SERVER/work/\" --exit 60 --alive /tmp/wptagent" >> ~/agent.sh
fi

echo '    echo "Exited, restarting"' >> ~/agent.sh
echo '    sleep 10' >> ~/agent.sh
echo 'done' >> ~/agent.sh

# OS Update
if [ $WPT_UPDATE_OS == 'y' ]; then
    echo 'echo "Updating OS"' >> ~/agent.sh
    echo 'sudo softwareupdate --install --recommended --restart' >> ~/agent.sh
fi

echo 'sudo reboot' >> ~/agent.sh
chmod +x ~/agent.sh

#**************************************************************************************************
# Startup and watchdog scripts
#**************************************************************************************************
cd ~
git clone https://github.com/WPO-Foundation/wptagent-install.git

# create the launch item to run the terminal automator script
mkdir -p ~/Library/LaunchAgents;
echo '<?xml version="1.0" encoding="UTF-8"?>' > ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '<plist version="1.0">' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '<dict>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <key>Label</key>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <string>org.webpagetest.wptagent</string>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <key>ProgramArguments</key>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <array>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo "        <string>$HOME/wptagent-install/macos/Agent.app</string>" >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    </array>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <key>RunAtLoad</key>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '    <true/>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '</dict>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist
echo '</plist>' >> ~/Library/LaunchAgents/org.webpagetest.wptagent.plist

echo '<?xml version="1.0" encoding="UTF-8"?>' > ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '<plist version="1.0">' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '<dict>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '    <key>Label</key>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '    <string>org.webpagetest.watchdog</string>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '    <key>ProgramArguments</key>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '    <array>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo "        <string>$HOME/wptagent-install/macos/Watchdog.app</string>" >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '    </array>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '    <key>RunAtLoad</key>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '    <true/>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '</dict>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist
echo '</plist>' >> ~/Library/LaunchAgents/org.webpagetest.watchdog.plist

#**************************************************************************************************
# Permission prompts
#**************************************************************************************************
echo "The install script is now going to trigger the permissions prompts for the various permissions needed by the agent."
echo "This includes Automation permissions for the scripts to move the simulator window and screen capture permissions to capture video."
echo "Press enter to continue."
read
python3 ~/wptagent/scripts/macos_prompts.py

open ~/wptagent-install/macos/Watchdog.app
open ~/wptagent-install/macos/Agent.app
killall Python

#**************************************************************************************************
# Done
#**************************************************************************************************

echo "Done. agent.sh will need to be configured to start automatically at login (see install docs)"
