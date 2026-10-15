output "public_ip" {
  description = "IP publica de la app"
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "URL publica de la aplicacion"
  value       = "http://${aws_instance.app.public_ip}/health"
}

output "ecr_url" {
  description = "URL del repositorio ECR"
  value       = aws_ecr_repository.app.repository_url
}
