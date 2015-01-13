#!/bin/sh

# echo ==
# will be eliminated
#
# >>
# will be replaced to
# >>
#
# >
# will be replaced to
# >

TMP=/tmp/.instvar
JOURNAL=/tmp/.instlog
ITEM=1

messagebox()
{
	dialog --msgbox "$1" 0 0
}

infobox()
{
	dialog --infobox "$1" 0 0
}

installer_welcome()
{
messagebox "Welcome to the Energy Linux installer.

Energy Linux is a lightweight Linux distribution based on Arch with batteries and other stuff included. Our goal is to create a distribution simple as Arch but works out of the box. We hope you will like it.

Click OK to begin installation."
}

installer_prepare_hdd()
{
messagebox "cfdisk, mkfs, mount to /mnt. Start right now."
}

# Currently useless.
installer_partition()
{
disks1="`lsblk -r | grep disk | cut -d" " -f1`"
disks=""
for i in $disks1; do disks="${disks} /dev/${i} -"; done
# TODO: text
# At first we need to partition the hard drive. If you have no special needs, create one partition filling the whole disk.
dialog --menu "Select a hard drive to partition." 0 0 0 $disks 2> $TMP
if [ $? "!=" 0 ]; then return; fi
disk=`cat $TMP`
cfdisk $disk
ITEM=2
}

# Currently useless.
installer_makefs()
{
partitions1="`lsblk -r | grep part | cut -d" " -f1`"
partitions=""
for i in $partitions1; do partitions="${partitions} /dev/${i} -"; done
# TODO: text
# Now we must create filesystems.
dialog --menu "Select a partition to create ext4 on." 0 0 0 $partitions 2> $TMP
if [ $? "!=" 0 ]; then return; fi
partition=`cat $TMP`
mkfs.ext4 $partition
ITEM=3
}

# Currently useless.
installer_mount()
{
partitions1="`lsblk -r | grep part | cut -d" " -f1`"
partitions=""
for i in $partitions1; do partitions="${partitions} /dev/${i} -"; done
# TODO: text
# Now we need to mount new filesystems to /mnt.
dialog --menu "Select a partition to be mounted to /mnt." 0 0 0 $partitions 2> $TMP
if [ $? "!=" 0 ]; then return; fi
mou=`cat $TMP`
mount $mou /mnt
ITEM=4
}

installer_internet()
{
# TODO: maybe, PPPoE?
dialog --menu "Setup requires an Internet connection. If you connect using wired connection like eth0, connection will be established automatically. If you don't see any suitable option, configure your connection manually." 0 0 0 check "Check connection" wifi "Select wireless network" 2> $TMP
internet=`cat $TMP`
case $internet in
	check)
		ping -c 5 google.com
		;;
	wifi)
		wifi-menu
		;;
esac
ITEM=5
}

installer_mirrors()
{
mirrors1=`cat /etc/pacman.d/mirrorlist | grep -v "#" | grep "tp://" | cut -d" " -f3`
mirrors=""
for i in $mirrors1; do mirrors="${mirrors} ${i} -"; done
dialog --menu "Select a mirror to use during install." 0 0 0 $mirrors 2> $TMP
if [ $? "!=" 0 ]; then return; fi
mirror=`cat $TMP`
echo "Server = ${mirror}" > /etc/pacman.d/mirrorlist
ITEM=6
}

installer_pacstrap()
{
pacstrap /mnt base base-devel
ITEM=7
}

installer_conf()
{
### fstab
infobox "Creating fstab..."
genfstab -U -p /mnt >> /mnt/etc/fstab

### hostname
dialog --no-cancel --inputbox "Please specify your hostname. It is okay to leave default one." 0 0 "myhost" 2> $TMP
cat $TMP > /mnt/etc/hostname

### timezone

# TODO: UTC/localtime
#To change the hardware clock time standard to localtime use:
# timedatectl set-local-rtc 1
#And to set it to UTC use:
# timedatectl set-local-rtc 0

#dialog --no-cancel --menu "Select your hardware clock mode. It is recommended to use UTC, but if you have Windows installed, you should you localtime." 0 0 0  0 UTC 1 localtime  2> $TMP
#rtc=`cat $TMP`
#timedatectl --root=/mnt set-local-rtc $rtc

timezones1=`timedatectl --no-pager list-timezones`
timezones=""
for i in $timezones1; do timezones="${timezones} ${i} -"; done
dialog --no-cancel --menu "Select a timezone." 0 0 0 $timezones 2> $TMP
timezone=`cat $TMP`
arch-chroot /mnt ln -s /usr/share/zoneinfo/${timezone} /etc/localtime

### TODO: locale: locale.conf
# TODO: /etc/locale.gen and generate with locale-gen.

### TODO: console font

### mkinitcpio
# TODO: Configure /etc/mkinitcpio.conf as needed
infobox "Creating initial RAM disk..."
arch-chroot /mnt mkinitcpio -p linux

### Root password
messagebox "Now we need to set root password."
arch-chroot /mnt passwd

### Create new user
dialog --no-cancel --inputbox "Now we will create new user account. Please specify its name." 0 0 "user" 2> $TMP
username=`cat $TMP`
# TODO: -s /bin/zsh
# TODO: -G networkmanager ?
# TODO: -G camera ? errors
# TODO: -G fuse ?
arch-chroot /mnt useradd -m -g users -G audio,disk,floppy,games,locate,lp,network,optical,power,scanner,storage,sys,video,wheel -s /bin/bash ${username}
arch-chroot /mnt passwd ${username}

### sudo
infobox "Installing sudo..."
arch-chroot /mnt pacman -S --noconfirm sudo

cat /mnt/etc/sudoers | sed "s/# %wheel\tALL=(ALL) ALL/%wheel\tALL=(ALL) ALL/" | sed "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" > /mnt/etc/sudoers.new
mv /mnt/etc/sudoers.new /mnt/etc/sudoers
# TODO: preprocess | from "111|111"

### dhcpcd
# Fuck it, we will use NetworkManager.
#dialog --yesno "Enable dhcpcd?
#
#Answer \"yes\" if you are not sure." 0 0
#if [ $? == 0 ]; then
#	systemctl --root=/mnt enable dhcpcd.service
#fi

### ntpd
infobox "Setting up NTP daemon..."
arch-chroot /mnt pacman -S --noconfirm ntp
systemctl --root=/mnt enable ntpd.service


ITEM=8
}

installer_bootload()
{
# TODO: select
#dialog --msgbox "Sorry!" 0 0

#GRUB
#    For BIOS:
# arch-chroot /mnt pacman -S grub-bios
#    For EFI (in rare cases you will need grub-efi-i386 instead):
# arch-chroot /mnt pacman -S grub-efi-x86_64
#    Install GRUB after chrooting (refer to the #Configure the system section).
#Syslinux
# arch-chroot /mnt pacman -S syslinux

infobox "Installing grub..."
arch-chroot /mnt pacman -S --noconfirm grub-bios

disks1="`lsblk -r | grep disk | cut -d" " -f1`"
disks=""
for i in $disks1; do disks="${disks} /dev/${i} -"; done
dialog --menu "Select a hard drive for grub to be installed." 0 0 0 $disks 2> $TMP
if [ $? "!=" 0 ]; then return; fi
disk=`cat $TMP`

infobox "Installing grub to MBR..."
arch-chroot /mnt grub-install $disk
infobox "Creating grub.cfg..."
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

ITEM=9
}

installer_stuff()
{
### yaourt
infobox "Installing yaourt..."
mkdir /mnt/inst
cp -r pkg/package-query /mnt/inst/
arch-chroot /mnt bash -c "cd /inst/package-query/ && makepkg --asroot -s --noconfirm -i"
cp -r pkg/yaourt /mnt/inst/
arch-chroot /mnt bash -c "cd /inst/yaourt/ && makepkg --asroot -s --noconfirm -i"
rm -rf /mnt/inst
arch-chroot /mnt yaourt -S --noconfirm yaourt

### X server
infobox "Installing X server..."
arch-chroot /mnt pacman -S --noconfirm xorg-server xorg-xinit xf86-video-vesa xterm

### GNOME
infobox "Installing GNOME..."
arch-chroot /mnt pacman -S --noconfirm gnome gnome-extra

### GDM
infobox "Installing GDM..."
arch-chroot /mnt pacman -S --noconfirm gdm
systemctl --root=/mnt enable gdm.service

### Fonts
infobox "Installing TTF fonts..."
arch-chroot /mnt pacman -S --noconfirm ttf-bitstream-vera ttf-dejavu ttf-droid ttf-freefont ttf-liberation ttf-ubuntu-font-family

### Other, categorized
infobox "Installing other packages..."
#dialog --no-cancel --checklist "Other packages" 0 0 0 \
#	firefox Firefox on \
#	midori Midori off \
#	chromium Chromium off \
#	lynx Lynx off \
#	links Links on \
#	elinks Elinks off \
#	w3m w3m off \
#	rsync rsync on \
#	grsync grsync off \
#	gnome-system-monitor "GNOME system monitor" on \
#	geany Geany on \
#	netbeans NetBeans off \
#	dmd "Digital Mars D compiler" on \
#	leafpad Leafpad off \
#	gedit gedit on \
#2> $TMP
#packages=`cat $TMP`
#arch-chroot /mnt pacman -S --noconfirm ${packages}
##############arch-chroot /mnt pacman -S --noconfirm firefox midori chromium lynx links elinks w3m rsync grsync gnome-system-monitor geany netbeans dmd leafpad gedit

ITEM=reboot
}

installer_main()
{
dialog --nocancel --default-item $ITEM --menu "Do it step-by-step." 0 0 0  1 "Prepare hard drive" 4 "Connect to Internet" 5 "Select a mirror" 6 "Install base system" 7 "Configure new system" 9 "Install main packages" 8 "Install bootloader" reboot Reboot zsh "Wait! I need command shell." abort Abort 2> $TMP
variant=`cat $TMP`
case $variant in
	1)
		installer_prepare_hdd
		;;
	4)
		installer_internet
		;;
	5)
		installer_mirrors
		;;
	6)
		installer_pacstrap
		;;
	7)
		installer_conf
		;;
	8)
		installer_bootload
		;;
	9)
		installer_stuff
		;;
	reboot)
		dialog --yesno "Reboot now?" 0 0
		if [ $? == 0 ]; then
			reboot
			exit
		fi
		;;
	zsh)
		echo Type \"exit\" or press "Ctrl+D" when you finish.
		zsh
		;;
	abort)
		exit
		;;
esac
installer_main
}

installer_welcome
installer_main
