#!/bin/bash

cmd="terraform fmt -check -recursive $@"
# echo "running [$cmd]"
$cmd
