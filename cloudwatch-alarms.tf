# Required Terraform providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# External data source to execute script and get file path
data "external" "kubernetes_services_file" {
  program = ["bash", "${path.module}/scripts/get_services.sh", var.cluster_name, var.namespace]
}

# Read the file produced by the script
data "local_file" "kubernetes_services" {
  filename = data.external.kubernetes_services_file.result.file_path
  depends_on = [data.external.kubernetes_services_file]
}

# Locals for service discovery and alarm configuration
locals {
  # Parse the JSON from the file
  services_data = jsondecode(data.local_file.kubernetes_services.content)
  error_message = local.services_data.error
  services = local.services_data.services
  
  # Default to a fallback service if none discovered
  actual_services = length(local.services) > 0 ? local.services : ["default-service"]
  
  # Define metrics to monitor
  metrics = {
    "memory" = {
      metric_name      = "pod_memory_utilization_over_pod_limit"
      alarm_name_prefix = "pod-memory-high"
      description      = "Pod memory utilization exceeding 80% of its limit"
    },
    "cpu" = {
      metric_name      = "pod_cpu_utilization_over_pod_limit"
      alarm_name_prefix = "pod-cpu-high"
      description      = "Pod CPU utilization exceeding 80% of its limit"
    }
  }
  
  # Create static mapping for all service-metric combinations
  service_metric_keys = {
    for pair in flatten([
      for service in local.actual_services : [
        for metric_key, metric in local.metrics : {
          key           = "${service}-${metric_key}"
          service       = service
          metric_key    = metric_key
          metric_name   = metric.metric_name
          alarm_prefix  = metric.alarm_name_prefix
          description   = metric.description
        }
      ]
    ]) : pair.key => pair
  }
}

# Create a new SNS topic for alerts
resource "aws_sns_topic" "pod_resource_alerts" {
  name = "eks-pod-resource-alerts"
}

# Subscribe an email address to the SNS topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.pod_resource_alerts.arn
  protocol  = "email"
  endpoint  = var.email
}

# Create all alarms using for_each
resource "aws_cloudwatch_metric_alarm" "pod_resource_alarms" {
  for_each = local.service_metric_keys
  
  alarm_name          = "${each.value.service}-${each.value.alarm_prefix}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 80
  alarm_description   = "This metric monitors ${each.value.service} ${each.value.description}"
  
  metric_query {
    id          = "m1"
    return_data = true
    
    metric {
      metric_name = each.value.metric_name
      namespace   = "ContainerInsights"
      period      = 60
      stat        = "Average"
      
      dimensions = {
        ClusterName = var.cluster_name
        Namespace   = var.namespace
        Service     = each.value.service
      }
    }
  }
  
  alarm_actions = [aws_sns_topic.pod_resource_alerts.arn]
  ok_actions    = [aws_sns_topic.pod_resource_alerts.arn]
}

# Outputs for reference
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for EKS pod alerts"
  value       = aws_sns_topic.pod_resource_alerts.arn
}

output "discovery_error" {
  description = "Error message from service discovery (if any)"
  value       = local.error_message
}

output "discovered_services" {
  description = "Services discovered in the namespace"
  value       = local.services
}

output "monitored_services" {
  description = "Services being monitored (including fallbacks if discovery failed)"
  value       = local.actual_services
}

output "file_path" {
  description = "Path to the services file"
  value       = data.external.kubernetes_services_file.result.file_path
}

output "email_subscription" {
  description = "The email subscription for pod alerts"
  value       = aws_sns_topic_subscription.email_subscription.endpoint
}

output "alarm_names" {
  description = "Names of all created CloudWatch alarms"
  value       = [for k, v in aws_cloudwatch_metric_alarm.pod_resource_alarms : v.alarm_name]
}

output "dashboard_url" {
  description = "URL to access the CloudWatch dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.eks_service_dashboard.dashboard_name}"
}