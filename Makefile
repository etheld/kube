create-ca:
	./binary/cfssl gencert -initca config/ca-csr.json | ./binary/cfssl_json -bare secrets/ca

create-kube-api:
	./binary/cfssl gencert \
		-ca=secrets/ca.pem \
		-ca-key=secrets/ca-key.pem \
		-config=config/ca-config.json \
		-profile=server \
		config/kube-apiserver-server-csr.json | ./binary/cfssl_json -bare kube-apiserver

ssl: create-ca create-kube-api

download-cfssl:
	curl -o binary/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
	curl -o binary/cfssl_json https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

download-terraform:
	curl -o terraform.zip https://releases.hashicorp.com/terraform/0.8.5/terraform_0.8.5_linux_amd64.zip
	unzip terraform.zip
	mv terraform binary/

clean-binary:
	rm -rf binary
mkdir-binary:
	mkdir binary
download: clean-binary mkdir-binary download-terraform download-cfssl

apply:
	./binary/terraform apply

destroy:
	./binary/terraform destroy -force

token:
	grep -v etcd terraform.tfvars > terraform.tfvars_new
	mv terraform.tfvars_new terraform.tfvars
	echo "etcd_discovery_url=\"`curl https://discovery.etcd.io/new?size=1`\"" >> terraform.tfvars

ssh:
	ssh -o StrictHostKeyChecking=no core@$(shell ./binary/terraform output | awk '{print $$3}' )

again: destroy token apply ssh
