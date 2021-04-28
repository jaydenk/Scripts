#!/bin/bash

##############################
##  Jayden Kerr 02/01/2021  ##
##############################
##  Version 0.2 ##
##############################################################
##  Installs Docker CE on CentOS using instructions from    ##
##  https://docs.docker.com/install/linux/docker-ce/centos/ ##
##############################################################

# Instance variables
localIP=$(hostname -I)
RED="\033[0;31m" # Red text
WHITE="\033[1;37m" # White text
NF="\033[0m" # No formatting
NB="\033[21m" # No bold
BOLD="\033[1m" # Bold text
NC="\033[39m" # Default text colour

# Welcome, we're going to install Docker CE and it's related bits and pieces.
printf "\n${BOLD}We're going to install Docker CE, and it's dependancies.${NF}\n"

# Uninstall any previously installed verions, just in case.
printf "\n${BOLD}We're just checking to see if there are any previous verions of Docker and removing them if necessary...${NF}\n"
apt -y remove docker \
docker-client \
docker-client-latest \
docker-common \
docker-latest \
docker-latest-logrotate \
docker-logrotate \
docker-selinux \
docker-engine-selinux \
docker-engine \
docker.io \
containerd \
runc
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 0.2

# Install the dependancies of the storage driver.
printf "\n${BOLD}Prepare repo install...${NF}\n"
apt -y install \
apt-transport-https \
ca-certificates \
curl \
gnupg \
lsb-release
printf "\n${BOLD}${WHITE}Done.${NF}\n"

# Install the Docker GPG key
printf "\n${BOLD}Add the Docker GPG keys...${NF}\n"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
printf "\n${BOLD}${WHITE}Done.${NF}\n"

# Now, add the Docker repo
printf "\n${BOLD}We'll now add the Docker repository to apt...${NF}\n"
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 0.2

# We can now install Docker, start it, and enable it to start on boot
printf "\n${BOLD}Let's now install Docker...${NF}\n"
apt update
apt -y install docker-ce docker-ce-cli containerd.io
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 0.2
printf "\n${BOLD}We can now start it and link it to start on boot...${NF}\n"
systemctl enable docker.service
systemctl enable containerd.service
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Let's also install docker-compose
printf "\n${BOLD}Let's now install Docker Compose...${NF}\n"
VERSION=1.29.1
sudo curl -fsSL https://github.com/docker/compose/releases/download/$VERSION/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Done!
printf "\n${BOLD}All done, enjoy Docker!\n\n"
