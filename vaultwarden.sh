#!/bin/bash
set -xe

cd /
apt update

sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp
echo y | ufw enable

sed -i 's/#$nrconf{restart} = '"'"'i'"'"';/$nrconf{restart} = '"'"'a'"'"';/g' /etc/needrestart/needrestart.conf
apt install -y debian-keyring debian-archive-keyring
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list

apt-get update
apt -y install caddy

cat << EOF | sudo tee "/etc/caddy/Caddyfile"
{
    # auto_https will create redirects for https://{host}:8443 instead of https://{host}
    # https redirects are added manually in the http://:80 block
    auto_https disable_redirects
    https_port 443
    http_port 80
    log {
        level ERROR
    }
    on_demand_tls {
        ask      http://google.com/
        interval 60m
    }
}

https://*.*:443,
https://*.*.*:443,
https://*.*.*.*:443,
https://*.*.*.*.*:443,
https://*.*.*.*.*.*:443 {

    reverse_proxy localhost:81
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

curl -fsSL get.docker.com | sudo sh
wget https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -O /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

docker pull vaultwarden/server:latest
docker run -d --name vaultwarden -v /vw-data/:/data/ --restart unless-stopped -p 81:81 vaultwarden/server:latest
