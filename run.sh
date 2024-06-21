#!/usr/bin/env bash
python3 flow.py

sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key output_data.txt --body output_data.txt
sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key output_data_vectorised.txt --body output_data_vectorised.txt
sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key savefig.png --body savefig.png