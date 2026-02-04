#!/bin/bash
set -eu

# jqの存在確認
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Please install it."
    exit 1
fi

# 実行中・停止中のインスタンス一覧を取得
instances=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value|[0],InstanceType:InstanceType,PublicIpAddress:PublicIpAddress,State:State.Name}' \
    --output json)

instance_count=$(echo "$instances" | jq 'length')

if [ "$instance_count" -eq 0 ]; then
    echo "No instances found."
    exit 0
fi

# インスタンス一覧を表示
echo "Select an instance:"
echo ""
for i in $(seq 0 $((instance_count - 1))); do
    instance_id=$(echo "$instances" | jq -r ".[$i].InstanceId")
    name=$(echo "$instances" | jq -r ".[$i].Name // \"(no name)\"")
    instance_type=$(echo "$instances" | jq -r ".[$i].InstanceType")
    public_ip=$(echo "$instances" | jq -r ".[$i].PublicIpAddress // \"(no public ip)\"")
    state=$(echo "$instances" | jq -r ".[$i].State")
    echo "  $((i + 1)). $name ($instance_id, type: $instance_type, ip: $public_ip, state: $state)"
done
echo ""

# インスタンス選択
read -p "Enter number (1-$instance_count): " selection

# 入力検証
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$instance_count" ]; then
    echo "Error: Invalid selection"
    exit 1
fi

index=$((selection - 1))

# 選択されたインスタンスの情報を取得
instance_id=$(echo "$instances" | jq -r ".[$index].InstanceId")
name=$(echo "$instances" | jq -r ".[$index].Name // \"(no name)\"")

# アクション選択
echo ""
echo "Select action for $name ($instance_id):"
echo "  1. Stop instance"
echo "  2. Terminate instance (delete)"
echo ""
read -p "Enter number (1-2): " action

if [ "$action" = "1" ]; then
    echo ""
    echo "Stopping instance: $name ($instance_id)"

    aws ec2 stop-instances --instance-ids "$instance_id" > /dev/null

    echo "Stop request sent. Waiting for instance to stop..."
    aws ec2 wait instance-stopped --instance-ids "$instance_id"

    echo "Instance stopped: $instance_id"
elif [ "$action" = "2" ]; then
    echo ""
    read -p "Are you sure you want to terminate $name ($instance_id)? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi

    echo "Terminating instance: $name ($instance_id)"

    aws ec2 terminate-instances --instance-ids "$instance_id" > /dev/null

    echo "Terminate request sent. Waiting for instance to terminate..."
    aws ec2 wait instance-terminated --instance-ids "$instance_id"

    echo "Instance terminated: $instance_id"
else
    echo "Error: Invalid selection"
    exit 1
fi
