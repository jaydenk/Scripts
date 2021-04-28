#!/bin/bash

##############################
##  Jayden Kerr 25/10/2018  ##
##    Updated 02/01/2021    ##
##############################
##  Version 1.0.2 ##
############################################################
##  CentOS Packaging Script. Installs the following:      ##
##  1.  epel-release                                      ##
##  2.  fail2ban                                          ##
##  3.  wget                                              ##
##  4.  nano                                              ##
##  5.  vim                                               ##
##  6.  fish                                              ##
##  7.  mosh                                              ##
##  8.  git                                               ##
##  9.  gcc                                               ##
##  10. htop                                              ##
##  11. iftop                                             ##
##  12. nload                                             ##
##  13. tree                                              ##
##  14. tmux                                              ##
##  15. docker                                            ##
##  As well as sets up a few other bits and pieces.       ##
############################################################

##################################
##  PART 1 - TO BE RUN AS root  ##
##################################

# Instance variables
localIP=$(hostname -I)
RED="\033[0;31m" # Red text
WHITE="\033[1;37m" # White text
NF="\033[0m" # No formatting
NB="\033[21m" # No bold
BOLD="\033[1m" # Bold text
NC="\033[39m" # Default text colour

printf "\n\n${WHITE}##############################\n##  Jayden Kerr 02/01/2021  ##\n##############################\n##        Version 1.1       ##\n##############################\n##  CentOS Packaging Script ##\n##############################${NF}\n\n"

# Welcome
printf "\n${BOLD}Welcome, let's get this machine setup.${NF}\n"

# Change root password
printf "${BOLD}\nStep 1.${NF}\n"
question="change the root password?"
actionToPerform=$(echo "hi")
actionToSkip="changing the root password."
changeRootPassword () {
  printf "${BOLD}We will now change the root password, because that's a good idea.${NF}\n"
  passwd
}
questionUser () {
        while true; do
                read -p "Do you wish to ${1} [y/n] " yn
                case $yn in
                        [Yy]* ) changeRootPassword; sleep 1; break;;
                        [Nn]* ) printf "Skipping ${2}\n"; sleep 1; break;;
                        * ) printf "Please answer [y]es or [n]o.\n";;
                esac
        done
}
questionUser "$question" "$actionToSkip"

# Create limited user
printf "${BOLD}\nStep 2.${NF}\n"
question="create a limited user?"
actionToSkip="creation of limited user."
createLimitedUser () {
  printf "\n${BOLD}Now let's create a limited user and set a password for it.${NF}\n"
  printf "\n${BOLD}Please enter the desired username: ${NF}${WHITE}"
  read LimitedUserName
  sleep 0.2
  printf "\n${NF}${BOLD}Cool. ${WHITE}$LimitedUserName${NC} it is.${NF}\n"
  useradd $LimitedUserName
  sleep 0.2
  sudo passwd $LimitedUserName
  usermod -aG wheel $LimitedUserName
}
questionUser () {
        while true; do
                read -p "Do you wish to ${1} [y/n] " yn
                case $yn in
                        [Yy]* ) createLimitedUser; sleep 1; break;;
                        [Nn]* ) printf "Skipping ${2}\n"; sleep 1; break;;
                        * ) printf "Please answer [y]es or [n]o.\n";;
                esac
        done
}
questionUser "$question" "$actionToSkip"

# Create recovery user for SSH
# This user will be the only user that can SSH into the machine without a key
printf "${BOLD}\nStep 3.${NF}\n"
question="create a recovery user?"
actionToSkip="creation of recovery user."
createRecoveryUser () {
  printf "\n${BOLD}Nice. Now let's create an SSH recovery user and set a password for it.${NF}\n"
  printf "\n${BOLD}Please enter the desired username: ${NF}${WHITE}"
  read RecoveryUserName
  sleep 0.2
  printf "\n${NF}${BOLD}Cool. ${WHITE}$RecoveryUserName${NC} it is.${NF}\n"
  useradd $RecoveryUserName
  sleep 0.2
  sudo passwd $RecoveryUserName
  usermod -aG wheel $RecoveryUserName
}
questionUser () {
        while true; do
                read -p "Do you wish to ${1} [y/n] " yn
                case $yn in
                        [Yy]* ) createRecoveryUser; sleep 1; break;;
                        [Nn]* ) printf "Skipping ${2}\n"; sleep 1; break;;
                        * ) printf "Please answer [y]es or [n]o.\n";;
                esac
        done
}
questionUser "$question" "$actionToSkip"

# We will now create the /.ssh folder for $LimitedUserName,
# with appropriate permissions
mkdir -p /home/$LimitedUserName/.ssh
chown -R $LimitedUserName /home/$LimitedUserName/.ssh
chmod -R 700 /home/$LimitedUserName/.ssh
printf "\n${BOLD}Please copy your SSH key to the machine now, using:\n\t${WHITE}scp ~/.ssh/id_rsa.pub $LimitedUserName@$localIP:~/.ssh/authorized_keys\n${NC}Or similar. "
read -n 1 -s -r -p "Press any key to continue when done..."
printf "\n\n${BOLD}sshd_config will be edited to allow login only via authorized_keys.${NF}\n"
sleep 1

# Set machine hostname
printf "${BOLD}\nStep 4.${NF}\n"
question="change the machine hostname?"
actionToSkip="changing of machine hostname."
changeHostname () {
  printf "\n${BOLD}Let's set the hostname for this machine.${NF}\n"
  printf "\n${BOLD}Please enter your desired hostname: ${WHITE}"
  read machineHostname
  printf "${NF}\n${BOLD}Cool. ${WHITE}$machineHostname${NC} it is.${NF}\n"
  hostnamectl set-hostname $machineHostname
  printf "\n${BOLD}Setting hostname...${NF}\n\n"
  sleep 0.2
  hostname
  sleep 0.2
  printf "\n${BOLD}${WHITE}Done.${NF}\n"
}
questionUser () {
        while true; do
                read -p "Do you wish to ${1} [y/n] " yn
                case $yn in
                        [Yy]* ) changeHostname; sleep 1; break;;
                        [Nn]* ) printf "Skipping ${2}\n"; sleep 1; break;;
                        * ) printf "Please answer [y]es or [n]o.\n";;
                esac
        done
}
questionUser "$question" "$actionToSkip"

# Set the date and time correctly
printf "${BOLD}\nStep 5.${NF}\n"
printf "\n${BOLD}These are the current date and time settings:${NF}\n"
timedatectl
# TODO make this optional. For now, it just sets the timezone to AUS/ADL
printf "\n${BOLD}Correcting timezone...${NF}\n"
timedatectl set-timezone Australia/Adelaide
timedatectl
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Update the OS before starting to install packages
printf "${BOLD}\nStep 6.${NF}\n"
printf "\n${BOLD}We will now update the OS before commencing package installs...${NF}\n"
sudo yum -y update 1>> ~/setup.log
sudo yum -y upgrade 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install CentOS-EPEL release repo
printf "\n${BOLD}Adding the CentOS EPEL repo...${NF}\n"
sudo yum -y install epel-release 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Let's start installing a few packages
printf "${BOLD}\nStep 7.${NF}\n"
printf "\n${BOLD}We will now install a few key pieces of software and configure them.${NF}\n"

# Installing git
printf "\n${BOLD}Installing git...${NF}\n"
sudo yum -y install git 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Clone dotfiles into /home/$LimitedUserName/.dotfiles
printf "\n${BOLD}Cloning .dotfiles into ~/.dotfiles...${NF}\n"
git clone https://github.com/jaydenk/dotfiles.git /home/$LimitedUserName/.dotfiles
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Append recovery user exception to sshd_config
printf "\n${BOLD}Adding exception to sshd_config for ${WHITE}$RecoveryUserName${NC}...${NF}\n"
printf "# Add recovery user exception\nMatch User $RecoveryUserName\n\tPasswordAuthentication yes" >> /home/$LimitedUserName/.dotfiles/sshd_config
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Move sshd_config into /etc/sshd/ and set correct permissions, then restart sshd
printf "\n${BOLD}Moving sshd_config to /etc/sshd/ and setting correct permissions...${NF}\n"
mv /home/$LimitedUserName/.dotfiles/sshd_config /etc/ssh/
chown root /etc/ssh/sshd_config
chmod 600 /etc/ssh/sshd_config
sleep 0.2
printf "\n${BOLD}Reloading sshd...${NF}"
systemctl restart sshd
printf "${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install wget
printf "\n${BOLD}Installing wget...${NF}\n"
yum -y install wget 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install fail2ban and configure to enable SSH blocking
printf "\n${BOLD}Installing fail2ban...\n${NF}"
yum -y install fail2ban 1>> ~/setup.log
systemctl start fail2ban
systemctl enable fail2ban
printf "\n${BOLD}${WHITE}Done.${NF}\n"
printf "\n${BOLD}Copying fail2ban.conf...${NF}"
cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
printf "${BOLD}${WHITE}Done.${NF}\n"
sleep 0.2
printf "\n${BOLD}Copying jail.local from home/$LimitedUserName/.dotfiles...${NF}"
cp /home/$LimitedUserName/.dotfiles/fail2ban.jail.local /etc/fail2ban/jail.local
chown root /etc/fail2ban/jail.local
chmod 644 /etc/fail2ban/jail.local
printf "${BOLD}${WHITE}Done.${NF}\n"
printf "\n${BOLD}Starting fail2ban-client...${NF}\n"
fail2ban-client reload
fail2ban-client status
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 0.2
printf "\n${BOLD}fail2ban has been successfully installed and configued.${NF}\n"
sleep 1

# Install nano, the sane text editor
printf "\n${BOLD}Installing nano...${NF}\n"
yum -y install nano 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install vim, because everyone should know how to exit it
printf "\n${BOLD}Installing vim...${NF}\n"
yum -y install vim 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install fish, the sane shell, and setting it as the default shell for $LimitedUserName
printf "\n${BOLD}Installing fish...${NF}\n"
cd /etc/yum.repos.d/
wget -nv https://download.opensuse.org/repositories/shells:fish:release:3/RHEL_7/shells:fish:release:3.repo
yum -y install fish 1>> ~/setup.log
cd ~
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 0.2
printf "\n${BOLD}Setting fish as the default shell for $LimitedUserName...${NF}\n"
chsh -s /usr/bin/fish $LimitedUserName
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install mosh, the only way to connect. Adds firewall exceptions for port range 60000-61000.
printf "\n${BOLD}Installing mosh...${NF}\n"
yum -y install mosh 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 0.2
printf "\n${BOLD}Adding firewall exception for port range 60000-61000, and reloading firewall...\n${NF}"
printf "\n${BOLD}Firewall exception: ${NF}${WHITE}"
firewall-cmd --zone=public --permanent --add-port=60000-61000/udp
printf "\n${NF}${BOLD}Firewall reload: ${NF}${WHITE}"
firewall-cmd --reload
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install gcc, just in case you know.
printf "\n${BOLD}Installing gcc...${NF}\n"
yum -y install gcc 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install htop, to keep an eye on this nonsense.
printf "\n${BOLD}Installing htop...${NF}\n"
yum -y install htop 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install iftop, to keep an eye on the network
printf "\n${BOLD}Installing iftop...${NF}\n"
yum -y install iftop 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install nload, to keep an eye on the network in a bit more of a friend way
printf "\n${BOLD}Installing nload...${NF}\n"
yum -y install nload 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install tree, to dig through the mess
printf "\n${BOLD}Installing tree...${NF}\n"
yum -y install tree 1>> ~/setup.log
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# symlink tmux.conf from .dotfiles to ~
printf "\n${BOLD}Linking your tmux.conf file...${NF}"
ln -s /home/$LimitedUserName/.dotfiles/tmux.conf /home/$LimitedUserName/.tmux.conf
printf "${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install tmux, building from source. This requires the script to be kept
# upto date when new builds are released.
printf "\n${BOLD}Installing tmux from source, this may take a few seconds...${NF}\n"
curl -fsSL https://raw.githubusercontent.com/jaydenk/Scripts/master/NewServerSetup/installTmuxCentOS.sh -o installTmuxCentOS.sh
chmod u+x installTmuxCentOS.sh
/bin/bash ./installTmuxCentOS.sh
printf "\n${BOLD}${WHITE}Done.${NF}\n"
sleep 1

# Install docker. Pulls install script from GitHub, appends commands to add
# user to docker group, then runs.
printf "\n${BOLD}Finally we'll install docker...${NF}\n"
printf "${BOLD}Pulling install script from GitHub...${NF}\n"
curl -fsSL https://raw.githubusercontent.com/jaydenk/Scripts/master/NewServerSetup/installDockerCentOS.sh -o installDockerCentOS.sh
chmod u+x installDockerCentOS.sh
printf "# Add $LimitedUserName to docker group to avoid needing sudo\nprintf \"\\n${BOLD}Adding $LimitedUserName to docker group...${NF}\"\nusermod -aG docker $LimitedUserName\nprintf \"${BOLD}${WHITE}Done.${NF}\\n\"\n\n# Hand control back to setup.sh\nprintf \"\\n${BOLD}Handing control back to setup.sh...${NF}\\n\"" >> installDockerCentOS.sh
chmod u+x installDockerCentOS.sh
/bin/bash ./installDockerCentOS.sh
sleep 1

# And that's it!
printf "\n${BOLD}${WHITE}Done! Enjoy your machine.\n\n${NF}"
