#!/bin/bash

set -xe

if [[ -z $1 ]];
then 
    echo "Please enter server FQDN"
else
    echo "FQDN is $1"
    ufw disable
    snap install core; sudo snap refresh core
    snap install --classic certbot
    certbot certonly -d $1 --standalone -n --agree-tos --email admin@$1    
    echo y | ufw enable
fi



