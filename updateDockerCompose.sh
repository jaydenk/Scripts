#!/bin/bash

# Prompts for the latest version of docker compose
# and installs it.

# Instance variables
localIP=$(hostname -I)
RED="\033[0;31m" # Red text
WHITE="\033[1;37m" # White text
NF="\033[0m" # No formatting
NB="\033[21m" # No bold
BOLD="\033[1m" # Bold text
NC="\033[39m" # Default text colour

printf "\n${WHITE}${BOLD}Update docker-compose...${NF}\n"

printf "\n${WHITE}Current docker-compose version:${NF}\n"
sudo docker-compose --version

printf "\n${WHITE}What is the latest version of docker-compose?${NF} "
read dockerComposeVersion
printf "\n${WHITE}Updating..."
sudo curl -sL https://github.com/docker/compose/releases/download/${dockerComposeVersion}/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
printf "done.${NF}\n"

docker-compose --version

printf "\n${GREEN}${BOLD}Complete.${NF}\n\n"
