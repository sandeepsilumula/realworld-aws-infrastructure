output "load_balancer_dns_name" {
  description = "The absolute public access link for your live application infrastructure deployment."
  value       = module.alb.dns_name  # <--- FIXED HERE (dns_name)
}