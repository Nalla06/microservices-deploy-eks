# IAM roles for service accounts (IRSA) configuration for AWS EKS

# Create IAM role for Kubernetes service account (frontend service)
module "frontend_irsa_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version   = "~> 5.0"

  create_role = true
  role_name   = "${local.cluster_name}-frontend-sa"
  
  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.namespace}:frontend"]

  role_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]

  depends_on = [
    null_resource.configure_kubectl,
    module.eks
  ]
}

# Create IAM role for Kubernetes service account (cart service)
module "cart_irsa_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version   = "~> 5.0"

  create_role = true
  role_name   = "${local.cluster_name}-cart-sa"
  
  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.namespace}:cart"]

  role_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  ]

  depends_on = [
    null_resource.configure_kubectl,
    module.eks
  ]
}

# Create the ElastiCache policy if needed
resource "aws_iam_policy" "elasticache_access" {
  count = var.elasticache ? 1 : 0
  
  name        = "${local.cluster_name}-elasticache-policy"
  description = "Policy to allow ElastiCache access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "elasticache:DescribeCacheClusters",
          "elasticache:DescribeReplicationGroups"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach the ElastiCache policy to the cart role if needed
resource "aws_iam_role_policy_attachment" "cart_elasticache" {
  count      = var.elasticache ? 1 : 0
  role       = module.cart_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.elasticache_access[0].arn

  depends_on = [
    null_resource.configure_kubectl,
    module.cart_irsa_role,
    aws_iam_policy.elasticache_access
  ]
}

# Create Kubernetes Service Account with AWS role annotation
resource "kubernetes_service_account" "frontend_sa" {
  metadata {
    name      = "frontend"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.frontend_irsa_role.iam_role_arn
    }
  }

  depends_on = [
    null_resource.configure_kubectl,
    module.eks,
    module.frontend_irsa_role
  ]
}

resource "kubernetes_service_account" "cart_sa" {
  metadata {
    name      = "cart"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.cart_irsa_role.iam_role_arn
    }
  }

  depends_on = [
    null_resource.configure_kubectl,
    module.eks,
    module.cart_irsa_role
  ]
}

# Create Kubernetes secret for service account token (frontend)
resource "kubernetes_secret_v1" "frontend_sa_token" {
  metadata {
    name      = "frontend-sa-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.frontend_sa.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [
    null_resource.configure_kubectl,
    kubernetes_service_account.frontend_sa
  ]
}

# Create Kubernetes secret for service account token (cart)
resource "kubernetes_secret_v1" "cart_sa_token" {
  metadata {
    name      = "cart-sa-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.cart_sa.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [
    kubernetes_service_account.cart_sa
  ]
}

# Create Kubernetes cluster role for frontend service
resource "kubernetes_cluster_role" "frontend_role" {
  metadata {
    name = "frontend-role"
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [
    module.eks
  ]
}

# Create Kubernetes role binding for frontend service
resource "kubernetes_cluster_role_binding" "frontend_role_binding" {
  metadata {
    name = "frontend-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.frontend_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.frontend_sa.metadata[0].name
    namespace = var.namespace
  }

  depends_on = [
    kubernetes_cluster_role.frontend_role,
    kubernetes_service_account.frontend_sa
  ]
}

# Create Kubernetes cluster role for cart service
resource "kubernetes_cluster_role" "cart_role" {
  metadata {
    name = "cart-role"
  }

  rule {
    api_groups = [""]
    resources  = ["services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  # Add additional rule for ElastiCache if needed
  dynamic "rule" {
    for_each = var.elasticache ? [1] : []
    content {
      api_groups = [""]
      resources  = ["secrets"]
      verbs      = ["get"]
    }
  }

  depends_on = [
    module.eks
  ]
}

# Create Kubernetes role binding for cart service
resource "kubernetes_cluster_role_binding" "cart_role_binding" {
  metadata {
    name = "cart-role-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.cart_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cart_sa.metadata[0].name
    namespace = var.namespace
  }

  depends_on = [
    kubernetes_cluster_role.cart_role,
    kubernetes_service_account.cart_sa
  ]
}

# Output the service account tokens
output "frontend_service_account_token" {
  description = "Token for frontend service account"
  value       = kubernetes_secret_v1.frontend_sa_token.metadata[0].name
  sensitive   = true
}

output "cart_service_account_token" {
  description = "Token for cart service account"
  value       = kubernetes_secret_v1.cart_sa_token.metadata[0].name
  sensitive   = true
}