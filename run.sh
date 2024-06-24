#!/usr/bin/env bash
python3 main/flow.py

sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key main/dataoutput_data.txt --body output_data.txt
sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key main/dataoutput_data_vectorised.txt --body output_data_vectorised.txt
sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key main/datasavefig.png --body savefig.png