#!/bin/bash
#
# Author: Aleksandar Stoykovski <bavarien362@protonmail.ch>
#
# Find existing disks, ask user to confirm if disk is to be formated, setup
# file system, auto mount on reboot.
#
# <NOTE> The script doesn't check the type of the file system. It takes into 
# account that system has only basic root fs and any disk devices
# need to be configured.
# Not tested with LUN storage devices. </NOTE>


# Creating file system requires to have super user privileges.
function initial_check() {
  if [[ "${UID}" -ne 0 ]]; then
    printf "\n %30s \n" "usage: sudo ./$(basename $0) " >&2
    exit 1
  fi
}

# Used for better formating in different tasks.
function divider() {
    local divider_type="======================="
    local divider_type="$divider_type$divider_type"
    local divider_width="40"
    printf "%${divider_width}.${divider_width}s\n" "${divider_type}"
    printf "%s\n" "${1}"
    printf "%${divider_width}.${divider_width}s\n" "${divider_type}"
}

# Disk devices found on the system.
# Some of the devices might not be for formating such as usb stick.
# Script will ask to enter those devices.
function disk_check() {
  local all_disk="/tmp/all_disk"
  local exclude_disk="/tmp/exclude_disk"
  while : ; do
    clear
    divider "Checking for avaliable disk devices:"
    # lsblk is used to get disk devices, lsscsi is the prefered option
    # but it doesn't come installed by default.
    local disk_device=$(lsblk -o KNAME,TYPE,SIZE,MODEL | grep disk \
      | awk '{print $1}' \
                         | grep -v sda \
                         | tee ${all_disk} )
    sed -i 's/^/\/dev\//g' "${all_disk}"
    lsblk -o KNAME,TYPE,SIZE,MODEL | grep disk
    echo "--------"
    echo "Press '1' partition all devices found. sda is skipped!"
    echo "Press '2' exclude devices from partition process e.g sdb sdc. sda is skipped!"
    echo "Press 'q' quit the programm."
    read -p "Enter option [1 - 2,q] " option
    case ${option} in
     1)
       # Continue and format all devices found except sda.
       partition_device "$(cat ${all_disk})"
       ;;
     2)
       # Exclude devices from partitioning.
       read -p "device to exclude:" exclude
       # save result to file.
       printf "%s\n" ${exclude} > ${exclude_disk}
       sed -i 's/^/\/dev\//g' ${exclude_disk}
       # match all disk found on the system against user selected for excluding.
       non_excluded=$(grep -vf  ${exclude_disk} ${all_disk} )
       if [[ -z ${non_excluded} || "${?}" -ne 0 ]]; then
         echo "Disk not found, exiting..." >&2
         exit 1
       fi

       echo "Prepare to format device: ${non_excluded}"
       read -p "Are you sure you want to continue? <y/N>" input
       if [[ ${input} == "y" ]]; then
         # move to partition_device function.
         partition_device "$(echo "${non_excluded}")"
       else
         echo "Bye!"
         exit 0
       fi
       sleep 10
       ;;
     q)
       echo "exiting..." >&2
       exit 0
       ;;
     *)
       echo "Please choose valid option"
       read -p "Press [Enter] key to continue..." readEnterKey
       clear
     ;;
    esac
  done
}

function partition_device() {
  divider "Partition devices"
  local disk=${@}

  for mkpart in ${disk}; do
    # Label disk as msdos.
    parted -s ${mkpart} mklabel msdos
    if [[ $? != 0 ]]; then
      echo "Cannot label device, manual check is needed." >&2
      exit 1
    fi
    # Create partition.
    parted ${mkpart} --script mkpart primary 1048s 100%
    if [[ $? != 0 ]]; then
      echo "Cannot make partition, manual check is needed." >&2
    fi
    # Create file system.
    mkfs.ext4 ${mkpart}1
    if [[ $? != 0 ]]; then
      echo "Cannot make partition, manual check is needed." >&2
    fi
  done
  setup_mount
}

function setup_mount() {
  divider "Create mount points and setup fstab"
  local mount_dir="/mnt/test"
  local fstab_tmp="/tmp/fstab"
  local fstab_system="/etc/fstab"
  local backup="$(date +\%Y\%m\%d_\%H-\%M)"

  for dir in ${disk}; do
    mkdir -p ${mount_dir}/${dir##/*/}
  done
  
  # Remove old fstab_tmp if exist and backup fstab.
  rm ${fstab_tmp} 
  cp -p ${fstab_system} ${fstab_system}.${backup}
  # Give information regarding mount points to user
  for mount_point in ${disk}; do
    echo "${mount_point}1  ${mount_dir}/${mount_point#/*/}  ext4 defaults     0 0 " \
      | tee -a ${fstab_tmp}
  done

  read -p "Do you want to add the above mount point <y/N> in fstab:" input
  echo
  if [[ "${input}" == "y" ]]; then 
    cat "${fstab_tmp}" >> "${fstab_system}"
    echo "Mouting partition"
    mount -a
    if [[ "${?}" != 0 ]]; then
      echo "Something went wrong, manual check is needed" >&2
      exit 1
    fi 
  else
    echo "Bye!" 
    exit 0
  fi
}

# Main function is used for calling functions
function main() {
  # Log stdout and stderr.
  exec > >(tee /tmp/fs_creator_$(date +%Y-%m-%d_%H-%M-%S).log)
  exec 2>&1 

  # Script must be run with super user privileges
  initial_check

  # Check for existing disk devices
  disk_check
}

main "${@}"
