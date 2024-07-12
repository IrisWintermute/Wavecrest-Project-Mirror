#!/usr/bin/env bash
git pull
python3 main/flow.py

#sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key main/data/output_data.txt --body main/data/output_data.txt
#sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key main/data/output_data_vectorised.txt --body main/data/output_data_vectorised.txt
# sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key main/data/savefig.png --body main/data/savefig.png
sudo aws s3api put-object --bucket wavecrest-terraform-ops-ew1-ai --key main/data/savefig_batch --body main/data/savefig_batch