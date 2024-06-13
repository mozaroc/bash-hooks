export SERVER_NAME="serverwg"
export INTERFACE_WG="wg0"

sudo mkdir -p /etc/amnezia/amneziawg/keys ;

wg genkey | sudo tee "/etc/amnezia/amneziawg/keys/server.key" | \
wg pubkey | sudo tee "/etc/amnezia/amneziawg/keys/server.key.pub";

DEFAULT_INTERFACE="$(ip -o -4 route show to default | awk '{print $5}')"
MAIN_IP="$(hostname -I | cut -d' ' -f1)"

PRIVATE_KEY=$(sudo cat /etc/amnezia/amneziawg/keys/server.key)

PORT=$(shuf -i 52800-53000 -n1)

J_C=$(shuf -i 7-15 -n1)
J_MIN=$(shuf -i 35-65 -n1)
J_MAX=$(shuf -i 800-950 -n1)
S_1=$(shuf -i 50-70 -n1)
S_2=$(shuf -i 130-150 -n1)
H_1=$(shuf -i 1006457265-1206457265 -n1)
H_2=$(shuf -i 239455488-259455488 -n1)
H_3=$(shuf -i 1109847463-1309847463 -n1)
H_4=$(shuf -i 1546644382-1746644382 -n1)

cat << EOF | sudo tee "/etc/amnezia/amneziawg/${INTERFACE_WG}.conf"
[Interface]
Address = 10.90.90.1/24
ListenPort = ${PORT}
PrivateKey = ${PRIVATE_KEY}
Jc = ${J_C}
Jmin = ${J_MIN}
Jmax = ${J_MAX}
S1 = ${S_1}
S2 = ${S_2}
H1 = ${H_1}
H2 = ${H_2}
H3 = ${H_3}
H4 = ${H_4}

EOF

sudo chmod 600 "/etc/amnezia/amneziawg/${INTERFACE_WG}.conf" "/etc/amnezia/amneziawg/keys/server.key"
sudo wg-quick up "${INTERFACE_WG}"
sudo wg show "${INTERFACE_WG}"
sudo systemctl enable awg-quick@wg0
