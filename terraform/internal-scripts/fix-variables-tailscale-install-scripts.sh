#!/bin/bash

MODULE_PATH=internal-modules/tailscale-install-scripts
DESTINATION_FILENAME=variables-tailscale-install-scripts.tf

for file in $(find . -name $DESTINATION_FILENAME | grep -v $MODULE_PATH); do
    cmd="cp $MODULE_PATH/variables.tf $(dirname $file)/$DESTINATION_FILENAME"
    # echo "running [$cmd]"
    $cmd
done

