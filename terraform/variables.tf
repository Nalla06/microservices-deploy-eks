# Variables for AWS EKS deployment

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "microservices-deploy-eks"
}

variable "namespace" {
  description = "Kubernetes namespace for deploying the application"
  type        = string
  default     = "default"
}

variable "filepath_manifest" {
  description = "Path to the Kubernetes manifest files"
  type        = string
  default     = "../kubernetes-manifests"
}

variable "elasticache" {
  description = "Set to true to use AWS ElastiCache Redis instead of in-cluster Redis"
  type        = bool
  default     = false
}