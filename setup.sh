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
yum install -y nano mc htop iftop

export EDITOR=/usr/bin/nano
echo "export EDITOR=/usr/bin/nano" >> /root/.bashrc

if [ -e /var/run/auditd.pid ]; then 
	service auditd stop >/dev/null 2>&1
	chkconfig auditd off >/dev/null 2>&1
	echo "Auditd stopped"
fi

while true
do
	case "${1}" in
		--kvs)
			kvs="true"
			shift 1
			;;
		*)
			if [ -z "${1}" ]; then
				break
			fi
			echo "Unknown parametr ${1}"
			shift 1
			;;
	esac
done

if [ "#${kvs}" == "#true" ]; then
	yum install -y memcached ffmpeg ImageMagick curl gcc-c++
	curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && chmod a+rx /usr/local/bin/youtube-dl
	cd /tmp && wget https://cytranet.dl.sourceforge.net/project/yamdi/yamdi/1.9/yamdi-1.9.tar.gz && tar xzvf yamdi-1.9.tar.gz
	cd yamdi-1.9 && make && make install
fi

cd && rm -rf setup.sh
echo "Done"
