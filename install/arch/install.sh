#!/bin/bash

sfdisk --delete /dev/sda
wipefs -a /dev/sda

if [ -d "/sys/firmware/efi" ]
then
	parted /dev/sda mklabel gpt
else
	parted /dev/sda mklabel msdos
fi

parted -a optimal /dev/sda mkpart primary fat32 0% 1024MB
parted -a optimal /dev/sda mkpart primary linux-swap 1024MB 5096MB
parted -a optimal /dev/sda mkpart primary btrfs 5096MB 100%

if [ -d "/sys/firmware/efi" ]
then
	echo -e "set 1 esp on" | parted /dev/sda
else
	echo -e "set 1 bios_grub on" | parted /dev/sda
fi

mkfs.fat -F 32 /dev/sda1

mkswap /dev/sda2
swapon /dev/sda2

mkfs.btrfs -L "Arch" /dev/sda3

mount --mkdir /dev/sda3 /mnt
mount --mkdir /dev/sda1 /mnt/boot

pacman -Sy --noconfirm archlinux-keyring

pacstrap /mnt base base-devel grub btrfs-progs mkinitcpio linux linux-firmware nano wget

if [ -d "/sys/firmware/efi" ]
then
	pacstrap /mnt efibootmgr
fi

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt bash -c '
	pacman -Sy networkmanager --noconfirm
	systemctl enable NetworkManager.service

	echo "KEYMAP=fr" >> /etc/vconsole.conf
	echo "FONT=eurlatgr" >> /etc/vconsole.conf

	echo "" >> /etc/pacman.conf
	echo "[blackarch]" >> /etc/pacman.conf
	echo "SigLevel = Never" >> /etc/pacman.conf
	echo "Server = http://blackarch.org/blackarch/\$repo/os/\$arch" >> /etc/pacman.conf

	pacman -Syu

	ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
	hwclock --systohc
	locale-gen

	echo "Skadi" >> /etc/hostname

	grub-mkconfig -o /boot/grub/grub.cfg

	if [ -d "/sys/firmware/efi" ]
	then
		grub-install --target=x86_64-efi --efi-directory=esp --bootloader-id=GRUB
	else
		grub-install --target=i386-pc /dev/sda
	fi

	sed -i "s/^BINARIES=()/BINARIES=(setfont)/g" /etc/mkinicpio.conf
	mkinitcpio -p linux

	echo -e "mypassword\nmypassword" | passwd root

	useradd -m -g users -G wheel -s /bin/bash harkame
	echo -e "mypassword\nmypassword" | passwd harkame
	sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /etc/sudoers
	chown -R harkame /home/harkame
'

umount -R /mnt

reboot
