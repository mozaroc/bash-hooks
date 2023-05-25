#!/bin/bash

set -xe

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g'  /etc/needrestart/needrestart.conf

if [[ -z $1 ]];
then
    echo "Please enter server FQDN"
else
apt-get update
apt-get -y install dnsdist acl
setfacl -R -m u:_dnsdist:rx /etc/letsencrypt/



cat << EOF | sudo tee "/etc/dnsdist/dnsdist.conf"
setACL('0.0.0.0/0')
newServer({address="1.1.1.1", qps=1})
newServer({address="8.8.8.8", qps=1})
newServer({address="9.9.9.9", qps=1})
newServer({address="208.67.222.222", qps=1})
newServer({address="185.228.168.9", qps=1})
newServer({address="94.140.14.14", qps=1})
setServerPolicy(wrandom)

addDOHLocal('0.0.0.0', '/etc/letsencrypt/live/$1/fullchain.pem', '/etc/letsencrypt/live/$1/privkey.pem')
EOF


sudo ufw allow 443/tcp

echo y | ufw enable

sudo ufw status verbose



systemctl enable dnsdist --now
systemctl restart dnsdist 

mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat <<EOF > /etc/letsencrypt/renewal-hooks/deploy/restart-dnsdist.sh
#!/bin/sh
systemctl restart dnsdist
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-dnsdist.sh



fi

