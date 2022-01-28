#!/usr/bin/env bash

if [ ! "$(sudo file -s ${home_ebs_device})" == "${home_ebs_device}: SGI XFS filesystem "* ]; then
    sudo mkfs -t xfs ${home_ebs_device}
      
    sudo mkdir -p /mnt/temp_home    
    sudo mount ${home_ebs_device} /mnt/temp_home  
    sudo rsync -a /home/* /mnt/temp_home 
    sudo umount ${home_ebs_device}   
        
    # before mounting this we must copy the old data over or we loose our ssh keys
    sudo chown admin:admin /etc/fstab    
    sudo echo "${home_ebs_device} /home xfs  defaults,nofail   0    0 " >> /etc/fstab  
    sudo mount -a

fi




