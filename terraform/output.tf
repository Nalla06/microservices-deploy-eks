# Outputs for AWS EKS deployment

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "redis_endpoint" {
  description = "Endpoint of the ElastiCache Redis instance"
  value       = var.elasticache ? aws_elasticache_cluster.redis_cart[0].cache_nodes.0.address : "Not deployed"
}

output "redis_port" {
  description = "Port of the ElastiCache Redis instance"
  value       = var.elasticache ? "6379" : "Not deployed"
}