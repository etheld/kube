#!/bin/bash

SECRETS_DIR=$PWD/secrets
BINARY=$PWD/binary

$BINARY/cfssl gencert -ca=$SECRETS_DIR/ca.pem \
    -ca-key=$SECRETS_DIR/ca-key.pem \
    -config=$PWD/config/ca-config.json \
    -profile=client $PWD/config/kube-client.json | $BINARY/cfssl_json -bare $SECRETS_DIR/client-$1
