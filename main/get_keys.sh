#!/usr/bin/env bash

$(aws s3api list-objects --bucket wavecrest-terraform-ops-ew1-ai --prefix exp_odine --query 'Contents[].{Key: Key}') > cache.txt