#!/bin/bash

set -xe

if [[ -z $1 ]];
then 
    echo "Please enter server FQDN"
else
    echo "FQDN is $1"
    snap install core; sudo snap refresh core
    snap install --classic certbot
    certbot certonly -d $1 --standalone -n --agree-tos --email admin@$1    
fi



