#!/usr/bin/env bash
arg=$1
echo "$arg.csv loading..."
rm -f "AI-Project/main/data/$arg.csv.zip"
aws s3api get-object --bucket wavecrest-terraform-ops-ew1-ai --key "$arg.csv.zip" "$arg.csv.zip"
unzip -o "$arg.csv.zip"
sed -i '1d' "$arg.csv"
mv "$arg.csv AI-Project/main/data/cdr.csv"
rm -f "$arg.csv.zip"
echo "$arg.csv loaded."