#!/usr/bin/env bash
set -e

ufw disable
APP_NAME="marzban"
INSTALL_DIR="/opt"
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
HTTP_PORT=$(shuf -i 50000-65535 -n1)
COMPOSE_FILE="$APP_DIR/docker-compose.yml"

MAIL=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
ADMIN_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)
DOMAIN=$1
FILES_URL_PREFIX="https://raw.githubusercontent.com/Gozargah/Marzban/master"

colorized_echo() {
    local color=$1
    local text=$2
    
    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
        *)
            echo "${text}"
        ;;
    esac
}

FETCH_REPO="Gozargah/Marzban-scripts"
SCRIPT_URL="https://github.com/$FETCH_REPO/raw/master/marzban.sh"
colorized_echo blue "Installing marzban script"
curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/marzban
colorized_echo green "marzban script installed successfully"

colorized_echo blue "Installing Docker"
curl -fsSL https://get.docker.com | sh
colorized_echo green "Docker installed successfully"

mkdir -p "$DATA_DIR"
mkdir -p "$APP_DIR"

colorized_echo blue "Fetching compose file"
curl -sL "$FILES_URL_PREFIX/docker-compose.yml" -o "$APP_DIR/docker-compose.yml"
colorized_echo green "File saved in $APP_DIR/docker-compose.yml"

colorized_echo blue "Fetching .env file"
cat << EOF | tee "$APP_DIR/.env"
UVICORN_HOST = "127.0.0.1"
UVICORN_PORT = 8000
SUDO_USERNAME = "admin"
SUDO_PASSWORD = "${ADMIN_PASS}"
XRAY_JSON = "/var/lib/marzban/xray_config.json"
SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"
XRAY_SUBSCRIPTION_URL_PREFIX = "https://${DOMAIN}:${HTTP_PORT}"
EOF

colorized_echo green "File saved in $APP_DIR/.env"

colorized_echo blue "Fetching xray config file"
curl -sL "$FILES_URL_PREFIX/xray_config.json" -o "$DATA_DIR/xray_config.json"
colorized_echo green "File saved in $DATA_DIR/xray_config.json"

colorized_echo blue "Installing caddy"
wget https://github.com/caddyserver/caddy/releases/download/v2.6.4/caddy_2.6.4_linux_amd64.deb
dpkg -i caddy_2.6.4_linux_amd64.deb
rm -rf /etc/caddy/Caddyfile
cat << EOF | sudo tee "/etc/caddy/Caddyfile"
{
    # auto_https will create redirects for https://{host}:8443 instead of https://{host}
    # https redirects are added manually in the http://:80 block
    auto_https disable_redirects
    https_port ${HTTP_PORT}
    http_port  10087
    https_port 443
    http_port 80
    log {
        level ERROR
    }
    on_demand_tls {
		ask http://localhost:10087/
                interval 3600s
                burst 4
	}

}

https://{\$IP}:${HTTP_PORT} {
  reverse_proxy localhost:8000
  tls internal {
    on_demand
  }
}

# Match only host names and not ip-addresses:
https://*.*:${HTTP_PORT},
https://*.*.*:${HTTP_PORT} {

    reverse_proxy localhost:8000
    tls {
        on_demand 
        issuer acme {
            email  ${MAIL}@${MAIL}.com
        }
    }
}


http://:10087 {
  respond "allowed" 200 {
                close
        }
}

EOF

systemctl restart caddy

docker compose -f "$APP_DIR/docker-compose.yml" -p marzban up -d --remove-orphans


colorized_echo green "Marzban installation finished, it is running now..."
echo -e "###############################################"
colorized_echo green "username: admin"
colorized_echo green "password: ${ADMIN_PASS}"
echo -e "###############################################"
colorized_echo green "The panel is available at https://${DOMAIN}:${HTTP_PORT}/dashboard"
echo -e "###############################################"
