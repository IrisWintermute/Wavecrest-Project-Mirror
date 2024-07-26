#!/usr/bin/env bash
arg=$1
echo "$arg.csv loading..."
aws s3api get-object --bucket wavecrest-terraform-ops-ew1-ai --key "$arg.csv.zip" "$arg.csv.zip"
unzip -o "$arg.csv.zip"
sed -i '1d' "$arg.csv"
rm -f "AI-Project/main/data/cdr.csv"
mv "$arg.csv" AI-Project/main/data/cdr.csv
rm -f "$arg.csv.zip"
rm -f $(find | grep "sed")
echo "$arg.csv loaded."