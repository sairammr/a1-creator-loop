#!/usr/bin/env bash
# Quick status check for OCI A1 free-tier instance.
# Reads from ~/.oci/config (DEFAULT profile).

set -e

COMPARTMENT="ocid1.tenancy.oc1..aaaaaaaabdqwyhgtxgscos442qd3xjit2zlf2llz36imayumdowaf4riy43q"
SHAPE="VM.Standard.A1.Flex"

echo "Querying OCI for A1 instances in ap-mumbai-1..."
echo ""

OUT=$(oci compute instance list \
  --compartment-id "$COMPARTMENT" \
  --all \
  --query "data[?shape=='$SHAPE'].{Name:\"display-name\",State:\"lifecycle-state\",ID:id}" \
  --output json)

COUNT=$(echo "$OUT" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')

if [ "$COUNT" = "0" ]; then
  echo "❌ No A1 instances yet. The workflow is still retrying."
  echo ""
  echo "Last 3 workflow runs:"
  gh run list -R Philotheephilix/a1-creator-loop --workflow=oci-instance-retry.yml --limit 3 2>/dev/null || \
    echo "  (gh CLI not configured — visit https://github.com/Philotheephilix/a1-creator-loop/actions)"
  exit 0
fi

echo "✅ Found $COUNT A1 instance(s):"
echo "$OUT" | python3 -m json.tool
echo ""

# For any RUNNING instance, fetch and print public IP + SSH command
RUNNING_IDS=$(echo "$OUT" | python3 -c 'import json,sys; print("\n".join(i["ID"] for i in json.load(sys.stdin) if i["State"]=="RUNNING"))')
if [ -n "$RUNNING_IDS" ]; then
  while IFS= read -r ID; do
    IP=$(oci compute instance list-vnics --instance-id "$ID" --query 'data[0]."public-ip"' --raw-output 2>/dev/null)
    echo "Instance: $ID"
    echo "  Public IP: $IP"
    echo "  SSH:       ssh -i ~/.ssh/oci_a1 ubuntu@$IP"
    echo ""
  done <<< "$RUNNING_IDS"
fi
