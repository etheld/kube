/*data "template_file" "master" {
  template = "${file("conf/master.yml")}"

  vars {
    etcd_discovery_url    = "${var.etcd_discovery_url}"
    kubernetes_version    = "${var.kubernetes_version}"
    kubectl_version       = "${var.kubectl_version}"
    dns_service_ip        = "${var.dns_service_ip}"
    kubernetes_service_ip = "${var.kubernetes_service_ip}"
    service_ip_range      = "${var.service_ip_range}"
    pod_network           = "${var.pod_network}"
  }
}*/

/*data "template_file" "node" {
  template = "${file("conf/node.conf")}"

  vars {
    etcd_discovery_url    = "${var.etcd_discovery_url}"
    kubernetes_version    = "${var.kubernetes_version}"
    dns_service_ip        = "${var.dns_service_ip}"
    kubernetes_service_ip = "${var.kubernetes_service_ip}"
    service_ip_range      = "${var.service_ip_range}"
    pod_network           = "${var.pod_network}"
    master_ip             = "${digitalocean_droplet.master.ipv4_address_private}"
  }
}

*/

resource "digitalocean_ssh_key" "dodemo" {
  name       = "DO Demo Key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

resource "digitalocean_droplet" "k8s_master" {
  image              = "coreos-beta"
  name               = "k8s-master"
  region             = "nyc3"
  size               = "2gb"
  private_networking = true
  ssh_keys           = ["${digitalocean_ssh_key.dodemo.id}"]
  user_data          = "${data.template_file.etcd-k8s-master.rendered}"
   # Generate the Certificate Authority
    provisioner "local-exec" {
        command = "$PWD/scripts/generate_ca.sh"
    }

    # Generate k8s-etcd server certificate
    provisioner "local-exec" {
        command = "$PWD/scripts/generate_server.sh k8s_etcd ${digitalocean_droplet.k8s_master.ipv4_address_private}"
    }

    # Generate k8s_master server certificate
    provisioner "local-exec" {
        command = "$PWD/scripts/generate_server.sh k8s_master '${digitalocean_droplet.k8s_master.ipv4_address},${digitalocean_droplet.k8s_master.ipv4_address_private},10.3.0.1,kubernetes.default,kubernetes'"
    }

    # Provision k8s_etcd server certificate
    provisioner "file" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }
      source = "./secrets/ca.pem"
      destination = "/home/core/ca.pem"
    }

    provisioner "file" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }
      source = "./secrets/k8s_etcd.pem"
      destination = "/home/core/etcd.pem"
    }

    provisioner "file" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }
      source = "./secrets/k8s_etcd-key.pem"
      destination = "/home/core/etcd-key.pem"
    }

    provisioner "file" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }
      source = "./secrets/k8s_master.pem"
      destination = "/home/core/apiserver.pem"
    }
    provisioner "file" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }
      source = "./secrets/k8s_master-key.pem"
      destination = "/home/core/apiserver-key.pem"
    }

    # Generate k8s_master client certificate
    provisioner "local-exec" { command = "$PWD/scripts/generate_client.sh k8s_master" }

    # Provision k8s_master client certificate
    provisioner "file" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }
      source = "./secrets/client-k8s_master.pem"
      destination = "/home/core/client.pem"
    }

    provisioner "file" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }
      source = "./secrets/client-k8s_master-key.pem"
      destination = "/home/core/client-key.pem"
    }

    # TODO: figure out etcd2 user and chown, chmod key.pem files
    provisioner "remote-exec" {
      connection {
         user = "core"
         private_key = "${file("~/.ssh/id_rsa")}"
      }

      inline = [
          "sudo mkdir -p /etc/kubernetes/ssl",
          "sudo cp /home/core/{etcd,etcd-key,ca,apiserver,apiserver-key,client,client-key}.pem /etc/kubernetes/ssl/.",

          "sudo mkdir -p /etc/ssl/etcd",
          "sudo cp /home/core/{ca,client,client-key}.pem /etc/ssl/etcd/.",

          "sudo systemctl start etcd2",
          "sudo systemctl enable etcd2",

          "sudo systemctl daemon-reload",
          "curl --cacert /etc/kubernetes/ssl/ca.pem --cert /etc/kubernetes/ssl/client.pem --key /etc/kubernetes/ssl/client-key.pem -X PUT -d 'value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}' https://${digitalocean_droplet.k8s_master.ipv4_address_private}:2379/v2/keys/coreos.com/network/config",
          "sudo systemctl start flanneld",
          "sudo systemctl enable flanneld",
          "sudo systemctl start kubelet",
          "sudo systemctl enable kubelet",
          "until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:8080); do printf '.'; sleep 5; done",
          "curl -XPOST -H 'Content-type: application/json' -d'{\"apiVersion\":\"v1\",\"kind\":\"Namespace\",\"metadata\":{\"name\":\"kube-system\"}}' http://127.0.0.1:8080/api/v1/namespaces"
      ]
    }
}


data "template_file" "etcd-k8s-master" {
    template = "${file("user-data/00-etcd-k8s-master.yml")}"
    vars {
        DNS_SERVICE_IP = "10.3.0.10"
        POD_NETWORK = "10.2.0.0/16"
        SERVICE_IP_RANGE = "10.3.0.0/24"
        HYPERCUBE_VERSION = "${var.kubernetes_version}"
    }
}




/*variable "node_size_config" {
  default = ["2gb", "2gb", "2gb", "2gb"]
}*/

/*resource "digitalocean_droplet" "node" {
  image              = "coreos-beta"
  name               = "node-${count.index}"
  region             = "lon1"
  size               = "${element(var.node_size_config, count.index)}"
  private_networking = true
  ssh_keys           = ["${digitalocean_ssh_key.dodemo.id}"]
  user_data          = "${data.template_file.node.rendered}"

  # cannot copy files from one host to another, so we use a local command to generate the cert on master and copy it over to the worker
  provisioner "local-exec" {
    command = "${var.local_bash_shell_location} copy-keys.sh ${var.asset_path} ${digitalocean_droplet.master.ipv4_address} ${self.ipv4_address} ${self.name} ${self.ipv4_address_private}"
  }

  count = 3
}*/
