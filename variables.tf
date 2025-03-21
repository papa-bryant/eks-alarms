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

# Variable for multiple email addresses
variable "alert_emails" {
  description = "List of email addresses to receive CloudWatch alarm notifications"
  type        = list(string)
  default     = [
    "first.email@gmail.com", # Replace with your emails
    "second.email@example.com",
    "third.email@example.com"
  ]
}
