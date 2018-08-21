#!/bin/bash
set -e

aws s3 cp $1 s3://proof.travis.builds/$2/$3;
# EXPIRES_AT=`date --date='now + 24 hours'`
# echo -e "\033[1;35mUrl for $3 download (will expire at $EXPIRES_AT):\033[0m";
# aws s3 presign s3://proof.travis.builds/$2/$3 --expires-in 86400;
