# Dashboard with combined CPU and memory metrics per service
resource "aws_cloudwatch_dashboard" "eks_service_dashboard" {
  dashboard_name = "EKS-Service-Metrics"
  
  dashboard_body = jsonencode({
    widgets = [
      for i, service in local.actual_services : {
        type   = "metric"
        x      = i % 2 * 12
        y      = floor(i / 2) * 8
        width  = 12
        height = 8
        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization_over_pod_limit", "ClusterName", var.cluster_name, "Namespace", var.namespace, "Service", service],
            ["ContainerInsights", "pod_memory_utilization_over_pod_limit", "ClusterName", var.cluster_name, "Namespace", var.namespace, "Service", service]
          ]
          period = 60
          stat   = "Average"
          region = var.region
          title  = "${service} - Resource Utilization (% of limit)"
          view   = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min = 0
              max = 100
              label = "Utilization %"
              showUnits = false
            }
          }
          annotations = {
            horizontal = [
              {
                value = 80
                label = "Alarm Threshold (80%)"
                color = "#ff0000"
              }
            ]
          }
          legend = {
            position = "right"
          }
        }
      }
    ]
  })
}