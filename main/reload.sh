#!/usr/bin/env bash

aws s3api get-object --bucket wavecrest-terraform-ops-ew1-ai --key exp_odine_u_332_p_1_e_270_20240603084457.csv.zip exp_odine_u_332_p_1_e_270_20240603084457.csv.zip
unzip -o exp_odine_u_332_p_1_e_270_20240603084457.csv.zip
sed -i '1d' exp_odine_u_332_p_1_e_270_20240603084457.csv
mv exp_odine_u_332_p_1_e_270_20240603084457.csv AI-Project/main/data/cdr.csv
rm -f exp_odine_u_332_p_1_e_270_20240603084457.csv.zip