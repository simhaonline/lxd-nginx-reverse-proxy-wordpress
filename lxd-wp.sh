echo "#### LXC + LEMP + WordPress by generator by John Mark C." 
echo "#"

# Cloudflare add DNS for this LXC Cloudflare zone is the zone which holds the record
zone=causingdesigns.net
## Cloudflare authentication details keep these private
cloudflare_auth_email=#####
cloudflare_auth_key=####


   #################### 
   # Start - Clean mode
   if [ "$1" == "clean" ]
   then
      # play.yml file check
      FILE=*.yml
      if ls $FILE 1> /dev/null 2>&1; then
         echo "#"
         echo "# $FILE exists. Deleting..!"
         rm $FILE
      else
         echo "#"
         echo "# $FILE does not exist. Already clean!"
      fi
      # ansible_wpconfig.php file check
      FILE=ansible_wpconfig.php
      if [ -f "$FILE" ]; then
         echo "# $FILE exists. Deleting..!"
         rm $FILE
      else
         echo "# $FILE does not exist. Already clean!"
      fi
      # haproxy.cfg file check
      FILE=haproxy.cfg
      if [ -f "$FILE" ]; then
         echo "# $FILE exists. Deleting..!"
         rm $FILE 
      else 
         echo "# $FILE does not exist. Already clean!"
      fi

      
      # host file check
      if ls *host* 1> /dev/null 2>&1; then
         echo "# Hosts file do exist. Deleting!"
         rm *host*
      else
         echo "# Hosts file is already clean!"
      fi

      # playbook retry file check
      if ls *retry* 1> /dev/null 2>&1; then
         echo "# playbook retry file do exist. Deleting!"
         rm *retry*
      else
         echo "# playbook retry file is already clean!"
      fi 


      # default nginx file check
      FILE=default
      if [ -f "$FILE" ]; then
         echo "# $FILE nginx config exists. Deleting..!"
         rm $FILE 
         
      else 
         echo "# $FILE nginx config file does not exist. Already clean!"
      fi


      #  - START - Clean up ssh keys with lxc string
      #
      if [[ $(ls $HOME/.ssh/ | grep lxc) ]]; 
      then
         echo "# LXC ssh files found! Deleting.."
         rm $HOME/.ssh/*lxc*
      else
         echo "# No LXC SSH key found. Already clean!"
      fi
      #
      # - END -  Clean up ssh keys with lxc string

      #  - START - Cloudflare subdomain clean up
      #
      if [[ $(lxc list | awk '!/NAME/{print $2}') ]]; 

      then
         echo "# Cloudflare DNS subdomain clean up"


         lxc_list=$(lxc list | awk '!/NAME/{print $2}' | awk NF)
   
         # Setting up array for list of LXC
         lxc_list_array=($lxc_list)

         # Marking lxc not for deletion
         dont_delete=rproxy

         # Start loop
         for item in "${lxc_list_array[@]}"; do

            if [[ $dont_delete == "$item" ]]; 
            then 
               echo "# $item is found! Not for CF Deletion.."
            else

               # Start -- Deleting subdomain block 
               echo "# Deleting Cloudflare subdomain $item... "


               # Get the zone id for the requested zone
               zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
               -H "X-Auth-Email: $cloudflare_auth_email" \
               -H "X-Auth-Key: $cloudflare_auth_key" \
               -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

               echo "# Zoneid for $zone is $zoneid"
               echo "#"
               dnsrecord=$item

               # Get the DNS record ID
               dnsrecordid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrecord.${zone}" \
                  -H "X-Auth-Email: $cloudflare_auth_email" \
                  -H "X-Auth-Key: $cloudflare_auth_key" \
                  -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

               echo "# DNS record ID for $dnsrecord is $dnsrecordid" 

               # Delete DNS records
               echo "# Deleting $dnsrecord dns record.."
               echo "#"
               result=$(
               curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
                  -H "X-Auth-Email: $cloudflare_auth_email" \
                  -H "X-Auth-Key: $cloudflare_auth_key" \
                  -H "Content-Type: application/json" \
               )
               # echo $result
               if [[ "$result" == *"method_not_allowed"* ]]
               then
                  echo "# Failed. Result: $result"
                  echo "#"
                  echo "# Make sure you entered the correct domain like domain.com or subdomain like hello.domain.com"
                  echo "# Or make sure it exist!"
                  else 
                  echo "# Success!"
                  echo "#"
                  echo "# Result: $result"
               fi
               # END -- Deleting subdomain block 
            fi
         done
         # End loop

   else
      echo "# Already clean!"
   fi   
      #
      # - END -   Cloudflare subdomain clean up



      #  - START - Clean up LXC containers
      #
   if [[ $(lxc list | awk '!/NAME/{print $2}') ]]; 
   then
      echo "# LXC Containers found! Deleting.."+
      if [[  $(lxc list | awk '!/NAME/{print $2}') == *"rproxy"* ]]; then
      echo "# There's a proxy container.."
      fi
      lxc_list=$(lxc list | awk '!/NAME/{print $2}' | awk NF)

      # Setting up array for list of LXC
      lxc_list_array=($lxc_list)
      # Marking lxc not for deletion
      dont_delete=rproxy
      for item in "${lxc_list_array[@]}"; do
         if [[ $dont_delete == "$item" ]]; 
         then 
            echo "# $item is found! This is your Reverse Proxy container. NEVER DELETE!"
         else
            echo "# Deleting LXC $item... (FORCED)"
            lxc delete $item --force
            
         fi
      done

   else
   echo "# No LXC Containers found. Already clean!"
   fi   
      #
      # - END -   Clean up LXC containers



      # Cleaning sites from Reverse Proxy container
      echo "# Cleaning Reverse Proxy LXC site files in /etc/nginx/sites-available/"
      echo "# "
      lxc exec rproxy -- sh -c "find /etc/nginx/sites-available/ ! -name default  -type f -delete" --verbose

      
      echo "# Cleaning Reverse Proxy LXC symlink site files in /etc/nginx/sites-enabled"
      echo "# "
      lxc exec rproxy -- sh -c "find /etc/nginx/sites-enabled/ ! -name default  -type l -delete" --verbose
      lxc exec rproxy -- sh -c "find /etc/nginx/sites-enabled/ ! -name default  -type f -delete" --verbose

      echo "# Done! Reverse Proxy container is now clean!!" 
      echo "#"

      lxc list
      ls -al $HOME/.ssh/
      echo "#"
      echo "# Done!"
      exit 1
   fi
   # END - Clean mode
   ################## 


   echo "# Hello! Enter the LXC container name please:"
   read -p "# Enter LXC name: " lxcname

   # Read WordPress Password
   echo -n "# Enter your WordPress Password": 
   read -s wppassword

   echo "# Hello! Enter the LXC container name please:"
   read -p "# Enter your WordPress email: " wpemail
   echo "#"
   echo "#"


   echo "# Alright! Let's generate the LXC container Ubuntu 18.04: $lxcname"
   echo "#"
   echo "#"

   echo "# Let's update.. (apt install update)"
   echo "#"
   sudo apt -y update -qq
   
   
   echo "# Checking required apps.."

   # Check if jq app exist for cloudflare. If not, then install.
   if ! command -v jq &> /dev/null
   then
      echo "# jq is not yet installed"
      echo "# Installing jq.."
      echo "#"
      sudo apt -y install jq -qq
      
   else
      echo "# jq is here.."
   fi


   # Check if Ansible app exist. If not, then install.
   if ! command -v ansible &> /dev/null
   then
      echo "# Ansible is not yet installed"
      echo "# Installing Ansible.."
      sudo apt -y update -qq
      sudo apt -y install ansible -qq
      
   else
      echo "# Ansible is here.."
   fi




   echo "#"
   echo "# Testing Cloudflare connection.."
   # Get the zone id for the requested zone
   zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
   -H "X-Auth-Email: $cloudflare_auth_email" \
   -H "X-Auth-Key: $cloudflare_auth_key" \
   -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

   echo "# Zoneid for $zone is $zoneid"
   echo "#"


   # Upgrades are needed for Ansible to work
   echo "# Checking for apt update and upgrades.."
   if [[ $(sudo apt list --upgradeable | grep ubuntu) ]];
   then   
      echo "# There's an upgrade available."
      echo "# Updating and upgrading now.. - apt update && apt upgrade"
      sudo apt -y update -qq
      sudo apt -y upgrade -qq
   else
      echo "# No upgrades needed.."
   fi


   # LXD check profile and permission
   if [[ $(lxc profile show default | grep "devices: {}") ]]; 
   then
      if [[ $(groups $(whoami) | grep "lxd") ]];  
      then
         echo "# You are a member of LXD group!"
         echo "# Downloading and applying LXD config.."
         wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/lxdconfig.yaml
         sudo lxd init --preseed < lxdconfig.yaml
         rm lxdconfig.yaml   
      else
         echo "# You are NOT a member of LXD Group.."
         echo "#"
         echo "# Adding this user $(whoami) to LXD group. Please run this script again!" 
         sudo adduser $(whoami) lxd
         newgrp lxd
      fi
   else
      echo "# LXD is already configured. Let's proceed."
   fi
      





   #  - START - Nginx Reverse Proxy check
   ##    
   ##    
   if [[ $(lxc list | grep rproxy) ]]; 
   then
      echo "# Reverse Proxy container is found!"
      echo "#"
   else

      # Checking LXD version.  Version 3 will continue. Version 2 will exit!
      if [[ $(sudo lxd --version | grep 4.) ]]; 
      then
         echo "# LXD is version $(sudo lxd version). We will proceed adding LXD Proxy device"

      else
         echo "# Installing LXD from Snap to get version 4.x.."
         echo "# "
         sudo snap install lxd
         sudo lxd.migrate -yes
         wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/lxdconfig.yaml
         sudo lxd init --preseed < lxdconfig.yaml
         rm lxdconfig.yaml   
      fi
   
      echo "# Reverse Proxy container is not here. Installing Reverse Proxy container"
      lxc launch ubuntu:18.04 rproxy
      echo "#"
      echo "# Trying to get the Reverse Proxy container IP Address.."
      rproxy_LXC_IP=$(lxc list | grep rproxy | awk '{print $6}')
      VALID_IP=^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$
      # START - SPINNER 
      #
      sp="/-\|"
      sc=0
      spin() {
      printf "\b${sp:sc++:1}"
      ((sc==${#sp})) && sc=0
      }
      endspin() {
      printf "\r%s\n" "$@"
      }
      #
      # - END SPINNER
      # Getting the IP of LXC
      while ! [[ "${rproxy_LXC_IP}" =~ ${VALID_IP} ]]; do
            rproxy_LXC_IP=$(lxc list | grep rproxy | awk '{print $6}')
            spin
      done
      endspin
      echo "# "
      echo "# IP Address found! Reverse Proxy container LXC IP: ${rproxy_LXC_IP}"
      
      echo "# "
      echo "# Updating Reverse Proxy container"
      echo "# "
      lxc exec rproxy -- sh -c "apt update -qq" --verbose



      # Setting up  Reverse Proxy container
      echo "# "
      echo "# Adding proxy device to Reverse Proxy container (rproxy)"
      lxc config device add rproxy myport80 proxy listen=tcp:0.0.0.0:80 connect=tcp:127.0.0.1:80 proxy_protocol=true
      lxc config device add rproxy myport443 proxy listen=tcp:0.0.0.0:443 connect=tcp:127.0.0.1:443 proxy_protocol=true


      echo "# "
      echo "# Install nginx to Reverse Proxy container..."
      lxc exec rproxy -- sh -c "apt -y install nginx -qq" --verbose


      # Install Let's Encrypt certbot to rprox continer
      echo "# "
      echo "# Let's install SSL Let's Encrypt certbot..."

      echo "# "
      echo "# Adding repository ppa:certbot/certbot"
      lxc exec rproxy -- sh -c "add-apt-repository ppa:certbot/certbot -y" --verbose

      echo "# Install certbot (support the creating of LE) and python-certbot-nginx (auto-configure the NGINX reverse proxy to use Let’s Encrypt certificates.)"
      lxc exec rproxy -- sh -c "apt-get install certbot python-certbot-nginx -y -qq" --verbose

      echo "# "
      echo "# Run certbot for nginx SSL automation.."
      lxc exec rproxy -- sh -c "certbot --nginx --non-interactive --agree-tos -m johnmarkcausing@gmail.com" --verbose
      





   

    
   fi
   ##    
   ## 
   #  - END - Nginx Reverse Proxy check




   # 18.04
   lxc launch ubuntu:18.04 $lxcname

   # 16.04
   #lxc launch ubuntu:16.04 $lxcname

   # Initial Cloudflare Setup
   echo "#"
   echo "# This is still designed for subdomain. Sites are inserted in proxy container /etc/nginx/sites-available/"
   echo "#"
   echo "# Let's setup your Cloudflare domain to add the dns.."

   cfdomain=$lxcname

   # Get the current external IP address
   ip=$(curl -s -X GET https://checkip.amazonaws.com)

   echo "# Current IP is $ip"


   if host $cfdomain 1.1.1.1 | grep "has address" | grep "$ip"; then
   echo "# $cfdomain is currently set to $ip; no changes needed"
   # exit
   fi



   # Get the zone id for the requested zone
   zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
   -H "X-Auth-Email: $cloudflare_auth_email" \
   -H "X-Auth-Key: $cloudflare_auth_key" \
   -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

   echo "# Zoneid for $zone is $zoneid"
   echo "#"


   # Create DNS records
   result=$(
   curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/" \
      -H "X-Auth-Email: $cloudflare_auth_email" \
      -H "X-Auth-Key: $cloudflare_auth_key" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$cfdomain\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}"
   )
   # echo $result
   if [[ "$result" == *"success\":false"* ]]
      then
      echo "# Failed. "
      echo "#":
      echo "# Result: $result"
      echo "#"
      else 
         echo "# Success!!"
         echo "#"
         echo "# Result: $result"
         echo "#"
   fi

   echo "#"
   echo "#"
   echo "# Cloudflare DNS setup i done! Your subdomain is $cfdomain.causingdesigns.net"
   echo "# Visit your WordPress site after this install using this link: http://$cfdomain.causingdesigns.net"


   echo "#"
   echo "# Let's generate SSH-KEY gen for this LXC"
   echo "#"
   ssh-keygen -f $HOME/.ssh/id_lxc_$lxcname -N '' -C 'key for local LXC'

   echo "#"
   echo "# - START - Details from ssh key gen"

   # ls $HOME/.ssh/
   # cat $HOME/.ssh/id_lxc_$lxcname.pub


   echo "#"
   echo "#"
   echo "# START - Info of LXC: ${lxcname}"


   echo "#"
   echo "# Trying to get the LXC IP Address.."


   LXC_IP=$(lxc list | grep ${lxcname} | awk '{print $6}')


   VALID_IP=^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$


   # START - SPINNER 
   #
   sp="/-\|"
   sc=0
   spin() {
      printf "\b${sp:sc++:1}"
      ((sc==${#sp})) && sc=0
   }
   endspin() {
      printf "\r%s\n" "$@"
   }
   #
   # - END SPINNER


   while ! [[ "${LXC_IP}" =~ ${VALID_IP} ]]; do
   # sleep 1
   #  echo "LXC ${lxcname} has still no IP "
   #  echo "Checking again.." 
   #  echo "#"
   #  echo "#"
   #  lxc list
      LXC_IP=$(lxc list | grep ${lxcname} | awk '{print $6}')
      spin
   #  echo "IP is: ${LXC_IP}"
   done
   endspin

   echo "# IP Address found!  ${lxcname} LXC IP: ${LXC_IP}"
   #lxc info $lxcname
   echo "# "

   echo "# Checking status of LXC list again.."
   lxc list


   echo "# Sending public key to target LXC: " ${lxcname}
   echo "#"
   #echo lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys

   #Pause for 2 seconds to make sure we get the IP and push the file.
   sleep 5

   # Send SSH key file from this those to the target LXC
   echo "######## lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys --verbose"
   lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys --verbose

   echo "#"
   echo "# Fixing root permission for authorized_keys file"
   echo "#"
   lxc exec ${lxcname} -- chmod 600 /root/.ssh/authorized_keys --verbose
   lxc exec ${lxcname} -- chown root:root /root/.ssh/authorized_keys --verbose
   echo "#"
   echo "# Adding SSH-key for this host so we can SSH to the target LXC."
   echo "#"
   eval $(ssh-agent); 
   ssh-add $HOME/.ssh/id_lxc_$lxcname
   echo "#"
   echo "# Done! Ready to connect?"
   echo "#"
   echo "# Connect to this: ssh -i ~/.ssh/id_lxc_${lxcname} root@${LXC_IP}"
   echo "#"
   echo "#"

   # ssh key variable location
   SSHKEY=~/.ssh/id_lxc_${lxcname}

   echo "[lxc]
   ${LXC_IP} ansible_user=root "> ${lxcname}_hosts

   # Downloading ansible files 
   # Ansible playbook file check


   # nginx default config file
   FILE=default
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting and downloading a fresh one!"
      rm default
      wget -q w https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/default
      echo "#"
      
   else 
      echo "#"
      echo "# $FILE does not exist."
      echo "# Downloading a fresh nginx default config file"
      wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/default
      echo "#"
   fi

   # vars file check
   FILE=vars.yml
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting and downloading a fresh one!"
      rm vars.yml
      wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/vars.yml
      echo "#"
      
   else 
      echo "#"
      echo "# $FILE does not exist."
      echo "# Downloading vars.yml for Ansible"
      wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/vars.yml
      echo "#"
   fi

   # wp-config.php file check
   FILE=ansible_wpconfig.php
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting and downloading a fresh one!"
      rm ansible_wpconfig.php
      wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/ansible_wpconfig.php
      echo "#"
      
   else 
      echo "#"
      echo "# $FILE does not exist."
      echo "# Downloading a fresh nginx default config file"
      wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/ansible_wpconfig.php
      echo "#"
   fi

   # Ansible playbook play.yml file check
   FILE=play.yml
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting and downloading a fresh one!"
      rm play.yml
      wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/play.yml
      mv play.yml ${lxcname}_lemp.yml
      echo "#"
      
   else 
      echo "#"
      echo "# $FILE does not exist."
      echo "# Downloading a fresh nginx default config file"
      wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/play.yml
      mv play.yml ${lxcname}_lemp.yml
      echo "#"
   fi

   echo "# Checking files.."
   ls -al  ${lxcname}_lemp.yml
   ls -al  ${lxcname}_hosts
   ls -al vars.yml
   echo "#"

   echo "# Updating mysql credentials.."
   sed -i "s/mysqluser/${lxcname}/g" vars.yml
   sed -i "s/mysqlpasswd/${wppassword}/g" vars.yml

   echo "#"
   echo "# Running playbook with this command:"
   echo "#"
   echo "# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ${lxcname}_lemp.yml -i ${lxcname}_hosts --private-key=${SSHKEY}"
   echo "#"

   time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ${lxcname}_lemp.yml -i ${lxcname}_hosts --private-key=~${SSHKEY} 


   # Remove this later if its working then enable Ansible
   #
   #
   # echo "# Downloading Nginx..."
   # lxc exec ${lxcname}  -- sh -c "apt -y install nginx -qq" --verbose; lxc exec ${lxcname}  -- sh -c "rm /var/www/html/index.nginx-debian.html" --verbose; lxc exec ${lxcname}  -- sh -c "echo \"<h1> This is LXC ${lxcname}\" >> /var/www/html/index.nginx-debian.html" --verbose
   #
   #
   # Remove this later if its working then enable Ansible


   echo "#"
   echo "# Add user 'ubuntu' to groups www-data"
   lxc exec ${lxcname} -- sh -c "usermod -a -G www-data ubuntu" --verbose
   lxc exec ${lxcname} -- sh -c "ls -al /var/www/html" --verbose


   # Configure Reverse Proxy container (rproxy) for this LXC
   #!/bin/bash
   echo "#"
   echo "# Let's configure Reverse Proxy for this container so the world can see it!"
   
   # Creating file /etc/nginx/conf.d/real-ip.conf in the newly created LXC
   lxc exec ${lxcname} -- sh -c "echo \"real_ip_header    X-Real-IP;\" >> /etc/nginx/conf.d/real-ip.conf" --verbose
   lxc exec ${lxcname} -- sh -c "echo \"set_real_ip_from  rproxy.lxd;\" >> /etc/nginx/conf.d/real-ip.conf" --verbose


   # Test and Reload Nginx for this LXC
   lxc exec ${lxcname} -- sh -c "nginx -t; systemctl reload nginx" --verbose


   # Downloading default nginx1.example.com file
   echo "# "
   echo "# Download and transfer default nginx site config file"    
   wget -q https://raw.githubusercontent.com/jmcausing/lxd-nginx-reverse-proxy-wordpress/master/nginx1.example.com   

   mv nginx1.example.com  ${cfdomain}.causingdesigns.net

   # Insert site domain name to the nginx file
   sed -i  "/^    # server_name/a\    server_name ${cfdomain}.causingdesigns.net;"  ${cfdomain}.causingdesigns.net 
   sed -i  "/^            # proxy_pass/a\            proxy_pass http://${lxcname}.lxd;" ${cfdomain}.causingdesigns.net 

   # Send nginx site file
   lxc file push ${cfdomain}.causingdesigns.net rproxy/etc/nginx/sites-available/${cfdomain}.causingdesigns.net --verbose

   # Remove nginx file ${cfdomain}.causingdesigns.net
   rm ${cfdomain}.causingdesigns.net

   # Enable this site (symlink nginx)
   lxc exec rproxy -- sh -c "ln -s /etc/nginx/sites-available/${cfdomain}.causingdesigns.net /etc/nginx/sites-enabled/" --verbose

  
   echo "# "
   echo "# Apply Let's Encrypt SSL for this domain (certbot automated)"
   lxc exec rproxy -- sh -c "certbot --nginx --non-interactive --agree-tos --domains ${cfdomain}.causingdesigns.net --email johnmarkcausing@gmail.com" --verbose 


   echo "# "
   echo "# Append proxy_protocol to nginx config ssl line"
   lxc exec rproxy -- sh -c "sed -i 's/ssl;/ssl proxy_protocol;/g' /etc/nginx/sites-available/${cfdomain}.causingdesigns.net"  --verbose
   lxc exec rproxy -- sh -c "sed -i 's/ssl;/ssl proxy_protocol;/g' /etc/nginx/sites-enabled/${cfdomain}.causingdesigns.net"  --verbose

  
   # Test and Reload Nginx for RPROXY container
   lxc exec rproxy -- sh -c "nginx -t; systemctl reload nginx" --verbose

   # Setup WP CLI
   echo "#"
   echo "# Download and install WP-CLI"
   lxc exec ${lxcname} -- sh -c "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" --verbose
   lxc exec ${lxcname} -- sh -c "php wp-cli.phar --info" --verbose
   lxc exec ${lxcname} -- sh -c "chmod +x wp-cli.phar" --verbose
   lxc exec ${lxcname} -- sh -c "sudo mv wp-cli.phar /usr/local/bin/wp" --verbose


   # Install the WordPress database.
  
   lxc exec ${lxcname} -- sudo --login --user ubuntu sh -c "wp core install --url=https://$cfdomain.causingdesigns.net --title=${lxcname} --admin_user=${lxcname}  --admin_password=${wppassword}  --admin_email=${wpemail}   --path=/var/www/html" --verbose


   # Search and replace
   # echo "#"
   # echo "# WP-CLI run search and relace to fix mixed-content issue"
   # lxc exec ${lxcname} -- sudo --login --user ubuntu sh -c "wp search-replace http://$cfdomain.causingdesigns.net https://$cfdomain.causingdesigns.net --path=/var/www/html" --verbose


   # Seutp phpmyadin
   echo "#"
   echo "# Let's setup phpmyadmin..."
   echo "#"
   echo "# Running: export DEBIAN_FRONTEND=noninteractive;apt-get -yq install phpmyadmin"
   lxc exec  ${lxcname} -- sh -c "export DEBIAN_FRONTEND=noninteractive;apt-get -yq install phpmyadmin > /dev/null" --verbose


   echo "#"
   echo "# Running: dpkg-reconfigure --frontend=noninteractive phpmyadmin"
   lxc exec ${lxcname} -- sh -c "dpkg-reconfigure --frontend=noninteractive phpmyadmin" --verbose 

   echo "#"
   echo "# ln -s /usr/share/phpmyadmin /var/www/html"
   lxc exec ${lxcname} -- sh -c "ln -s /usr/share/phpmyadmin /var/www/html" --verbose 

   echo "#"
   echo "# systemctl restart php7.3-fpm"
   lxc exec ${lxcname} -- sh -c "systemctl restart php7.3-fpm" --verbose 

   # Setup add user and enable SSH password authentication
   echo "# Let's setup SSH access.."   
   echo "#"

   # Setup ssh port random and password
   echo "# Settng up random port and password"
   echo "#"
   # ssh port also allowed in GPC firewall tcp:2000-2999
   sshport=22$(( $RANDOM % 10 + 90 ))
   sshpass=$(openssl rand -base64 12);


   echo "# Addning proxy device for ssh:"
   echo "# lxc config device add john sshport$sshport proxy listen=tcp:0.0.0.0:$sshport connect=tcp:127.0.0.1:22"
   echo "#"
   lxc config device add ${lxcname} sshport$sshport proxy listen=tcp:0.0.0.0:$sshport connect=tcp:127.0.0.1:22

   echo "# Adding SSH user and password update.."
   echo "#"
   lxc exec ${lxcname} -- sh -c "useradd -m -g www-data -p 1234 ${lxcname}" --verbose
   lxc exec ${lxcname} -- sh -c "echo ${lxcname}:$wppassword-$sshpass | chpasswd"

   echo "# Configure SSH allow password authentication.."
   echo "#"
   lxc exec ${lxcname} -- sh -c "echo 'Match User ${lxcname}' >> /etc/ssh/sshd_config" --verbose
   lxc exec ${lxcname} -- sh -c "echo 'PasswordAuthentication yes' >>/etc/ssh/sshd_config" --verbose

   echo "# Restart SSH service.."
   echo "#"
   lxc exec ${lxcname} -- sh -c "systemctl restart sshd" --verbose


   echo "# Nicely done! Please see your WordPress login details below. Have fun!"
   echo "#"
   echo "#"
   echo "# Visit your WordPress site using this link: http://$cfdomain.causingdesigns.net"
   echo "# Phpmyadmin - http://$cfdomain.causingdesigns.net/phpmyadmin - username: ${lxcname} -- Password: the one you entered earlier"
   echo "# WordPress login url: http://$cfdomain.causingdesigns.net/wp-admin "
   echo "# WordPerss username: ${lxcname} -- Password: the one you entered earlier" 
   echo "# SSH access: ssh ${lxcname}@$cfdomain.causingdesigns.net -p $sshport"
   echo "# SSH password is your WP password + -$sshpass. Example: Mypassword1234-$sshpass"
   echo "# Note: Make sure you also allow ports like this in GPC firewall tcp:2000-2999"
   echo "#"
   echo "#"
   echo "# Thank you for using LXC LEMP + WordPress setup!"


