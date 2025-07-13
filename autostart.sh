#!/bin/bash

###
# Helper scripts for setting autostart methods for Dash application 
###

display_help() {
    echo "Autostart install helpers Version 0.3"
    echo "Usage: $0 [option...]" >&2
    echo
    echo "   -adi, --adddesktopicon           Add desktop icon"
    echo "   -asd, --autostartdaemon          Add autostart daemon"
    echo "   -axi, --addxinit                 Add xinit autostart"
    echo "   -ase, --autostarteglfs           Add eglfs autostart"
    echo "   -h, --help                       Show help of script"
    echo
    echo "Example: Add an desktop icon"
    echo "   helpers.sh -adi"
    echo
    echo "Example: Add autostart Systemd daemon"
    echo "   helpers.sh -asd"
    echo
    echo "Example: Add autostart xinit script"
    echo "   helpers.sh -axi"
    echo
    exit 1
}


add_desktop_icon () {
  # Remove existing opendash desktop
  if [ -f $HOME/Desktop/dash.desktop ]; then
    echo "Removing existing shortcut"
    rm $HOME/Desktop/dash.desktop
  fi

  # Copy icon to pixmaps folder
  echo "Copying icon to system directory (requires sudo)"
  sudo cp -v assets/icons/opendash.xpm /usr/share/pixmaps/opendash.xpm

  # Create shortcut on dashboard
  echo "Creating desktop shortcut at ~/Desktop/dash.desktop"
  bash -c "echo '[Desktop Entry]
Name=Dash
Comment=Open Dash
Icon=/usr/share/pixmaps/opendash.xpm
Exec=$HOME/dash/bin/dash
Type=Application
Encoding=UTF-8
Terminal=true
Categories=None;
  ' > $HOME/Desktop/dash.desktop"
  chmod +x $HOME/Desktop/dash.desktop
}

create_autostart_daemon() {
  WorkingDirectory="$HOME/dash"
  if [[ $2 != "" ]]
  then
     WorkingDirectory="$HOME/$2/dash"
  fi
  echo ${WorkingDirectory}

  if [ -f "/etc/systemd/system/dash.service" ]; then
    # Stop and disable dash service
    echo "Stopping and removing previous service"
    sudo systemctl stop dash.service || true
    sudo systemctl disable dash.service || true
  
    # Remove existing dash service
    sudo systemctl unmask dash.service || true
  fi
  # Write dash service unit
  echo "Creating Dash service unit" 
  sudo bash -c "echo '[Unit]
Description=Dash
After=graphical.target

[Service]
Type=idle
User=$USER
StandardOutput=inherit
StandardError=inherit
Environment=DISPLAY=:0
Environment=XAUTHORITY=${HOME}/.Xauthority
WorkingDirectory=${WorkingDirectory}
ExecStart=${WorkingDirectory}/bin/dash
Restart=on-failure
RestartSec=5s
KillMode=process
TimeoutSec=infinity

[Install]
WantedBy=graphical.target
  ' > /etc/systemd/system/dash.service"

  # Activate and start dash service
  echo "Enabling and starting Dash service"
  sudo systemctl daemon-reload
  sudo systemctl enable dash.service
  sudo systemctl start dash.service
  sudo systemctl status dash.service
}

add_xinit_autostart () {
  # Install dependencies
  echo "Installing xinit and Xorg dependencies"
  sudo apt install -y xserver-xorg xinit x11-xserver-utils

  # Create .xinitrc
  echo "Creating ~/.xinitrc"
  cat <<EOT > $HOME/.xinitrc
#!/usr/bin/env sh
xset -dpms
xset s off
xset s noblank

export GST_DEBUG=3,video_sink:5
export QT_LOGGING_RULES=qt.scenegraph.general=true

export QT_OPENGL=egl
export QSG_NO_VSYNC=1
export QSG_RENDER_LOOP=threaded

while [ true ]; do
  sh $HOME/run_dash.sh
done
EOT

  # Create runner
  echo "Creating ~/run_dash.sh and linking to ~/dash/bin/dash"
  cat <<EOT > $HOME/run_dash.sh
#!/usr/bin/env sh
$HOME/dash/bin/dash >> $HOME/dash/bin/dash.log 2>&1
sleep 1
EOT

  # Append to .bashrc
  echo "Appending startx to ~/.bashrc"
  cat <<EOT >> $HOME/.bashrc

### xinit
if [ "\$(tty)" = "/dev/tty1" ]; then
  startx
fi
EOT

}

add_eglfs_autostart () {
  echo "Creating/Updating ~/.bashrc for EGLFS autostart"
  # Remove existing xinit section from .bashrc to avoid conflicts
  sed -i '/### xinit/,/fi/d' "$HOME/.bashrc" || true

  # Append new EGLFS autostart section to .bashrc
  cat <<EOT >> "$HOME/.bashrc"

### EGLFS Autostart for dash application
if [ "\$(tty)" = "/dev/tty1" ]; then
  # Set debugging
  export GST_DEBUG="3,video_sink:5"

  # Tell Qt to use the EGLFS platform plugin
  export QT_QPA_PLATFORM=eglfs
  export QT_QPA_EGLFS_SWAPINTERVAL=0
  export QT_QPA_EGLFS_FORCEVSYNC=0


  # Useful settings for high DPI/portrait displays (for example: Waveshare 5.5 inch 1440x2560)
  #
  # Screen rotation:
  #export QT_QPA_EGLFS_ROTATION=90
  #
  # Text scaling:
  #export QT_FONT_DPI=240
  #
  # Global QT scaling:
  #export QT_SCALE_FACTOR=2


  export GST_GL_PLATFORM=egl
  export GST_GL_API=gles2
  export QSG_NO_VSYNC=1
  export QSG_RENDER_LOOP=threaded
  export QSG_ANTIALIASING_METHOD=msaa


  # Touchscreen calibration/rotation (if needed for your display)
  #
  # Example: For a specific device, 90-degree rotation, inverted X/Y
  #export QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS="/dev/input/event0:rotate=90:invertx:inverty"
  #
  # Use 'libinput list-devices' or 'ls /dev/input/event*' to find your touch device.
  #
  # Waveshare 5.5 inch 1440x2560 display has a hardware button for switching touch rotation and therefore this is not needed.


  # Loop to restart the application if it crashes
  while true; do
    sh "$HOME/run_dash.sh"
    sleep 1 # Wait a bit before restarting
  done
fi
EOT

  # Create or update ~/run_dash.sh
  echo "Creating/Updating ~/run_dash.sh and linking to ~/dash/bin/dash"
  cat <<EOT > "$HOME/run_dash.sh"
#!/usr/bin/env sh
# Ensure the application executable is correct and has execute permissions
"$HOME/dash/bin/dash" >> "$HOME/dash/bin/dash.log" 2>&1
EOT
  chmod +x "$HOME/run_dash.sh"

  echo "EGLFS autostart configuration complete. Reboot for changes to take effect."

}

# Main Menu
while :
do
    case "$1" in
        -adi | --adddesktopicon)
            add_desktop_icon
            exit 0
          ;;
        -asd | --autostartdaemon)
            if [ $# -ne 0 ]; then
              create_autostart_daemon $2
              exit 0
            fi
          ;;
        -axi | --addxinit)
            if [ $# -ne 0 ]; then
              add_xinit_autostart
              exit 0
            fi
          ;;
        -ase | --autostarteglfs)
            if [ $# -ne 0 ]; then
              add_eglfs_autostart
              exit 0
            fi
          ;;
        -h | --help)
            display_help  # Call your function
            exit 0
          ;;
        "")  # If $1 is blank, run display_help
            display_help
            exit 0
          ;;
        --) # End of all options
            shift
            break
          ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            ## or call function display_help
            exit 1
          ;;
        *)  # No more options
            break
          ;;
    esac
done
