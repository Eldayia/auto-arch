#!/bin/sh

# Exit if error
set -e

dev=$1
rootsize=$2
swapsize=$3
bootsize=1

echo "==> ### Begin ArchLinux Installation ###"
echo "==> ### ############################ ###"

echo "==> !! Local Host Name ?"
read hostname

echo "==> !! What disk do you want to use ? (ex: /dev/sda)"
read dev
echo "==> Your $dev disk size (ignore 'unreconized disk label' message): "
parted $dev --script -- print | grep "Disk /" 2> /dev/null
echo "==> The rest of the disk will be used for /home."

echo "==> !! Part / size in GB ('0' if no /home) ?"
read rootsize

echo "==> Sure to erase /dev/sda ? (y or n)"
read i
case $i in
    y)
        echo "==> OK, Go! Erase /dev/sda..."
        set +e
        case $rootsize in
          0)
            echo -e "g\nn\n\n\n\nw\n" | fdisk /dev/sda
            mkfs.ext4 /dev/sda1  > /dev/null
          ;;
          *)
            echo -e "g\nn\n\n\+$rootsizen\nn\n\n\nw\n" | fdisk $dev
            mkfs.ext4 /dev/sda1  > /dev/null
            mkfs.ext4 /dev/sda2  > /dev/null
          ;;
        esac
        set -e
        dd if=/dev/zero of=/swapfile bs=1024 count=524288
        mkswap /swapfile  > /dev/null
        mount /dev/sda1 /mnt/ > /dev/null
        if [ -f /dev/sda2  ]; then
          mkdir /mnt/home/ && mount /dev/sda2 /mnt/home/ > /dev/null
        fi
        echo "==> _____ Done"
    ;;
    *)
        exit 0
        break
    ;;
esac

## Init Update
echo "==> Updating current OS..."
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
echo "[archlinuxfr]" >> /etc/pacman.conf
echo "SigLevel = Never" >> /etc/pacman.conf
echo "Server = http://repo.archlinux.fr/\$arch" >> /etc/pacman.conf
pacman -Syu > /dev/null
echo "==> _____ Done"

## Pacstrap
echo "==> Install base system..."
pacstrap /mnt base  > /dev/null
echo "==> _____ Done"
## Pacman conf
cp /mnt/etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist.backup
cp -f /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
cp /etc/pacman.conf /mnt/etc/pacman.conf
## Bios Bootloader
echo "==> Install bootloader (syslinux)..."
pacstrap /mnt syslinux gptfdisk  > /dev/null
arch-chroot /mnt syslinux-install_update -iam  > /dev/null
echo "==> _____ Done"

## FSTAB
echo "==> Gen fstab..."
genfstab -p /mnt >> /mnt/etc/fstab
echo "==> _____ Done"
## Configs
echo "==> Config New OS..."
echo $hostname > /mnt/etc/hostname
echo "LANG=\"fr_FR.UTF-8\"" > /mnt/etc/locale.conf
arch-chroot /mnt ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
sed -i "s/#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/g" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen  > /dev/null
echo "KEYMAP=fr-latin1" > /mnt/etc/vconsole.conf
echo "==> _____ Done"
## initial RAM disk
echo "==> Init Ram Disk..."
# /etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -p linux > /dev/null
echo "==> _____ Done"

## other Packages
echo "==> Install other packages..."
pacstrap /mnt vim sudo ruby yaourt git openssh zsh make autoconf patch > /dev/null
sed -i "s/#%wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /mnt/etc/sudoers
echo "==> _____ Done"

## Network stuff
echo "==> Install cool Network packages (netctl https://wiki.archlinux.org/index.php/Netctl)..."
pacstrap /mnt netctl dialog dhclient wpa_supplicant wpa_actiond ifplugd bridge-utils > /dev/null
echo "==> _____ Done"

## Xorg
echo "==> !! Do you Xorg ?"
read x
case $x in
    y)
        echo "==> Install XOrg..."
        pacstrap /mnt xorg-server xorg-xinit xorg-xmessage xorg-utils xorg-xmodmap xorg-xrdb \
            alsa-utils ttf-dejavu xterm xf86-input-synaptics xorg-fonts-100dpi > /dev/null
        echo "==> _____ Done"

        echo "==> !! Choose your video card driver: "
        echo "==> [i]Intel(Open), [n]nVidia(Open), [a]ATI(Open), [v]Vesa"
        read driver
        echo "==> Install video card driver..."
        case $driver in
            i)
                pacstrap /mnt xf86-video-intel > /dev/null
            ;;
            n)
                pacstrap /mnt xf86-video-nouveau > /dev/null
            ;;
            a)
                pacstrap /mnt xf86-video-ati > /dev/null
            ;;
            v)
                 	pacstrap /mnt virtualbox-guest-utils virtualbox-guest-modules > /dev/null
            ;;
            *)
                pacstrap /mnt xf86-video-vesa > /dev/null
                break
            ;;
        esac
        echo "==> _____ Done"

        ## WM
        echo "==> !! Do you want a WM ? [g]Gnome, [a]Awesome, [o]Openbox, [i]i3"
        read wm
        case $wm in
            g)
                echo "==> Install Gnome..."
                pacstrap /mnt gnome gnome-tweak-tool gnome-extra > /dev/null
                arch-chroot /mnt systemctl enable gdm.service > /dev/null
                arch-chroot /mnt systemctl enable NetworkManager.service > /dev/null
                echo "==> _____ Done"
            ;;
            a)
                echo "==> Install Awesome..."
                pacstrap /mnt awesome > /dev/null
                echo "==> _____ Done"
            ;;
            o)
                echo "==> Install Openbox..."
                pacstrap /mnt openbox obmenu obconf obkey tint2 nitrogen mirage pcmanfm xfce4-notifyd \
                arch-chroot /mnt lxappearance-obconf > /dev/null
                echo "==> _____ Done"
            ;;
            i)
                echo "==> Install i3..."
                pacstrap /mnt i3 dmenu > /dev/null
                arch-chroot /mnt cp /etc/i3status.conf ~/.config/i3status/config
            ;;
            *)
                break
            ;;
        esac
    ;;
    *)
        break
    ;;
esac

## Users
echo "==> Users"
echo "==> !! Change the root password:"
arch-chroot /mnt passwd
echo "==> !! Username of the new user?"
read username
arch-chroot /mnt useradd -g users -G wheel -m -s /bin/bash $username
echo "==> !! Change the $username password:"
arch-chroot /mnt passwd $username
echo "==> _____ Done"

#Umount
echo "==> Umount..."
if [ -f /dev/sda2 ]; then
  umount /mnt/home  > /dev/null
fi
umount /mnt > /dev/null
echo "==> _____ Done"

echo "==> You can now reboot!"

set +e
