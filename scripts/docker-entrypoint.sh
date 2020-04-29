#!/bin/sh

if [ "$1" = 'init-pki' ]; then
    if [ -d /etc/openvpn/easy-rsa/pki ]; then
        echo pki volume not empty. Not initializing
    else
        echo pki volume is empty. Creating new CA, server and client certificates
        cd /usr/share/easy-rsa
        
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki init-pki
        dd if=/dev/urandom of=/etc/openvpn/easy-rsa/pki/.rnd bs=256 count=1
        # ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki gen-dh
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki build-ca nopass
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki build-server-full server nopass
        ./easyrsa --batch --pki-dir=/etc/openvpn/easy-rsa/pki gen-crl
        openvpn --genkey --secret /etc/openvpn/easy-rsa/pki/private/serverta.key
    fi
fi

# wait just in case pki volume is created in another container/process
i=0
imax=60
echo Waiting up to $((3*$imax)) seconds for the pki volume to be initialized
echo "If you haven't already intialized, cancel with ctrl-c and call again passing the init-pki command"
while [ $i != $imax ]; do
    echo -n '*'
    if [ -f "/etc/openvpn/easy-rsa/pki/issued/server.crt" ]; then
        echo " pki available!"
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

echo Initializing tun devices
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
    mknod /dev/net/tun c 10 200
fi

echo Preparing openvpn configuration file
PORT=${PORT:-'1194'}
PROTO=${PROTO:-'udp'}
IP_SUBNET=${IP_SUBNET:-'10.8.0.0'}
IP_MASK=${IP_MASK:-'255.255.255.0'}
DNS_SERVER=${DNS_SERVER:-'1.1.1.1'}
sed -i 's/{{PORT}}/'${PORT}'/g; s/{{PROTO}}/'${PROTO}'/g; s/{{IP_SUBNET}}/'${IP_SUBNET}'/g; s/{{IP_MASK}}/'${IP_MASK}'/g; s/{{DNS_SERVER}}/'${DNS_SERVER}'/g' /etc/openvpn/server.conf
if [ ${PROTO} = 'tcp' ]; then 
    sed -i 's/^explicit-exit-notify/;explicit-exit-notify/g' /etc/openvpn/server.conf
fi

echo 'Launching openvpn'
openvpn --config /etc/openvpn/server.conf
