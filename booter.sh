#!/bin/bash

# Synopsys: This file is intended to run on a LiveCD Arch Linux system.
# and is intended to install a base system to a specified disk, along with some
# necessary packages and configuration files.

# Propper usage to run this script should be curl https://raw.githubusercontent.com/portalmaster137/ArchyBootstrapper/main/booter.sh | bash

## STAGE 1 : CONFIGURATION ##

#First, determine if this is a UEFI or BIOS system.
BIOS=False
UEFI=False
if [ -d "/sys/firmware/efi/efivars" ]; then
    
    # cat'ing /sys/firmware/efi/fw_platform_size will return the size of the UEFI firmware in bits, either 32 or 64.
    # 32 bit UEFI systems are not supported by Arch Linux, so we will exit if this is the case.
    if [ $(cat /sys/firmware/efi/fw_platform_size) -eq 32 ]; then
        echo "32 bit UEFI systems are not supported by this installer. Exiting."
        exit 1
    fi
    UEFI=True
    echo "UEFI system detected."
else
    BIOS=True
    echo "BIOS system detected."
fi

# Attempt to ping google.com to determine if the system has an internet connection.
# If it does not, exit.

if ! ping -c 1 google.com &> /dev/null; then
    echo "No internet connection detected."
    echo "Attempt to setup your connection with iwctl or mmcli, then try again."
    echo "(DCHP Will work automatically if you use ethernet.)"
    exit 1
fi

lsblk

# Prompt the user for the disk to install to.
echo "Please enter the disk to install to. (Example: /dev/sda, /dev/nvme0n1)"
read DISK

# Prompt the user for the hostname of the system.
echo "Please enter the hostname of the system."
read HOSTNAME

# Prompt the user for the username of the user account to be created.
echo "Please enter the username of the user account to be created."
read USERNAME

#Password comes later.

# Until the user enters a valid timezone, prompt them for one.
TIMEZONE=""
until [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; do
    echo "Please enter your timezone. (Example: America/New_York)"
    read TIMEZONE
done

## STAGE 2 : PARTITIONING ##

#Ask for final confirmation before partitioning.
echo "The following disk will be partitioned: $DISK"
echo "This will erase all data on the disk."
echo "Are you sure you want to continue? (y/n)"

read CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Aborting."
    exit 1
fi

#check to make sure disk exists and has at least ~15GB of space.
if [ ! -b "$DISK" ]; then
    echo "Disk $DISK does not exist."
    exit 1
fi
if [ $(lsblk -b -n -o SIZE $DISK) -lt 15000000000 ]; then
    echo "Disk $DISK is too small. It must be at least 15GB."
    exit 1
fi

# Partition the disk.
if [ "$BIOS" = True ]; then
    echo "Partitioning disk $DISK for BIOS system."
    # MBR BIOS Setup :
    # Mount Point : Partition : Partition Type : Size
    # [SWAP]      : $DISK1    : Linux Swap     : >=512MiB
    # /mnt        : $DISK2    : Linux          : Remainder of disk

    # Create the partitions.
    parted -s $DISK mklabel msdos
    parted -s $DISK mkpart primary linux-swap 1MiB 513MiB
    parted -s $DISK mkpart primary ext4 513MiB 100%

    # Format the partitions.
    mkswap ${DISK}1
    mkfs.ext4 ${DISK}2

    # Mount the partitions.
    mount ${DISK}2 /mnt
    swapon ${DISK}1
    
else
    echo "Partitioning disk $DISK for UEFI system."
    # GPT UEFI Setup :
    # Mount Point : Partition : Partition Type : Size
    # /mnt/boot   : $DISK1    : EFI System     : 1GiB
    # [SWAP]      : $DISK2    : Linux Swap     : >=512MiB
    # /mnt        : $DISK3    : Linux          : Remainder of disk

    # Create the partitions.
    parted -s $DISK mklabel gpt
    parted -s $DISK mkpart primary fat32 1MiB 1025MiB
    parted -s $DISK mkpart primary linux-swap 1025MiB 1537MiB
    parted -s $DISK mkpart primary ext4 1537MiB 100%

    # Format the partitions.
    mkfs.fat -F 32 ${DISK}1
    mkswap ${DISK}2
    mkfs.ext4 ${DISK}3

    # Mount the partitions.
    mount ${DISK}3 /mnt
    swapon ${DISK}2
    mount --mkdir ${DISK}1 /mnt/boot
fi

echo "Disk $DISK has been partitioned, and mounted."