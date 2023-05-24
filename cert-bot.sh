#!/bin/bash

set -xe

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g'  /etc/needrestart/needrestart.conf

if [[ -z $1 ]];
then 
    echo "Please enter server FQDN"
else
    echo "FQDN is $1"
    apt-get update
    ufw disable
    snap install core; sudo snap refresh core
    snap install --classic certbot
    certbot certonly -d $1 --standalone -n --agree-tos --email admin@$1    
    echo y | ufw enable
fi



