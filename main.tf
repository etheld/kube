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
      user        = "core"
      private_key = "${file("~/.ssh/id_rsa")}"
    }

    source      = "./secrets/ca.pem"
    destination = "/home/core/ca.pem"
  }

  provisioner "file" {
    connection {
      user        = "core"
      private_key = "${file("~/.ssh/id_rsa")}"
    }

    source      = "./secrets/k8s_etcd.pem"
    destination = "/home/core/etcd.pem"
  }

  provisioner "file" {
    connection {
      user        = "core"
      private_key = "${file("~/.ssh/id_rsa")}"
    }

    source      = "./secrets/k8s_etcd-key.pem"
    destination = "/home/core/etcd-key.pem"
  }

  provisioner "file" {
    connection {
      user        = "core"
      private_key = "${file("~/.ssh/id_rsa")}"
    }

    source      = "./secrets/k8s_master.pem"
    destination = "/home/core/apiserver.pem"
  }

  provisioner "file" {
    connection {
      user        = "core"
      private_key = "${file("~/.ssh/id_rsa")}"
    }

    source      = "./secrets/k8s_master-key.pem"
    destination = "/home/core/apiserver-key.pem"
  }

  # Generate k8s_master client certificate
  provisioner "local-exec" {
    command = "$PWD/scripts/generate_client.sh k8s_master"
  }

  # Provision k8s_master client certificate
  provisioner "file" {
    connection {
      user        = "core"
      private_key = "${file("~/.ssh/id_rsa")}"
    }

    source      = "./secrets/client-k8s_master.pem"
    destination = "/home/core/client.pem"
  }

  provisioner "file" {
    connection {
      user        = "core"
      private_key = "${file("~/.ssh/id_rsa")}"
    }

    source      = "./secrets/client-k8s_master-key.pem"
    destination = "/home/core/client-key.pem"
  }

  # TODO: figure out etcd2 user and chown, chmod key.pem files
  provisioner "remote-exec" {
    connection {
      user        = "core"
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
      "curl -XPOST -H 'Content-type: application/json' -d'{\"apiVersion\":\"v1\",\"kind\":\"Namespace\",\"metadata\":{\"name\":\"kube-system\"}}' http://127.0.0.1:8080/api/v1/namespaces",
    ]
  }
}

data "template_file" "etcd-k8s-master" {
  template = "${file("user-data/00-etcd-k8s-master.yml")}"

  vars {
    DNS_SERVICE_IP    = "10.3.0.10"
    POD_NETWORK       = "10.2.0.0/16"
    SERVICE_IP_RANGE  = "10.3.0.0/24"
    HYPERCUBE_VERSION = "v1.4.3_coreos.0"
  }
}
