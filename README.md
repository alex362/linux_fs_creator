# linux_fs_creator
Objective

File system creator (fs_creator.sh) is a tool which is used in  to setup disk devices and perform the following tasks: create file system, create mount points running across reboots.
It should be used on new installations where there are multiple disk drives detected in order to speed up the deploy process.

Overview

fs_creator.sh - is used by systems administrators to discover disk devices, partition them, perform file system creation and create mount points in order to mount the newly created file systems. Changes are saved in /etc/fstab. 
It doesn’t require access to the network, it uses tools found on modern day Linux distributions so perform the task described above. The best is to be copy on the local file system, and remove any attached USB external storage devices.
Tool is tested on RHEL 7 / Ubuntu 14.04 installed on VirtualBox with 7 virtual disk devices.

Detailed Design

The tool can be run from usb stick or copy to the local file system to user home directory.
Super user privileges are needed when running the script.

First it discover all  block disk devices found (is not tested with SAN storage LUN’s) on the system and asks the user to choose between several options.
Pressing 1 will perform disk discovery on all disk devices found including external attached USB storage devices and will try to label the drive, create partition and format as ext4, if the partition is mounted it will yield and exit with status 1. Once the file system is created it creates mount points and it will ask the user if changes are to be saved in /etc/fstab if <y> program will exit gracefully with exit status 0.

As there are many variables on how to discover disk devices  and on which it should run, its better and more safe for the user to choose option 2, where user choose between storage disk devices. The program doesn’t tell which of the devices are used it assumes that it is run on fresh installation where only the main root file system exist and and is booted from sda. 
Choosing option 2 will ask from the user to enter the devices which are to be excluded  and save the result in a file in /tmp for example: sdb sdg sdd sdr
Afterwards it will compare the result from user chosen devices and all storage devices presented on the system and will run on the ones are available. The rest of the process is the same as described  in “Pressing 1”.
