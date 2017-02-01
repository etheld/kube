#!/bin/bash

SECRETS_DIR=$PWD/secrets
BINARY=$PWD/binary

$BINARY/cfssl gencert -initca $PWD/config/ca-csr.json | $BINARY/cfssl_json -bare $SECRETS_DIR/ca -
