output "tunnel1_address" {
  value = google_compute_address.vpn_static_ip.address
}

output "tunnel1_preshared_key" {
  value = google_compute_vpn_tunnel.tunnel1.shared_secret
}
