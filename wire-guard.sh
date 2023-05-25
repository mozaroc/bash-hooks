#!/bin/bash

set -xe

sudo sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

if [[ -z $1 ]];
then 
    echo "Please enter server FQDN"
else

cd /
apt-get update
apt -y install python3-pip
pip install gunicorn ifcfg flask flask_qrcode icmplib
git clone -b v3.1-dev https://github.com/donaldzou/WGDashboard.git wgdashboard

cd /wgdashboard/src

chmod u+x wgd.sh

./wgd.sh install



sudo apt update && sudo apt install -y wireguard


export SERVER_NAME="serverwg"
export INTERFACE_WG="wg0"

sudo mkdir -p /etc/wireguard/keys;

wg genkey | sudo tee "/etc/wireguard/keys/${SERVER_NAME}.key" | \
wg pubkey | sudo tee "/etc/wireguard/keys/${SERVER_NAME}.key.pub";

echo y | ufw reset

echo
echo "CREATING THE SERVER CONFIG"
echo

DEFAULT_INTERFACE="$(ip -o -4 route show to default | awk '{print $5}')"

PRIVATE_KEY=$(sudo cat /etc/wireguard/keys/${SERVER_NAME}.key)

PORT=$(shuf -i 52800-53000 -n1)

cat << EOF | sudo tee "/etc/wireguard/${INTERFACE_WG}.conf"
[Interface]
Address = 10.0.0.1/24
ListenPort = ${PORT}
PrivateKey = ${PRIVATE_KEY}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_INTERFACE} -j MASQUERADE
SaveConfig = true
EOF

sudo chmod 600 "/etc/wireguard/${INTERFACE_WG}.conf" "/etc/wireguard/keys/${SERVER_NAME}.key"

echo
echo "ACTIVATING WIREGUARD SERVICE"
echo

sudo wg-quick up "${INTERFACE_WG}"
sudo wg show "${INTERFACE_WG}"

echo
echo "ENABLE WIREGUARD SERVICE AT BOOT"
echo

sudo systemctl enable wg-quick@wg0

echo
echo "SETTING UP IP FORWARDING"
echo

sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

sudo sysctl -p

echo
echo "ACTIVATING FIREWALL"
echo

sudo ufw allow 10086/tcp

sudo ufw allow ${PORT}/udp
sudo ufw allow 443/tcp

sudo ufw allow 22/tcp # might want to keep ssh open ;-)

echo y | ufw enable

#sudo ufw enable # this will prompt yes/no :(


sudo ufw status verbose

chmod -R 755 /etc/wireguard

cat << EOF | sudo tee "/etc/systemd/system/wg-dash.service"
[Unit]
After=syslog.target network-online.target
ConditionPathIsDirectory=/etc/wireguard

[Service]
Type=forking
User=root
Group=root
PIDFile=/wgdashboard/src/gunicron.pid
WorkingDirectory=/wgdashboard/src
ExecStart=/usr/bin/env gunicorn --access-logfile /wgdashboard/src/log/access.log --certfile /etc/letsencrypt/live/$1/fullchain.pem --keyfile /etc/letsencrypt/live/$1/privkey.pem   --error-logfile /wgdashboard/src/log/error.log 'dashboard:run_dashboard()' --pid /wgdashboard/src/gunicron.pid
PrivateTmp=true
Restart=no

[Install]
WantedBy=multi-user.target

EOF

systemctl enable wg-dash --now

mkdir -p /etc/letsencrypt/renewal-hooks/deploy
cat <<EOF > /etc/letsencrypt/renewal-hooks/deploy/restart-wg-dash.sh
#!/bin/sh
systemctl restart wg-dash
EOF
chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-wg-dash.sh


fi
