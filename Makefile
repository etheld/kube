ifeq (${OS},)
    OS = $(shell uname | tr '[A-Z]' '[a-z]')
endif

TERRAFORM_VERSION=0.8.5

recreate-binary:
	rm -rf binary
	mkdir binary

download: recreate-binary download-cfssl download-terraform


download-cfssl:
	curl -o binary/cfssl https://pkg.cfssl.org/R1.2/cfssl_${OS}-amd64
	curl -o binary/cfssl_json https://pkg.cfssl.org/R1.2/cfssljson_${OS}-amd64

download-terraform:
	curl -o terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_amd64.zip
	unzip terraform.zip
	mv terraform binary/

apply:
	./binary/terraform apply

destroy:
	./binary/terraform destroy -force

ssh:
	ssh -o StrictHostKeyChecking=no core@$(shell ./binary/terraform output | awk '{print $$3}' )

again: token apply ssh
