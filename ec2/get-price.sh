#!/bin/bash
set -eu

if [ $# -ne 1 ]; then
    echo "Usage: $0 <instance-type>" >&2
    exit 1
fi

INSTANCE_TYPE="$1"

# 現在のリージョンを取得
REGION=$(aws configure get region || echo "us-east-1")

# リージョンコード→ロケーション名のマッピング
declare -A REGION_MAP=(
    ["us-east-1"]="US East (N. Virginia)"
    ["us-east-2"]="US East (Ohio)"
    ["us-west-1"]="US West (N. California)"
    ["us-west-2"]="US West (Oregon)"
    ["ap-northeast-1"]="Asia Pacific (Tokyo)"
    ["ap-northeast-2"]="Asia Pacific (Seoul)"
    ["ap-northeast-3"]="Asia Pacific (Osaka)"
    ["ap-southeast-1"]="Asia Pacific (Singapore)"
    ["ap-southeast-2"]="Asia Pacific (Sydney)"
    ["ap-south-1"]="Asia Pacific (Mumbai)"
    ["eu-west-1"]="EU (Ireland)"
    ["eu-west-2"]="EU (London)"
    ["eu-west-3"]="EU (Paris)"
    ["eu-central-1"]="EU (Frankfurt)"
    ["eu-north-1"]="EU (Stockholm)"
    ["sa-east-1"]="South America (Sao Paulo)"
    ["ca-central-1"]="Canada (Central)"
)

LOCATION="${REGION_MAP[$REGION]:-}"
if [ -z "$LOCATION" ]; then
    echo "Unknown region: $REGION" >&2
    exit 1
fi

# Pricing APIでオンデマンド価格を取得（us-east-1固定）
result=$(aws pricing get-products \
    --region us-east-1 \
    --service-code AmazonEC2 \
    --filters \
        "Type=TERM_MATCH,Field=instanceType,Value=$INSTANCE_TYPE" \
        "Type=TERM_MATCH,Field=location,Value=$LOCATION" \
        "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
        "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
        "Type=TERM_MATCH,Field=tenancy,Value=Shared" \
        "Type=TERM_MATCH,Field=capacitystatus,Value=Used" \
    --query 'PriceList[0]' \
    --output text)

if [ -z "$result" ] || [ "$result" = "None" ]; then
    echo "N/A"
    exit 0
fi

# 価格を抽出
echo "$result" | jq -r '
    .terms.OnDemand | to_entries[0].value |
    .priceDimensions | to_entries[0].value |
    .pricePerUnit.USD
' | awk '{printf "%.4f\n", $1}'
