#!/usr/bin/env bash

aws s3api get-object --bucket wavecrest-terraform-ops-ew1-ai --key $1.csv.zip $1.csv.zip
unzip -o $1.csv.zip
sed -i '1d' $1.csv
mv $1.csv AI-Project/main/data/cdr.csv
rm -f $1.csv.zip