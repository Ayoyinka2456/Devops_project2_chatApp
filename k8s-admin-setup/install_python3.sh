#!/bin/bash

# Update system packages
sudo dnf update -y

# Install Python 3 (Amazon Linux 2023/2024 comes with Python 3.9+)
sudo dnf install -y python3

# Ensure pip is installed
sudo dnf install -y python3-pip

# Upgrade pip
pip3 install --upgrade pip

# Install Jinja2 via pip
pip3 install Jinja2

# Verify installations
python3 --version
pip3 show Jinja2
