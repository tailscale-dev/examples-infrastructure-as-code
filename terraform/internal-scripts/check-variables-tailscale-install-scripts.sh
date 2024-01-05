#!/bin/bash
#
# This scripts compares the variables file in $MODULE_VARIABLES_PATH to all
# instances of $EXAMPLE_VARIABLES_FILENAME to ensure they are identical.
#

function get_md5() {
    MD5_COMMAND='md5sum --tag'
    if [ $(uname) == "Darwin" ]; then
        MD5_COMMAND='md5'
    fi

    $MD5_COMMAND $1 | cut -d' ' -f4
}

STARTING_DIRECTORY=$1
if [ "$STARTING_DIRECTORY" == "" ]; then
    echo "Must pass the directory to start in as the first argument."
    exit 1
fi

MODULE_VARIABLES_PATH="$STARTING_DIRECTORY/internal-modules/tailscale-install-scripts/variables.tf"
MODULE_VARIABLES_MD5=$(get_md5 $MODULE_VARIABLES_PATH)
echo "md5 of [$MODULE_VARIABLES_PATH] is [$MODULE_VARIABLES_MD5]"

EXAMPLE_VARIABLES_FILENAME=variables-tailscale-install-scripts.tf

ERRORS_FOUND=0

for file in $(find . -type f -name $EXAMPLE_VARIABLES_FILENAME)
do
    FILE_MD5=$(get_md5 $file)

    if [ "$FILE_MD5" != "$MODULE_VARIABLES_MD5" ]; then 
        echo "File [$file] does not match [$MODULE_VARIABLES_PATH]"
        ERRORS_FOUND=$((ERRORS_FOUND+1))
    fi
done

if [ $ERRORS_FOUND -ne 0 ]; then 
    printf "\n#\n# [$ERRORS_FOUND] ERRORS FOUND\n#\n"
    echo "Found downstream files that do not match [$MODULE_VARIABLES_PATH]."
    echo "Copy [$MODULE_VARIABLES_PATH] to each location of [$EXAMPLE_VARIABLES_FILENAME] to fix."
    exit 1
fi
