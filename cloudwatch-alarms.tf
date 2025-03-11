
# Create a new SNS topic for alerts
resource "aws_sns_topic" "pod_resource_alerts" {
  name = "eks-pod-resource-alerts"
}

# Subscribe an email address to the SNS topic
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.pod_resource_alerts.arn
  protocol  = "email"
  endpoint  = "bryantkiseu@gmail.com"  # Replace with your actual email address
}

# Locals to define services and metrics to monitor
locals {
  cluster_name = "eks-cluster"
  namespace    = "test-services"
  services     = ["service1", "service2"]
  
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
  
  # Create a flattened list of all service-metric combinations
  monitoring_pairs = flatten([
    for service in local.services : [
      for metric_key, metric in local.metrics : {
        service         = service
        metric_key      = metric_key
        metric_name     = metric.metric_name
        alarm_name      = "${service}-${metric.alarm_name_prefix}"
        description     = "This metric monitors ${service} ${metric.description}"
      }
    ]
  ])
}

# Create all alarms using for_each
resource "aws_cloudwatch_metric_alarm" "pod_resource_alarms" {
  for_each = { for pair in local.monitoring_pairs : "${pair.service}-${pair.metric_key}" => pair }
  
  alarm_name          = each.value.alarm_name
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = each.value.metric_name
  namespace           = "ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = each.value.description
  
  dimensions = {
    ClusterName = local.cluster_name
    Namespace   = local.namespace
    Service     = each.value.service
  }
  
  alarm_actions = [aws_sns_topic.pod_resource_alerts.arn]
  ok_actions    = [aws_sns_topic.pod_resource_alerts.arn]
}

# Dashboard to visualize the metrics
resource "aws_cloudwatch_dashboard" "eks_pod_dashboard" {
  dashboard_name = "EKS-Pod-Metrics"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            for service in local.services : 
              ["ContainerInsights", "pod_memory_utilization_over_pod_limit", "ClusterName", local.cluster_name, "Namespace", local.namespace, "Service", service]
          ]
          period = 60
          stat   = "Average"
          region = "us-east-1"
          title  = "Pod Memory Utilization (% of limit)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            for service in local.services : 
              ["ContainerInsights", "pod_cpu_utilization_over_pod_limit", "ClusterName", local.cluster_name, "Namespace", local.namespace, "Service", service]
          ]
          period = 60
          stat   = "Average"
          region = "us-east-1"
          title  = "Pod CPU Utilization (% of limit)"
        }
      }
    ]
  })
}

# Outputs for reference
output "sns_topic_arn" {
  description = "The ARN of the SNS topic for EKS pod alerts"
  value       = aws_sns_topic.pod_resource_alerts.arn
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
  value       = "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=${aws_cloudwatch_dashboard.eks_pod_dashboard.dashboard_name}"
}
