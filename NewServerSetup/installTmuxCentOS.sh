#!/bin/bash

##############################
##  Jayden Kerr 27/10/2018  ##
##############################
##  Version 0.1 ##
############################################
##  Installs tmux from source on CentOS 7 ##
############################################

# Set this version flag to allow easy updates
VERSION=2.8

# Remove previous installs
sudo yum -y remove tmux

# Install dependancies
sudo yum -y install wget tar libevent-devel ncurses-devel

# Download tarball from GitHub, expand, and make.
wget https://github.com/tmux/tmux/releases/download/${VERSION}/tmux-${VERSION}.tar.gz
tar xzf tmux-${VERSION}.tar.gz
rm -f tmux-${VERSION}.tar.gz
cd tmux-${VERSION}
./configure
sudo make -s install
cd -
sudo rm -rf /usr/local/src/tmux-*
sudo mv tmux-${VERSION} /usr/local/src
