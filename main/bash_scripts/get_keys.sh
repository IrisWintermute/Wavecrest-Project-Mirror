#!/usr/bin/env bash

touch main/data/cache.txt
chmod +rw main/data/cache.txt
aws s3api list-objects --bucket wavecrest-terraform-ops-ew1-ai --prefix exp_odine --query 'Contents[].{Key: Key}' > main/data/cache.txt