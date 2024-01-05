#!/bin/bash

cmd="terraform fmt -recursive $@"
# echo "running [$cmd]"
$cmd
