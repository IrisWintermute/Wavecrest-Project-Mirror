#!/usr/bin/env bash
python3.10 flow.py

sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key output_data --body output_data