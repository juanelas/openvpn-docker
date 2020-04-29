FROM alpine:latest

RUN apk add --no-cache \
    openvpn \
    easy-rsa && \
    mkdir /var/log/openvpn

# ENV PUBLIC_IP 147.98.4.5
# ENV PROTO udp
# ENV PORT 53
# ENV IP_SUBNET 192.168.130.0
# ENV IP_MASK 255.255.255.0
# ENV DNS_SERVER 8.8.8.8

COPY ./config/server.conf /etc/openvpn/server.conf
COPY ./scripts/* /usr/local/bin/

VOLUME ["/etc/openvpn/easy-rsa"]

ENTRYPOINT [ "docker-entrypoint.sh" ]
