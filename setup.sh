#!/bin/bash

#
# wget https://github.com/Scumtron/Firewall/raw/master/setup.sh && chmod +x setup.sh && ./setup.sh
#

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# Main
yum update -y
yum install -y epel-release
rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-1.el7.nux.noarch.rpm
yum update -y
yum install -y nano mc htop iftop curl

export EDITOR=nano
echo "export EDITOR=/usr/bin/nano" >> /root/.bashrc

service auditd stop && chkconfig auditd off

# KVS only
yum install -y memcached ffmpeg imagemagick gcc-c++
curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && chmod a+rx /usr/local/bin/youtube-dl
cd /tmp && wget https://cytranet.dl.sourceforge.net/project/yamdi/yamdi/1.9/yamdi-1.9.tar.gz && tar xzvf yamdi-1.9.tar.gz
cd yamdi-1.9 && make && make install

rm -rf setup.sh
echo "Done"
