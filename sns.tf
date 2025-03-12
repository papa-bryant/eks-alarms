
# Create a new SNS topic for alerts
resource "aws_sns_topic" "pod_resource_alerts" {
  name = "eks-pod-resource-alerts"
}

# Subscribe multiple email addresses to the SNS topic
resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each  = toset(var.alert_emails)
  
  topic_arn = aws_sns_topic.pod_resource_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

# Output all email subscriptions
output "email_subscriptions" {
  description = "All email subscriptions for pod alerts"
  value       = [for subscription in aws_sns_topic_subscription.email_subscriptions : subscription.endpoint]
}
