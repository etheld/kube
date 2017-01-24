create-ca:
	./cfssl gencert -initca config/ca-csr.json | ./cfssljson -bare ca

create-kube: create-ca
	./cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=config/ca-config.json \
		-profile=server \
		config/kube-apiserver-server-csr.json | ./cfssljson -bare kube-apiserver-server
