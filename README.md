# OpenDash

OpenDash is a Qt-based infotainment center for your Linux OpenAuto installation!
The OpenDash project includes OpenAuto, AASDK, and Dash.

Main features of Dash include:

*	Embedded OpenAuto `Windowed/Fullscreen`
*	Wireless OpenAuto Capability
*	On-screen Volume, Brightness, & Theme Control
*	Responsive Scalable UI `Adjustable for screen size`
*	Bluetooth Media Control
*	Real-Time Vehicle OBD-II Data & SocketCAN Capabilities
*	Theming `Dark/Light mode` `Customizable RGB Accent Color`
*	True Raspberry Pi 7” Official Touchscreen Brightness Control
*	App-Launcher built in
*	Camera Access `Streaming/Local` `Backup` `Dash`
*	Keyboard Shortcuts `GPIO Triggerable`

![](docs/imgs/opendash-ui.gif)

# Getting Started

## Video walk through
_steps may be slightly different such as ia (intelligent-auto) has been renamed to dash, the UI has changed, etc..._

https://youtu.be/CIdEN2JNAzw

## Install Script

Dash can be built automatically utilizing an included script. 

However, some extra steps are required to enhance performance and setup the Raspberry Pi environment for proper function.

The following guide has been tested on a Raspberry Pi 3B+, though it should work for newer Pi revisions too.

### 1. Flash Raspberry Pi OS Lite (64-Bit)
It's easiest to do this with Raspberry Pi Imager.

Do not use the Legacy Bullseye OS build - the current Bookworm works fine.

Also, do not set WiFi through Pi Imager, as it seems to not currently work and breaks WiFi entirely. We will setup WiFi on the Pi itself.

It's a good idea to setup a user and password, and enable SSH in Raspberry Pi Imager.

### 2. Edit config.txt
Once the OS is flashed to your SD card, replug your reader, access the bootfs partition and edit config.txt with the following at the very end:
```
# Speed up boot
disable_splash=1
boot_delay=0
force_turbo=1
dtparam=krnbt
gpu_mem=128
```

If you are using a display with a resolution that's higher than 1080p, set `gpu_mem=256` instead.

On Pi 3 series it's useful to do some overclocking, however - it may not be stable on your device, but on my Pi it works fine. If you choose to use overcloking, also add:
```
[pi3]
gpu_freq=500
over_voltage=2
soft_temp_limit=70
temp_limit=85
sdram_freq=580
sdram_schmoo=0x02000020
over_voltage_sdram=5
dtparam=sd_overclock=100 
avoid_warnings=1
```

On my Pi 4 these are stable overclock settings:
```
[pi4]
over_voltage=6
arm_freq=2147
gpu_freq=750
```

Waveshare 5.5inch 1440x2560 needs an extra command at the start of `cmdline.txt`:
```
video=HDMI-A-1:1440x2560@50D,rotate=90
```

Note that this display does not work on Pi 3-series.

### 3. First boot and setup
Now you can boot your Pi. If you setup your user and enabled SSH while flashing with Raspberry Pi Imager, you can use Ethernet and login via SSH. Otherwise, use a monitor and keyboard to complete user setup.

Once the Pi is running, use `sudo raspi-config` to setup Wifi, SSH and autologin.

### 4. Update system
Run `sudo apt update && sudo apt upgrade -y` to update the OS.

Once done, reboot with `sudo reboot now`

### 5. Setup zram, install git
Before we start installing dash, it's a good idea to add zram - this is mandatory for Raspberry Pis that have less than 2GB RAM, otherwise compile will fail. It's also fine to use zram even if your device has more than 2GB RAM.

Run `sudo apt install git systemd-zram-generator -y`

Now we need to configure zram. Run `sudo nano /etc/systemd/zram-generator.conf` and edit it like this:
```
[zram0]
zram-size = ram * 2
compression-algorithm = zstd
```

Reload systemd daemon and start the zram service with `sudo systemctl daemon-reload && sudo systemctl start systemd-zram-setup@zram0.service`

Finally, lets add some sysctl tweaks. Run `sudo nano /etc/sysctl.conf` and at the end add:
```
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
```

Run `sudo sysctl --system` to apply changes.

### 6. Compile openDsh
We're ready to install openDsh.

Run:
```
git clone https://github.com/jokubasver/dash.git
cd dash
sudo chmod +x new_install.sh
./new_install.sh
```
It will take a while...

### 7. Setup EGLFS autostart.
Once openDsh is finished compiling, now we can setup autostart.

There are multiple ways to setup autostart of dash. Run `./autostart.sh` to see the available options.

The easiest, best performant and effiecient way is to use EGLFS - this does not require X11, Wayland and runs great even on a Lite RPi OS without a desktop environment.

Run `./autostart.sh --autostarteglfs`

This will setup `.bashrc` to autostart openDsh using EGLFS.

Additional setup can be performed by `sudo nano .bashrc` - there are useful options for high DPI/portrait displays (like the Waveshare 5.5 inch 1440x2560 display)

### 8. Disable unnecessary services and reboot

Before we reboot, let's disable some unnecessary services to speed up boot time:

`sudo systemctl disable NetworkManager-wait-online.service e2scrub_reap.service ModemManager.service avahi-daemon.service rpi-eeprom-update.service `

Finally, reboot with `sudo reboot now` and you should load into openDsh.

### 9. Bluetooth setup

To setup the built-in Pi Bluetooth, run `bluetoothctl` and enter these commands:
```
power on
discoverable on
pairable on
agent on
default-agent
```

Next, on your phone, pair to the `raspberrypi` device. Type `yes` on the Pi to authorize connection, then accept any permissions on your phone and click Pair.

Answer `yes` on the Pi side to any incoming requests.

Finally, type `trust YOUR:PHONE'S:BLUETOOTH:MAC:ADDRESS` and `exit`

### 10. Android Auto setup in openDsh
Click the cog icon in the top right corner and turn off `RtAudio` - at least on my setup RtAudio does not play any audio. 

Enable the `Bluetooth` and `Autoconnect Last Device` toggles.

1080p is a bit slow on a Pi 3B+, 720p works a lot better. 

Be sure to use 60FPS - gstreamer latency has been optimized for 60FPS and uses less CPU.

