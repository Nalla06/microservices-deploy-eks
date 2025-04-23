# AWS ElastiCache (Redis) configuration

# Security group for ElastiCache
resource "aws_security_group" "redis_sg" {
  name        = "redis-cart-sg"
  description = "Security group for Redis Cart"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound traffic from EKS cluster nodes
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [module.eks.cluster_primary_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  count = var.elasticache ? 1 : 0
}

# Create subnet group for ElastiCache
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-cart-subnet-group"
  subnet_ids = module.vpc.private_subnets

  count = var.elasticache ? 1 : 0
}

# Create ElastiCache Redis instance
resource "aws_elasticache_cluster" "redis_cart" {
  cluster_id           = "redis-cart"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.t3.small"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group[0].name
  security_group_ids   = [aws_security_group.redis_sg[0].id]

  count = var.elasticache ? 1 : 0

  depends_on = [
    aws_elasticache_subnet_group.redis_subnet_group,
    aws_security_group.redis_sg
  ]
}

# Update kustomization.yaml with Redis connection details
resource "null_resource" "kustomization_update" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command     = "sed -i \"s/REDIS_CONNECTION_STRING/${aws_elasticache_cluster.redis_cart[0].cache_nodes.0.address}:6379/g\" ../kustomize/components/memorystore/kustomization.yaml"
  }

  count = var.elasticache ? 1 : 0

  depends_on = [
    aws_elasticache_cluster.redis_cart
  ]
}