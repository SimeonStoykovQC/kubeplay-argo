#!/bin/bash

set -eox pipefail

kubectl() {
    minikube kubectl -- "$@"
}

wait-for-it() {
    deployment=$1

    while [[ "$(kubectl rollout status deployment/$deployment)" != "deployment \"$deployment\" successfully rolled out" ]]; do
        sleep 1
    done
}


update-rolling() {
    # Start the rolling update (assuming you have kubectl configured)
    helm upgrade --install my-release /home/ec2-user/kubeplay-helm \
        --set redeployApplication=$(shuf -i 1000-9999 -n 1) --set redeployRouter=$(shuf -i 1000-9999 -n 1)  # TODO - doesnt work from python, not sure why

    # Monitor the rollout status

    wait-for-it "kubeplay-router-deployment"

    for ((i = 0; i < 3; i++)); do
        wait-for-it "kubeplay-application-$i-deployment"
    done
}


update-blue-green () {
    current=$1
    new=$2

    helm upgrade --install my-release-$new /home/ec2-user/kubeplay-helm/ --set release=$new \
        --set redeployApplication=$(shuf -i 1000-9999 -n 1) --set redeployRouter=$(shuf -i 1000-9999 -n 1) 
    
    wait-for-it "kubeplay-router-deployment-$new"
    for ((i = 0; i < 3; i++)); do
        wait-for-it "kubeplay-application-$i-deployment-$new"
    done

    sed "s/{{ \.Values\.prodTrafficRelease }}/$new/g" router-service.yaml | kubectl apply -f -

    helm delete my-release-$current
}


export CONDA_PREFIX=/home/ec2-user/miniforge3/envs/prep
python ./prep-values.py $1

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

# update-rolling TODO needs fixing
update-blue-green $2 $3

sleep 5

# Stop the attack
kill -SIGINT $ATTACK_PID

# Generate the report
vegeta report -type=text $OUTPUT_FILE

# Clean up temporary files
rm $TEMP_TARGET_FILE

