# docker-openvpn
OpenVPN server with easy setup and client management in a minimal docker container (Alpine).

## Setup
The PKI and OpenVPN are configured with environment variables that ca be directly passed to docker or use .env files with docker-compose. Example files would be:

- `easy-rsa.env`
  ```sh
  # The common name for the CA certificate 
  EASYRSA_REQ_CN=OpenVPN Root CA

  # Use Elliptic Curve Cryptography (RECOMMENDED)
  EASYRSA_ALGO=ec

  # Define the named curve. One of: openvpn --show-curves
  EASYRSA_CURVE=secp384r1

  # In how many days should the root CA key expire?
  EASYRSA_CA_EXPIRE=3652

  # In how many days should certificates expire?
  EASYRSA_CERT_EXPIRE=1826

  # How many days until the next CRL publish date. You can check your crl with openssl crl -in crl.pem -noout -text
  EASYRSA_CRL_DAYS=3652
  ```

- `openvpn.env`
  ```sh
  # The public IP of your web server
  PUBLIC_IP=0.0.0.0

  # Either udp (recommended) or tcp
  PROTO=udp

  # The port your server will listen on
  PORT=1194

  # The subnet of your VPN
  IP_SUBNET=192.168.131.0
  IP_MASK=255.255.255.0

  # If CLIENT_TO_CLIENT is set to 1, this directive to allow different clients 
  # to be able to "see" each other. By default, clients will only see the server.
  CLIENT_TO_CLIENT=1

  # A DNS server that is accesible from your server
  DNS_SERVER=1.1.1.1

  # Set to 1 if multiple clients might connect with the same certificate/key
  # files or common names (not recommended)
  DUPLICATE_CN=0
  ```

### Single server
An example `docker-compose.yml` file would be:

```yaml
version: '3.1'

services:
  openvpn:
    build: .
    container_name: openvpn
    cap_add: 
      - NET_ADMIN
    env_file: 
      - easy-rsa.env
      - openvpn.env
    ports: 
      - 1194:1194/udp
    volumes:
      - easy-rsa:/etc/openvpn/easy-rsa
    restart: always

volumes:
  easy-rsa:
```

### Multiple servers
If you want to run several openvpn servers sharing the same PKI volume you can run one docker container as before and pass the option `no-init-pki` to the rest ones. You will need one ovenpn .env file for every server. An example `docker-compose.yml` file with two servers listening on 1194/udp and 443/tcp woul be:

```yaml
version: '3.1'

services:
  openvpn1194udp:
    build: .
    container_name: openvpn_udp
    cap_add: 
      - NET_ADMIN
    env_file: 
      - easy-rsa.env
      - openvpn-udp1194.env
    ports: 
      - 1194:1194/udp
    volumes:
      - easy-rsa:/etc/openvpn/easy-rsa
    restart: always

  openvpn443tcp:
    depends_on: 
      - udp
    build: .
    container_name: openvpn_tcp
    cap_add: 
      - NET_ADMIN
    env_file: 
      - easy-rsa.env
      - openvpn-tcp443.env
    ports: 
      - 443:443/tcp
    command: no-init-pki  # don't try to init the PKI (it's going to be intialized in other container)
    volumes:
      - easy-rsa:/etc/openvpn/easy-rsa
    restart: always

volumes:
  easy-rsa:
```

# PKI management
Exec the following commands in a running container for:
- `pki-list-clients [-revoked]` returns a list with all the active clients. If you need a list of revoked clients, call it with `-revoke`
- `pki-new-client clientName` creates a new client `clientName`
- `pki-revoke-client clientName` revoke existing client `clientName`
- `get-client-ovpn clientName` gets .ovpn file (required for OpenVPN connect App) for client `clientName`