#!/usr/bin/env bash

python3 flow.py

sudo aws s3api put-object --bucket wavecrest-terraform-ops --key output_data --body output_data