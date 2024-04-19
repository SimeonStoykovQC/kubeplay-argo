#!/bin/bash

set -eox pipefail

kubectl() {
    minikube kubectl -- "$@"
}

wait-for-argo() {
    APP_NAME=$1

    while [[ "$(argocd app get $APP_NAME -o json | jq -r '.status.health.status')" != "Healthy" ]]; do
        sleep 1
    done
}

update-argo-bg () {
    argocd app sync kubeplay --prune
    wait-for-argo kubeplay
}

export CONDA_PREFIX=/home/ec2-user/miniforge3/envs/prep
python ./prep-values.py $1 $2

git add charts/app/values.yaml
git commit -m "automated benchmark update with args: $1 - $2"
git push
sleep 1

# Define variables
RATE="20"  # Requests per second
OUTPUT_FILE="results.bin"  # Output file for Vegeta results
TEMP_TARGET_FILE="target.tmp"  # Temporary target file for Vegeta

# Create a temporary target file
echo "" > $TEMP_TARGET_FILE
for ((i = 0; i < 12; i++)); do
    echo "GET http://192.168.49.2:30001/get/class${i}" >> "$TEMP_TARGET_FILE"
done

# Start the attack in the background
vegeta attack -targets=$TEMP_TARGET_FILE -rate=$RATE -output=$OUTPUT_FILE > /dev/null &
sleep 1

# Save the PID of the attack
ATTACK_PID=$!

update-argo-bg

sleep 20

# Stop the attack
kill -SIGINT $ATTACK_PID

# Generate the report
vegeta report -type=text $OUTPUT_FILE

# Clean up temporary files
rm $TEMP_TARGET_FILE

