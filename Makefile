create-ca:
	./binary/cfssl gencert -initca config/ca-csr.json | ./binary/cfssljson -bare ca

create-kube: create-ca
	./binary/cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=config/ca-config.json \
		-profile=server \
		config/kube-apiserver-server-csr.json | ./binary/cfssljson -bare kube-apiserver-server

download-cfssl:
	curl -o binary/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
	curl -o binary/cfssl_json https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

download-terraform:
	curl -o terraform.zip https://releases.hashicorp.com/terraform/0.8.5/terraform_0.8.5_linux_amd64.zip
	unzip terraform.zip
	mv terraform binary/

apply:
	./binary/terraform apply
