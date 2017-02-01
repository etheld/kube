#!/bin/bash

SECRETS_DIR=$PWD/secrets
BINARY=$PWD/binary

template=$(cat $PWD/config/kube-apiserver-csr.json )

echo $template | $BINARY/cfssl gencert -ca=$SECRETS_DIR/ca.pem \
    -ca-key=$SECRETS_DIR/ca-key.pem \
    -config=$PWD/config/ca-config.json \
    -profile=server \
    -hostname="$2" - | $BINARY/cfssl_json -bare $SECRETS_DIR/$1
