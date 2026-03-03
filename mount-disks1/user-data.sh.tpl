#!/bin/bash

until curl -v ifconfig.me; do sleep 5; done
echo "image_id = " ${image_id}
echo "hostname = ${hostname}"
id
apt update && apt install unzip -y

set -x

hostnamectl hostname ${hostname}
timedatectl set-timezone Europe/Moscow

runcmd:
  - |
    #!/bin/bash
    set -euo pipefail
    
    OWNER=33
    MOUNT_DB="/var/lib"
    MOUNT_LOG="/var/log"
    
    DISK1="/dev/vdb"
    DISK2="/dev/vdc"
    
    SIZE1=$(lsblk -b -dn -o SIZE "$DISK1")
    SIZE2=$(lsblk -b -dn -o SIZE "$DISK2")
    
    if [ "$SIZE1" -ge "$SIZE2" ]; then
      DISK_DB="$DISK1"
      DISK_LOG="$DISK2"
    else
      DISK_DB="$DISK2"
      DISK_LOG="$DISK1"
    fi
    
    mount_disk() {
        local DISK_PATH="$1"
        local MOUNT_POINT="$2"
    
        echo "Mounting $DISK_PATH to $MOUNT_POINT"
        
        mkdir -p "$MOUNT_POINT"
        
        if ! blkid "$DISK_PATH" > /dev/null 2>&1; then
            echo "Formatting $DISK_PATH as ext4"
            mkfs.ext4 -F "$DISK_PATH"
            sleep 2
        fi
        
        UUID=$(blkid -s UUID -o value "$DISK_PATH")
        if [ -z "$UUID" ]; then
            echo "Error: Cannot get UUID for $DISK_PATH"
            return 1
        fi
        
        echo "Disk UUID: $UUID"
        
        if grep -q "$MOUNT_POINT" /etc/fstab; then
            echo "Removing existing fstab entry for $MOUNT_POINT"
            grep -v " $MOUNT_POINT " /etc/fstab > /tmp/fstab.new
            mv /tmp/fstab.new /etc/fstab
        fi
        
        if ! grep -q "$UUID" /etc/fstab; then
            echo "Adding fstab entry: UUID=$UUID for $MOUNT_POINT"
            echo "UUID=$UUID $MOUNT_POINT ext4 defaults 0 2" >> /etc/fstab
        else
            echo "UUID $UUID already in fstab"
        fi
        
        if ! mountpoint -q "$MOUNT_POINT"; then
            echo "Mounting $MOUNT_POINT"
            mount "$MOUNT_POINT"
        else
            echo "$MOUNT_POINT already mounted"
        fi
        
        chown -R "$OWNER":"$OWNER" "$MOUNT_POINT"
        echo "Successfully mounted $DISK_PATH (UUID=$UUID) to $MOUNT_POINT"
    }
    
    mount_disk "$DISK_DB" "$MOUNT_DB"
    mount_disk "$DISK_LOG" "$MOUNT_LOG"
    
    echo "Mounted DB: $DISK_DB -> $MOUNT_DB"
    echo "Mounted Logs: $DISK_LOG -> $MOUNT_LOG"
    
    echo -e "\nCurrent fstab entries:"
    grep -E "(UUID|$MOUNT_DB|$MOUNT_LOG)" /etc/fstab
    
    echo -e "\nCurrent mounts:"
    df -h | grep -E "($MOUNT_DB|$MOUNT_LOG)"