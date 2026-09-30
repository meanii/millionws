#!/usr/bin/env bash
# Emergency stop: terminate every millionws benchmark instance in a region.
# Usage: scripts/kill-bench.sh [region]   (default us-east-1)
# The VPC and IAM pieces are free; remove them with `tofu destroy`.
set -euo pipefail
region=${1:-us-east-1}
ids=$(aws ec2 describe-instances --region "$region" \
  --filters Name=tag:Project,Values=millionws-bench \
            Name=instance-state-name,Values=pending,running,stopping,stopped \
  --query 'Reservations[].Instances[].InstanceId' --output text)
if [ -z "$ids" ]; then
  echo "no millionws-bench instances in $region"
  exit 0
fi
echo "terminating in $region: $ids"
# shellcheck disable=SC2086
aws ec2 terminate-instances --region "$region" --instance-ids $ids \
  --query 'TerminatingInstances[].[InstanceId,CurrentState.Name]' --output text
