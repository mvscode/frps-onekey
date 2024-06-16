#!/bin/bash

# 创建证书存放目录
mkdir -p /etc/pki/tls/frp/ca
mkdir -p /etc/pki/tls/frp/frps
mkdir -p /etc/pki/tls/frp/frpc

# 创建 OpenSSL 配置文件
cat > /etc/pki/tls/frp/my-openssl.cnf << EOF
[ ca ]
default_ca = CA_default
[ CA_default ]
x509_extensions = usr_cert
[ req ]
default_bits        = 2048
default_md          = sha256
default_keyfile     = privkey.pem
distinguished_name  = req_distinguished_name
attributes          = req_attributes
x509_extensions     = v3_ca
string_mask         = utf8only
[ req_distinguished_name ]
[ req_attributes ]
[ usr_cert ]
basicConstraints       = CA:FALSE
nsComment              = "OpenSSL Generated Certificate"
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = CA:true
EOF

# 生成默认 CA
echo "====> Generating CA key and certificate"
openssl genrsa -out /etc/pki/tls/frp/ca/ca.key 2048
openssl req -x509 -new -nodes -key /etc/pki/tls/frp/ca/ca.key -subj "/CN=example.ca.com" -days 5000 -out /etc/pki/tls/frp/ca/ca.crt

# 生成服务器证书
echo "====> Generating server key and certificate"
openssl genrsa -out /etc/pki/tls/frp/frps/server.key 2048
openssl req -new -sha256 -key /etc/pki/tls/frp/frps/server.key \
    -subj "/C=XX/ST=DEFAULT/L=DEFAULT/O=DEFAULT/CN=server.com" \
    -reqexts SAN \
    -config <(cat /etc/pki/tls/frp/my-openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:localhost,IP:${defIP}")) \
    -out /etc/pki/tls/frp/frps/server.csr
openssl x509 -req -days 365 -sha256 \
    -in /etc/pki/tls/frp/frps/server.csr -CA /etc/pki/tls/frp/ca/ca.crt -CAkey /etc/pki/tls/frp/ca/ca.key -CAcreateserial \
    -extfile <(printf "subjectAltName=DNS:localhost,IP:${defIP}") \
    -out /etc/pki/tls/frp/frps/server.crt

# 生成客户端证书
echo "====> Generating client key and certificate"
openssl genrsa -out /etc/pki/tls/frp/frpc/client.key 2048
openssl req -new -sha256 -key /etc/pki/tls/frp/frpc/client.key \
    -subj "/C=XX/ST=DEFAULT/L=DEFAULT/O=DEFAULT/CN=client.com" \
    -reqexts SAN \
    -config <(cat /etc/pki/tls/frp/my-openssl.cnf <(printf "\n[SAN]\nsubjectAltName=DNS:localhost"))\
    -out /etc/pki/tls/frp/frpc/client.csr
openssl x509 -req -days 365 -sha256 \
    -in /etc/pki/tls/frp/frpc/client.csr -CA /etc/pki/tls/frp/ca/ca.crt -CAkey /etc/pki/tls/frp/ca/ca.key -CAcreateserial \
    -extfile <(printf "subjectAltName=DNS:localhost") \
    -out /etc/pki/tls/frp/frpc/client.crt

echo "Certificate generation completed."