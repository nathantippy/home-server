#!/bin/bash
TIME_ZONE=$${1:-"America/Chicago"}         

# the time is already set by chrony using AWS clocks, we just want the zone.
sudo timedatectl set-timezone $${TIME_ZONE}         
         
echo "-------------------- set up drive ---------------------"

# format ebs volume only if it has not already been formated                     
if [ "$(sudo file -s ${EBS_DEVICE} | grep "SGI XFS filesystem" -c)" -ne 1 ]; then
    echo "format new drive ${EBS_DEVICE}"
    sudo mkfs -t xfs ${EBS_DEVICE}
    # sudo mkfs -t xfs /dev/nvme1n1
fi                     
                    
  
# only switch to the remote drive if it has not been added to fstab for mounting.                     
if [ "$(grep -c 'second_drive xfs' /etc/fstab)" -eq 0 ]; then             

        sudo chown admin:admin /etc/fstab
        #sudo echo "old fstab did not map the var"
        #sudo cat /etc/fstab
    
        echo "adding var to fstab"
        sudo mkdir -p /mnt/second_drive
        sudo echo "${EBS_DEVICE} /mnt/second_drive xfs  defaults,nofail   0    0 " >> /etc/fstab 
        sudo mount -a  #this may take a little time.
   
        # backups are done in 3 parts due to dependencies between these 3 areas.
        sudo mkdir -p /mnt/second_drive/etc_users  # 1. User account data
        sudo mkdir -p /mnt/second_drive/home       # 2. User home data
        sudo mkdir -p /mnt/second_drive/var        # 3. Var data  
    
        # not done because this may be breaking the install.   
        if [ ! "$(ls -A /mnt/second_drive/var)" ]; then
             #echo "setup new var folder", done once             
             sudo cp -p -r -f /var/* /mnt/second_drive/var # keep any new files found before we swap over
             sudo cp -p -r -f /home/* /mnt/second_drive/home # keep any new files found before we swap over
        else
             # always copy so we have the new keys
             sudo cp -p -r -f /home/admin/.ssh/* /mnt/second_drive/home/admin/.ssh
             sudo cp -p -r -f /home/admin/*.sh /mnt/second_drive/home/admin
        fi 

        sudo mv /home /home_back
        sudo ln -s /mnt/second_drive/home /home
        
        sudo mv /var /var_back
        sudo ln -s /mnt/second_drive/var /var
                                   
else
        echo "var already in fstab"     
        sudo mount -a  #this may take a little time.   
fi



