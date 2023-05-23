#!/bin/bash

set -xe

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g'  /etc/needrestart/needrestart.conf

if [[ -z $1 ]];
then
    echo "Please enter server FQDN"
else

apt-get -y install dnsdist acl
setfacl -R -m u:_dnsdist:rx /etc/letsencrypt/



cat << EOF | sudo tee "/etc/dnsdist/dnsdist.conf"
setACL('0.0.0.0/0')
newServer({address="1.1.1.1", qps=1})
newServer({address="8.8.8.8", qps=1})
setServerPolicy(firstAvailable)
addDOHLocal('0.0.0.0', '/etc/letsencrypt/live/$1/fullchain.pem', '/etc/letsencrypt/live/$1/privkey.pem')
EOF


sudo ufw allow 443/tcp

echo y | ufw enable

sudo ufw status verbose



systemctl enable dnsdist --now

fi

