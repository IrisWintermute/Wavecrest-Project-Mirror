#!/usr/bin/env bash#!/usr/bin/env bash

touch cache.txt
chmod +rw cache.txt
aws s3api list-objects --bucket wavecrest-terraform-ops-ew1-ai --prefix exp_odine --query 'Contents[].{Key: Key}' > cache.txt