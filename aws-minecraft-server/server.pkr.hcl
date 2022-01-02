
variable "region" {
  type    = string
}
variable "access_key" {
  type    = string
}
variable "secret_key" {
  type    = string
}
variable "role_arn" {
  type    = string
}



data "amazon-ami" "found_debian" {
  filters = {
    name                = "*debian-11-arm64-20211011-792*"  # no EKS and no AWS
    root-device-type    = "ebs"
    virtualization-type = "hvm"
  }
  most_recent = true
  owners      = ["136693071363"]
 
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"   
  assume_role {
        role_arn     = "${var.role_arn}"
        session_name = "packer"
  }
}

locals {
    timestamp_id = "latest" #replace(replace(timestamp(),":","_"),"T","_")
    server_name = "minecraft"
}


source "amazon-ebs" "debian_server" {

  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"   
  assume_role {
        role_arn     = "${var.role_arn}"
        session_name = "packer"
  }
  
  encrypt_boot          = true
  force_delete_snapshot = true
  force_deregister      = true  
  ebs_optimized         = true
   
  source_ami            = "${data.amazon-ami.found_debian.id}"
  ssh_username          = "admin"
 

  max_retries          = 30
  communicator         = "ssh"            
  ssh_timeout          = "30m"


  
  
}

build {

    name="indi"
    	
	source "source.amazon-ebs.debian_server" {
	    name                  = "debian"
		ami_name              = "debian_arm_${local.server_name}_${local.timestamp_id}"
		instance_type         = "t4g.micro"  # 6$ "c6gn.medium" 30$	
		tags          = merge(
		                      {"instance_family" : "t4g"}
						   )
		ena_support   = true
        sriov_support = true
	} 	
	

	
	
	provisioner "shell" {
	    only = ["amazon-ebs.debian"]
		inline = [
		        "dpkg --print-architecture",
		        
		        "sudo apt-get update -y -qq",
                "sudo apt-get install apt-transport-https ca-certificates gnupg lsb-release -y",
                "sudo apt-get install sudo -y",
                		       
		        ######   ensure we have the right time on this server using AWS time service
		        "sudo apt-get install chrony -y", # local time service
			    "sudo echo \"server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4\" > ./chrony.conf2",
			    "sudo cat /etc/chrony/chrony.conf >> ./chrony.conf2",
                "sudo rm /etc/chrony/chrony.conf",
                "sudo mv ./chrony.conf2 /etc/chrony/chrony.conf",
                "sudo /etc/init.d/chrony restart",            
                
                #### common tools
		        "sudo apt-get install curl net-tools bash-completion wget lsof -y",
		        "sudo apt-get install bash -y",
                "sudo apt-get install vim -y",
		        "sudo apt-get install fail2ban -y",
		        "sudo apt-get install iptables-persistent -y",

                "sudo apt-get install haproxy -y", # proxy for jitsi and synapse/Dendrite		        
		        
		        ########      docker  https://www.techlear.com/blog/2021/10/01/how-to-install-docker-on-debian-11/		        
				"sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
				"sudo echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",				
				"sudo apt-get update -y -qq",
 				"sudo apt-get install docker-ce docker-ce-cli containerd.io -y",
                
              
		        ## start of mail installer.   
		        ## https://www.tecmint.com/install-postfix-mail-server-with-webmail-in-debian/
                "echo \"order hosts,bind\" > temp.conf", # read the hosts file first.
                "echo \"multi on\" >> temp.conf",
                "sudo cp temp.conf /etc/host.conf",
                "cat /etc/host.conf",                                
                # just download now and do the install later when we know the domain.
                "sudo apt-get -d install postfix -y",
                "sudo apt-get -d install mailutils -y",
                "sudo apt-get -d install dovecot-core dovecot-imapd -y",

     
		        		     	        		        
	      
		]
	}
}

