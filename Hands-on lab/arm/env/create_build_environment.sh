#!/bin/bash


# Install essentials
sudo apt-get update -y
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get install curl python-software-properties -y
curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
sudo apt-get update -y && sudo apt-get install -y docker-ce nodejs mongodb-clients
sudo apt-get upgrade -y



# Install Angular
npm install -g @angular/cli@~8.3.4

# Remove sudo requirement
sudo usermod -aG docker $USER

# Ensure we own our home
sudo chown -R $USER:$(id -gn $USER) /home/adminfabmedical/.config

docker version
nodejs --version
npm -version
ng version
