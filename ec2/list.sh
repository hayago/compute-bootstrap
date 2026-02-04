#!/bin/bash
set -eu

# jqの存在確認
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Please install it."
    exit 1
fi

# インスタンス一覧を取得
instances=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped,pending,stopping" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value|[0],InstanceType:InstanceType,PublicIpAddress:PublicIpAddress,State:State.Name}' \
    --output json)

instance_count=$(echo "$instances" | jq 'length')

if [ "$instance_count" -eq 0 ]; then
    echo "No instances found."
    exit 0
fi

echo "EC2 Instances:"
echo ""
for i in $(seq 0 $((instance_count - 1))); do
    instance_id=$(echo "$instances" | jq -r ".[$i].InstanceId")
    name=$(echo "$instances" | jq -r ".[$i].Name // \"(no name)\"")
    instance_type=$(echo "$instances" | jq -r ".[$i].InstanceType")
    public_ip=$(echo "$instances" | jq -r ".[$i].PublicIpAddress // \"(no public ip)\"")
    state=$(echo "$instances" | jq -r ".[$i].State")
    echo "  $name"
    echo "    ID: $instance_id"
    echo "    Type: $instance_type"
    echo "    IP: $public_ip"
    echo "    State: $state"
    echo ""
done
