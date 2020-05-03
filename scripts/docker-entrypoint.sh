#!/bin/sh

EASYRSA_ALGO = ${EASYRSA_ALGO:-ec}
if [ "${EASYRSA_ALGO}" = 'ec' ]; then
    EASYRSA_CURVE=${EASYRSA_CURVE:-secp384r1}
fi
PORT=${PORT:-1194}
PROTO=${PROTO:-udp}
IP_SUBNET=${IP_SUBNET:-10.8.16.0}
IP_MASK=${IP_MASK:-255.255.255.0}
DNS_SERVER=${DNS_SERVER:-1.1.1.1}
CLIENT_TO_CLIENT=${CLIENT_TO_CLIENT:-0}

if [ "$1" != 'no-init-pki' ]; then
    if [ -d /etc/openvpn/easy-rsa/pki ]; then
        echo pki volume not empty. Not initializing
    else
        echo pki volume is empty. Creating new CA, server and client certificates
        cd /usr/share/easy-rsa
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki init-pki
        dd if=/dev/urandom of=/etc/openvpn/easy-rsa/pki/.rnd bs=256 count=1
        if [ "${EASYRSA_ALGO}" != 'ec' ]; then
            ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki gen-dh
        fi
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki build-ca nopass
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki build-server-full server nopass
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki gen-crl
        openvpn --genkey --secret /etc/openvpn/easy-rsa/pki/private/serverta.key
    fi
fi

if [ ! -f "/etc/openvpn/easy-rsa/pki/issued/server.crt" ]; then
    # wait just in case pki volume is created in another container/process
    i=0
    imax=60
    echo "PKI volume not initialized. Waiting up to $((3*$imax)) seconds for it to be initialized elsewhere"
    echo "If you just forgot to initialize it, cancel with ctrl-c and call again without passing the no-init-pki command"
    while [ $i != $imax ]; do
        echo -n '*'
        if [ -f "/etc/openvpn/easy-rsa/pki/issued/server.crt" ]; then
            echo " PKI available!"
            break
        fi
        sleep 3
        i=$(($i+1))
    done
    if [ $i = $imax ]; then 
        echo 
        echo "Timeout! pki volume not initialized. Try to init first passing the init-pki command" >&2
        exit 1
    fi
fi

echo 'Initializing tun devices'
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

echo 'Preparing openvpn configuration file'
sed -i "s/{{PORT}}/${PORT}/g; s/{{PROTO}}/${PROTO}/g; s/{{IP_SUBNET}}/${IP_SUBNET}/g; s/{{IP_MASK}}/${IP_MASK}/g; s/{{DNS_SERVER}}/${DNS_SERVER}/g" /etc/openvpn/server.conf
if [ "${EASYRSA_ALGO}" = 'ec' ]; then
    EASYRSA_CURVE=${EASYRSA_CURVE:-secp384r1}
    sed -i "s/{{EASYRSA_CURVE}}/${EASYRSA_CURVE}/g" /etc/openvpn/server.conf
else
    sed -i "/^ecdh-curve /s/^/;/g; /^;dh /s/^;//g; /^dh none/s/^/;/g" /etc/openvpn/server.conf
fi
if [ "${PROTO}" = 'tcp' ]; then 
    sed -i '/^explicit-exit-notify/s/^/;/g' /etc/openvpn/server.conf
fi
if [ "$CLIENT_TO_CLIENT" = '1' ]; then
    sed -i '/^;client-to-client/s/^;//g' /etc/openvpn/server.conf
fi
if [ "$DUPLICATE_CN" = '1' ]; then
    sed -i '/^;duplicate-cn/s/^;//g' /etc/openvpn/server.conf
fi

echo "Enabling IP masquerading of VPN traffic"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

echo 'Launching openvpn'
openvpn --config /etc/openvpn/server.conf
