#!/bin/bash

# Simply pulls the latest image from hwdsl2/ipsec-vpn-server
# and restarts the container.

# Instance variables
localIP=$(hostname -I)
RED="\033[0;31m" # Red text
WHITE="\033[1;37m" # White text
NF="\033[0m" # No formatting
NB="\033[21m" # No bold
BOLD="\033[1m" # Bold text
NC="\033[39m" # Default text colour
containerName=ipsec-vpn
containerState=$(docker inspect --format="{{.State.Running}}" $containerName 2> /dev/null)

docker pull hwdsl2/ipsec-vpn-server:latest

if [[ "$containerState" == true ]]; then
  printf "\n${WHITE}IPSec VPN running - restarting.${NF}\n"
  docker restart ipsec-vpn
  printf "\n${WHITE}Done.${NF}\n"
elif [[ "$containerState" == false ]]; then
  printf "\n${WHITE}IPSec VPN not running - starting.${NF}\n"
  docker run --name ipsec-vpn --env-file ~/services/vpn/vpn.env --restart=always -p 500:500/udp -p 4500:4500/udp -d --privileged hwdsl2/ipsec-vpn-server
  printf "\n${WHITE}Done.${NF}\n"
else
  printf "\n${WHITE}Container doesn't exist - creating.${NF}\n"
  docker run --name ipsec-vpn --env-file ~/services/vpn/vpn.env --restart=always -p 500:500/udp -p 4500:4500/udp -d --privileged hwdsl2/ipsec-vpn-server
  printf "\n${WHITE}Done.${NF}\n"
fi
