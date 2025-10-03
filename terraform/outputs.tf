output "lb_ip_address" {
  description = "The IP address of the Load Balancer"
  value       = google_compute_global_address.lb_ip.address 
}