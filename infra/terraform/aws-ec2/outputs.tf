output "server_ssh" {
  value = "ssh ec2-user@${local.server_public_ip}"
}

output "grafana" {
  # Grafana listens on 3000, allowed from my_ip only (see the security group).
  value = "grafana http://${local.server_public_ip}:3000 (username admin, password admin)"
}

output "prometheus" {
  value = "prometheus http://${local.server_public_ip}:9090"
}

output "clients_ssh" {
  value = [for ip in local.client_public_ips : "ssh ec2-user@${ip}"]
}

output "target" {
  value = "total target: ${var.client_count * var.conns_per_client} connections (${var.conns_per_client} per client x ${var.client_count} clients, ${var.server_port_count} server ports)"
}
