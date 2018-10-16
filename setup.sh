#!/bin/bash

#
# wget https://github.com/Scumtron/Firewall/raw/master/setup.sh && chmod +x setup.sh && ./setup.sh
#

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

yum update -y
yum install -y epel-release
rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm
yum update -y
yum install -y nano mc htop iftop curl memcached ffmpeg imagemagick
echo "export EDITOR=nano" >> /root/.bashrc
echo "Done"
