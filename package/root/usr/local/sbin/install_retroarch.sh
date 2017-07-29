#!/bin/bash

#check for root
if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

#echo commands and arguments, and exit if any command returns non-zero status
set -xe

#add repositories
add-apt-repository ppa:libretro/testing -y
apt-add-repository -y ppa:ayufan/pine64-ppa -y

#Installs x for retroarch to run in
PACKAGES=(
	x-window-system
	xterm
	twm
	)

#Necessary dependencies
PACKAGES+=(
	libsdl1.2-dev
	libsdl1.2debian
	pkg-config
	build-essential
	)

#Add libretro and retroarch
PACKAGES+=(
	retroarch*
	libretro*
	)

#Add Samba for SMB file shares
PACKAGES+=(
	samba
	samba-common-bin
	)

#Adds defaults from install_desktop
PACKAGES+=(
	xserver-xorg-video-armsoc-sunxi
	libmali-sunxi-utgard0-r6p0
	)

# Install
apt-get update -y
apt-get -y --no-install-recommends install ${PACKAGES[@]}

# Kill parport module loading, not available on arm64.
if [ -e "/etc/modules-load.d/cups-filters.conf" ]; then
	echo "" >/etc/modules-load.d/cups-filters.conf
fi

# Disable Pulseaudio timer scheduling which does not work with sndhdmi driver.
if [ -e "/etc/pulse/default.pa" ]; then
	sed -i 's/load-module module-udev-detect$/& tsched=0/g' /etc/pulse/default.pa
fi

#change hostname (will also update motd banner)
echo "retroarch" > /etc/hostname
sed -i "s/pine64/retroarch/g" /etc/hosts

#retropie header
cat > /etc/update-motd.d/05-figlet <<EOF
#!/bin/sh
figlet \$(hostname)
EOF
chmod +x /etc/update-motd.d/05-figlet

#hide other MOTD banners
chmod -x /etc/update-motd.d/00-header
chmod -x /etc/update-motd.d/10-help-text
chmod -x /etc/update-motd.d/11-pine-a64-help-text

#prevent any tty permission X.org errors
usermod pine64 -aG tty

#allow passwordless shutdown
cat >> /etc/sudoers <<EOF
pine64 ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown
EOF

#download custom wallpaper from extras repo
curl -L -o "/home/pine64/pine64-retroarch-wallpaper.png" https://github.com/pfeerick-pine64/linux-extras/raw/master/retroarch/

#backup stock default config and customise
DEFAULT_CFG="/etc/retroarch.cfg"
cp ${DEFAULT_CFG} /etc/retroarch.cfg.stock
sed -i '/# video_fullscreen = false/c\video_fullscreen = true' ${DEFAULT_CFG} #fullscreen
sed -i '/# menu_wallpaper =/c\# menu_wallpaper = "/home/pine64/pine64-retroarch-wallpaper.png"' ${DEFAULT_CFG} #custom wallpaper
#sed -i '/# audio_device =/c\# audio_device = "hw:0,0"' ${DEFAULT_CFG} #analog audio
#sed -i '/# audio_device =/c\# audio_device = "hw:1,0"' ${DEFAULT_CFG} #HDMI audio

#Set up SMB sharefolder for ROMs and BIOS
mkdir -pv /home/pine64/ROMs
chown nobody:nogroup -R /home/pine64/ROMs

cat >> /etc/samba/smb.conf <<EOF
[ROMs]
comment = ROMs Folder
path = /home/pine64/ROMs
writeable = yes
browseable = yes
guest ok = yes
create mask = 0644
directory mask = 2777
EOF

#Enables mali + drm
exec /usr/local/sbin/pine64_enable_sunxidrm.sh

exit 0
