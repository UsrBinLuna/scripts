#timedatectl set-ntp true

echo "the disk must have 3 partitions (1- uefi (/boot/efi); 2- swap; 3- root(/)), they should **not** be mounted"
read -r "continue? [Y/n] " ynyn
if [[ $ynyn = "n" || $ynyn = "N" ]]; then
  exit 1
fi
read -r -p "disk (ex: /dev/sda): " dsk
read -r -p "extra packages (separated by spaces): " pkg
read -r -p "timezone (ex. America/Santiago): " TZ
read -r -p "locale (ex. en_US.UTF-8): " LOCALE
read -r -p "enter keyboard layour (ex. la-latin1): " kbd
read -r -p "enter hostname: " HOSTNAME
read -r -p "root password: " PSD
read -r -p "enter username: " USERNAME
read -r -p "enter user password: " UPWD

filesystems(){
  mkfs.vfat -F 32 "$dsk1"
  mkswap "$dsk2"
  mkfs.ext4 "$dsk3"
  mount "$dsk3" /mnt -v
  mkdir /mnt/boot/efi -v -p
  mount "$dsk1" /mnt/boot/efi -v
  swapon "$dsk2"
}

install(){
  echo "installing packages base base-devel linux linux-firmware grub efibootmgr networkmanager intel_ucode sudo $pkg to /mnt"
  pacstrap /mnt base base-devel linux linux-firmware grub efibootmgr networkmanager intel_ucode sudo $pkg
  echo "generating fstab"
  genfstab -U /mnt >> /mnt/etc/fstab
}

time(){
  echo "setting timezone to $TZ"
  ln -s /usr/share/zoneinfo/$TZ /mnt/etc/localtime
  arch-chroot /mnt hwclock --systohc
}

locale(){
  sed -i '/#$LOCALE/s/^#//g' /mnt/etc/locale.gen
  echo "LANG=en_US.UTF-8" >> /mnt/etc/locale.conf
  echo "KEYMAP=$kbd" >> /mnt/etc/vconsole.conf
}

network(){
  
  {
    echo "127.0.0.1 localhost"
    echo "::1       localhost"
    echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME"
  } >> /mnt/etc/hosts
  arch-chroot /mnt systemctl enable NetworkManager.service
}

pass(){ 
  echo root:"$PSD" | chpasswd --root /mnt
}

bootloader(){
  arch-chroot /mnt grub-install "$dsk"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

user(){
  arch-chroot /mnt useradd -m -G wheel,lp -s /bin/bash $USERNAME
  echo "$USERNAME":"$UPWD" | chpasswd --root /mnt
}

sudoperms(){
  echo "$USERNAME ALL=(ALL) ALL" >> /mnt/etc/sudoers.d/"$USERNAME"
}

rebootpc(){
  echo "Unmounting $dsk"
  umount -Rv $dsk
  echo "you may now reboot your computer"
}

main(){
  filesystem
  install
  time
  locale
  network
  pass
  bootloader
  user
  sudoperms
  rebootpc
}
