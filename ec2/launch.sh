#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/instances.json"

# 設定ファイルの存在確認
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

# jqの存在確認
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Please install it."
    exit 1
fi

# インスタンス一覧を取得
instance_count=$(jq '.instances | length' "$CONFIG_FILE")

if [ "$instance_count" -eq 0 ]; then
    echo "Error: No instances defined in $CONFIG_FILE"
    exit 1
fi

# インスタンス一覧を表示
echo "Select an instance to launch:"
echo ""
for i in $(seq 0 $((instance_count - 1))); do
    name=$(jq -r ".instances[$i].name" "$CONFIG_FILE")
    instance_type=$(jq -r ".instances[$i].instance_type" "$CONFIG_FILE")
    ami=$(jq -r ".instances[$i].ami" "$CONFIG_FILE")
    price=$(bash "$SCRIPT_DIR/get-price.sh" "$instance_type" 2>/dev/null || echo "N/A")
    echo "  $((i + 1)). $name (type: $instance_type, ami: $ami, price: \$$price/hr)"
done
echo ""

# ユーザー入力
read -p "Enter number (1-$instance_count): " selection

# 入力検証
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt "$instance_count" ]; then
    echo "Error: Invalid selection"
    exit 1
fi

index=$((selection - 1))

# 選択されたインスタンスの設定を取得
name=$(jq -r ".instances[$index].name" "$CONFIG_FILE")
ami=$(jq -r ".instances[$index].ami" "$CONFIG_FILE")
instance_type=$(jq -r ".instances[$index].instance_type" "$CONFIG_FILE")
key_name=$(jq -r ".instances[$index].key_name" "$CONFIG_FILE")
security_group_ids=$(jq -r ".instances[$index].security_group_ids | join(\",\")" "$CONFIG_FILE")
subnet_id=$(jq -r ".instances[$index].subnet_id" "$CONFIG_FILE")
user_data_file=$(jq -r ".instances[$index].user_data_file" "$CONFIG_FILE")
volume_size=$(jq -r ".instances[$index].volume_size" "$CONFIG_FILE")

echo ""
echo "Launching instance: $name"

# user-dataファイルのパス
user_data_path="$SCRIPT_DIR/$user_data_file"
if [ ! -f "$user_data_path" ]; then
    echo "Error: User data file not found: $user_data_path"
    exit 1
fi

# AMIからルートデバイス名を取得
root_device_name=$(aws ec2 describe-images \
    --image-ids "$ami" \
    --query 'Images[0].RootDeviceName' \
    --output text)

# EC2インスタンスを起動
instance_id=$(aws ec2 run-instances \
    --image-id "$ami" \
    --instance-type "$instance_type" \
    --key-name "$key_name" \
    --security-group-ids $security_group_ids \
    --subnet-id "$subnet_id" \
    --user-data "file://$user_data_path" \
    --block-device-mappings "DeviceName=$root_device_name,Ebs={VolumeSize=$volume_size}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$name}]" \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance launched: $instance_id"

# パブリックIPを取得（割り当てられるまで待機）
echo "Waiting for public IP..."
aws ec2 wait instance-running --instance-ids "$instance_id"

public_ip=$(aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo ""
echo "Instance is running!"
echo "  Instance ID: $instance_id"
echo "  Public IP: $public_ip"
