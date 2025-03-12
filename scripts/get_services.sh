# Updated script that writes to a file and returns simple JSON
#!/bin/bash
# Script that writes services to a file and returns minimal JSON

# Get cluster name and namespace from args
CLUSTER_NAME=$1
NAMESPACE=$2
OUTPUT_FILE="${3:-/tmp/terraform-eks-services.json}"

# Log directory
LOG_DIR="/tmp"
LOG_FILE="$LOG_DIR/terraform-eks-debug.log"

# Start with empty services array
SERVICES_JSON="[]"
ERROR_MSG=""

echo "Script called with: CLUSTER_NAME=$CLUSTER_NAME NAMESPACE=$NAMESPACE OUTPUT_FILE=$OUTPUT_FILE" > "$LOG_FILE"

# Try to get services if tools are available
if command -v aws &> /dev/null && command -v kubectl &> /dev/null; then
  # Try to update kubeconfig
  aws eks update-kubeconfig --name "$CLUSTER_NAME" --region us-east-1 >> "$LOG_FILE" 2>&1
  
  if [ $? -eq 0 ]; then
    # Get services
    SERVICES=$(kubectl get services -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>> "$LOG_FILE")
    
    if [ $? -eq 0 ] && [ ! -z "$SERVICES" ]; then
      # Build JSON array
      SERVICES_JSON="["
      FIRST=true
      for SVC in $SERVICES; do
        if [ "$FIRST" = true ]; then
          FIRST=false
        else
          SERVICES_JSON="$SERVICES_JSON,"
        fi
        SERVICES_JSON="$SERVICES_JSON\"$SVC\""
      done
      SERVICES_JSON="$SERVICES_JSON]"
    else
      ERROR_MSG="No services found in namespace $NAMESPACE"
    fi
  else
    ERROR_MSG="Could not connect to cluster $CLUSTER_NAME"
  fi
else
  ERROR_MSG="Required tools not installed"
fi

# Write detailed information to the output file
echo "{\"services\": $SERVICES_JSON, \"error\": \"$ERROR_MSG\"}" > "$OUTPUT_FILE"
echo "Wrote services to $OUTPUT_FILE" >> "$LOG_FILE"
echo "Content: $(cat $OUTPUT_FILE)" >> "$LOG_FILE"

# Return only the output file path to Terraform
echo "{\"file_path\":\"$OUTPUT_FILE\"}"