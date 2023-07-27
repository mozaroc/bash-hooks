#!/bin/bash
set -xe

cd /
apt update

sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf

apt install -y debian-keyring debian-archive-keyring
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

apt-get update
apt -y install python3-pip caddy
pip install gunicorn ifcfg flask flask_qrcode icmplib
git clone -b v3.1-dev https://github.com/donaldzou/WGDashboard.git wgdashboard




cd /wgdashboard/src

chmod u+x wgd.sh

./wgd.sh install



DEBIAN_FRONTEND=noninteractive sudo apt update && sudo apt install -y wireguard


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
MAIN_IP="$(hostname -I | cut -d' ' -f1)"

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
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow ${PORT}/udp
sudo ufw allow 8443/tcp
sudo ufw allow 3478/tcp
sudo ufw allow 3478/udp

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
ExecStart=/usr/bin/env gunicorn --access-logfile /wgdashboard/src/log/access.log --error-logfile /wgdashboard/src/log/error.log 'dashboard:run_dashboard()' --pid /wgdashboard/src/gunicron.pid
PrivateTmp=true
Restart=no

[Install]
WantedBy=multi-user.target

EOF

cat << EOF | sudo tee "/wgdashboard/src/wg-dashboard.ini"
[Account]
username = admin
password = 8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918

[Server]
wg_conf_path = /etc/wireguard
app_ip = 127.0.0.1
app_port = 10085
auth_req = true
version = v3.1
dashboard_refresh_interval = 60000
dashboard_sort = status
dashboard_theme = light

[Peers]
peer_global_dns = 1.1.1.1
peer_endpoint_allowed_ip = 0.0.0.0/0
peer_display_mode = grid
remote_endpoint = ${MAIN_IP}
peer_mtu = 1342
peer_keep_alive = 21

EOF

cat << EOF | sudo tee "/root/compose.yaml"
services:
  nextcloud:
    image: nextcloud/all-in-one:latest
    restart: always
    container_name: nextcloud-aio-mastercontainer
    volumes:
      - nextcloud_aio_mastercontainer:/mnt/docker-aio-config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - 8080:8080
    environment:
      - APACHE_PORT=11000
      - APACHE_IP_BINDING=0.0.0.0

volumes:
  nextcloud_aio_mastercontainer:
    name: nextcloud_aio_mastercontainer
EOF

cat << EOF | sudo tee "/etc/caddy/Caddyfile"
{
    # auto_https will create redirects for https://{host}:8443 instead of https://{host}
    # https redirects are added manually in the http://:80 block
    auto_https disable_redirects
    https_port 10086
    https_port 8443
    https_port 443
    http_port 80
    log {
        level ERROR
    }
}

# Match only host names and not ip-addresses:
https://*.*:10086,
https://*.*.*:10086,
https://*.*.*.*:10086,
https://*.*.*.*.*:10086,
https://*.*.*.*.*.*:10086 {

    reverse_proxy localhost:10085
    tls {
        on_demand
        issuer acme {
            disable_tlsalpn_challenge
        }
    }
}

https://{$IP}:10086 {
  reverse_proxy localhost:10085
  tls internal {
     on_demand
  }  
}


https://*.*:8443,
https://*.*.*:8443,
https://*.*.*.*:8443,
https://*.*.*.*.*:8443,
https://*.*.*.*.*.*:8443 {

    reverse_proxy localhost:8080 {
        transport http {
            tls_insecure_skip_verify
        }
    }
    tls {
        on_demand
        issuer acme {
            disable_tlsalpn_challenge
        }
    }
}

https://*.*:443,
https://*.*.*:443,
https://*.*.*.*:443,
https://*.*.*.*.*:443,
https://*.*.*.*.*.*:443 {

    reverse_proxy localhost:11000
    tls {
        on_demand
        issuer acme {
            disable_tlsalpn_challenge
        }
    }
}

http://*.*:80,
http://*.*.*:80,
http://*.*.*.*:80,
http://*.*.*.*.*:80,
http://*.*.*.*.*.*:80 {
    redir https://{host}{uri} permanent
}


EOF

systemctl daemon-reload

systemctl enable wg-dash --now
systemctl enable caddy
systemctl restart caddy

curl -fsSL get.docker.com | sudo sh
wget https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -O /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose -f /root/compose.yaml up -d

