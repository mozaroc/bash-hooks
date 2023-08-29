#!/bin/bash

UI_PORT=$(shuf -i 50000-65535 -n1)

echo n | bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
/usr/local/x-ui/x-ui setting -username admin -password admin -port ${UI_PORT}

wget https://github.com/caddyserver/caddy/releases/download/v2.6.4/caddy_2.6.4_linux_amd64.deb
dpkg -i caddy_2.6.4_linux_amd64.deb



rm -rf /etc/caddy/Caddyfile
cat << EOF | sudo tee "/etc/caddy/Caddyfile" 

{
    # auto_https will create redirects for https://{host}:8443 instead of https://{host}
    # https redirects are added manually in the http://:80 block
    auto_https disable_redirects
    https_port 10086
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

https://{$IP}:10086 {
  reverse_proxy localhost:${UI_PORT}
  tls internal {
    on_demand
  }
}

# Match only host names and not ip-addresses:
https://*.*:10086,
https://*.*.*:10086 {

    reverse_proxy localhost:${UI_PORT}
    tls {
        on_demand 
        issuer acme {
            email  client@example.com
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

