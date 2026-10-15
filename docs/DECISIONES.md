# Decisiones, limitaciones y mejoras — THE ODYSSEY

## Decisiones
- AWS EC2 + Docker (no ECS) para demo en 1 día, costo mínimo y rollback con script legible por el jurado.
- Flask minimalista: 2 endpoints exigidos + `/`. Modo fallo con `SHOULD_FAIL` para demo controlada.
- Nginx :80 -> :8080 para URL pública simple sin ALB (ahorra costo).
- Dos workflows separados por `paths:` para cumplir condición 4 (app vs infra).
- OIDC preferido sobre keys (condición 8). SSH limitado a ADMIN_IP (condición taller).
- Tags obligatorios en todo + t3.micro + 8GB cifrado (condiciones 10 y 11).
- Trivy gatea ANTES del push; health/functional gatean DESPUÉS del deploy. Separación intencional.

## Limitaciones
- 1 AZ, sin ALB/autoscaling (fuera de alcance y costo).
- SSH con key en secret (mejorable a SSM Session Manager sin puerto 22).
- Backend Terraform local (mejorable a S3+Dynamo para equipo).
- Sin HTTPS (mejorable con ACM+ALB o Front Door si fuera Azure).

## Mejoras futuras
- SSM en vez de SSH, ALB + target group health checks, ECR lifecycle policy, promoción canary, alertas CloudWatch.
