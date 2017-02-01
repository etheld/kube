output "k8s_master" {
  value = "${digitalocean_droplet.k8s_master.ipv4_address}"
}
