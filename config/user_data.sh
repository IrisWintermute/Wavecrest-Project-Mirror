#!/bin/bash
sudo apt update
sudo apt install python3
sudo apt install -y python3-pip -y
sudo apt install git

git remote add ai-project https://github.com/Wavecrest/AI-Project
git fetch ai-project

