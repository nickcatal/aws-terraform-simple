output "route53_public_nameserver" {
  value = aws_route53_zone.public.name_servers
}
