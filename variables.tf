# Variables for configuration
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster"  # ⚠️ REPLACE WITH YOUR ACTUAL CLUSTER NAME
}

variable "namespace" {
  description = "Kubernetes namespace to monitor"
  type        = string
  default     = "test-services"  # Replace with your actual namespace
}

variable "email" {
  description = "Email for alarm notifications"
  type        = string
  default     = "test@gmail.com"
}
