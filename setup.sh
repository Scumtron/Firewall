#!/bin/bash

#
# wget https://github.com/Scumtron/Firewall/raw/master/setup.sh && chmod +x setup.sh && ./setup.sh
#

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

Infon() {
	# shellcheck disable=SC2059,SC2145
	printf "\033[1;32m$@\033[0m"
}

Info() {
	# shellcheck disable=SC2059,SC2145
	Infon "$@\n"
}

Warningn() {
	# shellcheck disable=SC2059,SC2145
	printf "\033[1;35m$@\033[0m"
}

Warning() {
	# shellcheck disable=SC2059,SC2145
	Warningn "$@\n"
}

Warnn() {
	# shellcheck disable=SC2059,SC2145
	Warningn "$@"
}

Warn() {
	# shellcheck disable=SC2059,SC2145
	Warnn "$@\n"
}

Error() {
	# shellcheck disable=SC2059,SC2145
	printf "\033[1;31m$@\033[0m\n"
}

OSDetect() {
	test -n "${OSTYPE}" && return 0
	OSTYPE=unknown
	kern=$(uname -s)
	case "${kern}" in
		Linux)
		if [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
			# RH family
			export OSTYPE=REDHAT
		elif [ -f /etc/debian_version ]; then
			# DEB family
			export OSTYPE=DEBIAN
		fi
		;;
		FreeBSD)
			# FreeBSD
			export OSTYPE=FREEBSD
		;;
	esac
	if [ "#${OSTYPE}" = "#unknown" ]; then
		Error "Unknown os type. Try to use \"--osfamily\" option"
		exit 1
	fi

}

BadHostname() {
	test -z "${1}" && return 1
	# shellcheck disable=SC2039
	local HOSTNAME=${1}

	LENGTH=$(echo "${HOSTNAME}" | wc -m)
	if [ "${LENGTH}" -lt 2 ] || [ "${LENGTH}" -gt 50 ]; then
		return 1
	fi
	if ! echo "${HOSTNAME}" | grep -q '\.'; then
		return 1
	fi
	if echo "${HOSTNAME}" | grep -q '_'; then
		return 1
	fi
	local TOPLEVEL=$(echo "${HOSTNAME}" | awk -F. '{print $NF}')
	if [ -z "${TOPLEVEL}" ]; then
		return 1
	fi
	if [ -n "$(echo "${TOPLEVEL}" | sed -r 's/[a-zA-Z0-9\-]//g')" ]; then
		return 1
	fi
}

SetHostname() {
	# 1 - new hostname
	# 2 - old hostname
	test -z "${1}" && return 1
#	test -z "${2}" && return 1
	# shellcheck disable=SC2039,SC2086
	local HOSTNAME=$(echo ${1} | sed 's|\.+$||')
	case "${OSTYPE}" in
	REDHAT)
		# shellcheck disable=SC2086
		hostname ${HOSTNAME} || return 1
		sed -i -r "s|^HOSTNAME=|HOSTNAME=${HOSTNAME}|" /etc/sysconfig/network || return 1
		if [ -n "${2}" ]; then
			sed -i -r "s|${2}|${HOSTNAME}|g" /etc/hosts || return 1
		fi
		;;
	DEBIAN)
		# shellcheck disable=SC2039,SC2116,SC2086
		local CUTHOSTNAME=$(echo ${HOSTNAME%\.*})
		# shellcheck disable=SC2086
		hostname ${CUTHOSTNAME} || return 1
		echo "${CUTHOSTNAME}" > /etc/hostname || return 1
		if [ -n "${2}" ]; then
			sed -i -r "s|${2}|${HOSTNAME}|g" /etc/hosts || return 1
		fi
		if ! hostname -f >/dev/null 2>&1 ; then
			sed -i -r "s|^([0-9\.]+\s+)${HOSTNAME}\s*$|\1${HOSTNAME} ${CUTHOSTNAME}|g" /etc/hosts
		fi
		if ! hostname -f >/dev/null 2>&1 ; then
			echo "$(GetFirstIp) ${HOSTNAME} ${CUTHOSTNAME}" >> /etc/hosts
		fi
		if ! hostname -f >/dev/null 2>&1 ; then
			Error "Can not set hostname"
			return 1
		fi
		;;
	esac
}

CheckHostname() {
	if [ "${OSTYPE}" = "DEBIAN" ]; then
		# shellcheck disable=SC2039
		local CURHOSTNAME=$(hostname -f ||:)
	else
		# shellcheck disable=SC2039
		local CURHOSTNAME=$(hostname || :)
	fi
	# shellcheck disable=SC2039
	local HOSTNAME=${CURHOSTNAME}
	if [ "#${silent}" != "#true" ]; then
		# shellcheck disable=SC2086
		while ! BadHostname ${HOSTNAME};
		do
			Error "You have incorrect hostname: ${HOSTNAME}"
			# shellcheck disable=SC2039,SC2162
			read -p "Enter new hostname(or Ctrl+C to exit): " HOSTNAME
			echo
		done
		Info "You have hostname: ${HOSTNAME}"
		if [ ! "${CURHOSTNAME}" = "${HOSTNAME}" ]; then
			# shellcheck disable=SC2039
			local err_hn=0
			# shellcheck disable=SC2086
			SetHostname ${HOSTNAME} ${CURHOSTNAME} || err_hn=1
			if [ ${err_hn} -ne 0 ]; then
				echo 
				Error "Can not change hostname. Please change it manually"
				exit 1
			fi
		fi
	else
		# shellcheck disable=SC2086
		if ! BadHostname ${HOSTNAME}; then
			Error "You have incorrect hostname: ${HOSTNAME}"
			Error "Please change it manually"
			exit 1
		fi
	fi
}

CheckAppArmor() {
	# Check if this ubuntu
	[ "${OSTYPE}" = "DEBIAN" ] || return 0
	[ "$(lsb_release -s -i)" = "Ubuntu" ] || return 0
	if service apparmor status >/dev/null 2>&1 ; then
#		if [ -n "$release" ] || [ -n "$silent" ]; then
#			Error "Apparmor is enabled, aborting installation."
#			exit 1
#		fi
		Error "AppArmor is enabled on your server. Can not install with AppArmor. Trying to disable it"
		service apparmor stop
		service apparmor teardown
		update-rc.d -f apparmor remove
	fi
}

CheckSELinux() {
	# shellcheck disable=SC2039,SC2155
	local kern=$(uname -s)
	if [ "$kern" = "Linux" ]; then
		if selinuxenabled > /dev/null 2>&1 ; then
			# silent install
			if [ -n "$release" ] || [ -n "$silent" ]; then
				Error "SELinux is enabled, aborting installation."
				exit 1
			fi
			Error "SELinux is enabled on your server. It is strongly recommended to disable SELinux before you proceed."
			# shellcheck disable=SC2039,SC2155
			local uid=$(id -u)
			# do we have a root privileges ?
			if [ "$uid" = "0" ]; then
				# shellcheck disable=SC2039
				echo -n "Would you like to disable SELinux right now (yes/no)?"
				# shellcheck disable=SC2039
				local ask1
				ask1="true"
				while [ "$ask1" = "true" ]
				do
					ask1="false"
					# shellcheck disable=SC2162
					read answer
					if [ -z "$answer" ] || [ "$answer" = "yes" ]; then
						# do disable SELinux
						setenforce 0 >/dev/null 2>&1
						cp -n /etc/selinux/config /etc/selinux/config.orig >/dev/null 2>&1
						echo SELINUX=disabled > /etc/selinux/config
						Error "Reboot is requred to complete the configuration of SELinux."
						# shellcheck disable=SC2039
						echo -n "Reboot now (yes/no)?"
						# shellcheck disable=SC2039
						local ask2
						ask2="true"
						while [ "$ask2" = "true" ]
						do
							ask2="false"
							# shellcheck disable=SC2162
							read answer
							if [ "$answer" = "yes" ]; then
								Info "Rebooting now. Please start installation script again once the server reboots."
								shutdown -r now
								exit 0
							elif [ "$answer" = "no" ]; then
								Error "It is strongly recommended to reboot server before you proceed the installation"
							else
								ask2="true"
								# shellcheck disable=SC2039
								echo -n "Please type 'yes' or 'no':"
							fi
						done
					elif [ "$answer" != "no" ]; then
						ask1="true";
						# shellcheck disable=SC2039
						echo -n "Please type 'yes' or 'no':"
					fi
				done
			fi
		fi
	fi
}

OSVersion() {
	test -n "${OSVER}" && return 0
	OSVER=unknown
	case ${OSTYPE} in
		REDHAT)
			if ! which which >/dev/null 2>/dev/null ; then
				yum -y install which
			fi
			if [ -z "$(which hexdump 2>/dev/null)" ]; then
				yum -y install util-linux-ng
			fi
			OSVER=$(rpm -q --qf "%{version}" -f /etc/redhat-release)
			if echo "${OSVER}" | grep -q Server ; then
				OSVER=$(echo "${OSVER}" | sed 's/Server//')
			fi
			OSVER=${OSVER%%\.*}
			if ! echo "${centos_OSVERSIONS}" | grep -q -w "${OSVER}" ; then
				unsupported_osver="true"
			fi
		;;
		DEBIAN)
			/usr/bin/apt-get -qy update
			if ! which which >/dev/null 2>/dev/null ; then
				/usr/bin/apt-get -qy --allow-unauthenticated install which
			fi
			if [ -z "$(which lsb_release 2>/dev/null)" ]; then
				/usr/bin/apt-get -qy --allow-unauthenticated install lsb-release
			fi
			if [ -z "$(which hexdump 2>/dev/null)" ]; then
				/usr/bin/apt-get -qy --allow-unauthenticated install bsdmainutils
			fi
			if [ -z "$(which logger 2>/dev/null)" ]; then
				/usr/bin/apt-get -qy --allow-unauthenticated install bsdutils
			fi
			if [ -z "$(which free 2>/dev/null)" ]; then
				/usr/bin/apt-get -qy --allow-unauthenticated install procps
			fi
			if [ -z "$(which python 2>/dev/null)" ]; then
				/usr/bin/apt-get -qy --allow-unauthenticated install python
			fi
			if [ -z "$(which gpg 2>/dev/null)" ]; then
				/usr/bin/apt-get -qy --allow-unauthenticated install gnupg
			fi
			if [ -x /usr/bin/lsb_release ]; then
				OSVER=$(lsb_release -s -c)
			fi
			if ! echo "${debian_OSVERSIONS} ${ubuntu_OSVERSIONS}" | grep -q -w "${OSVER}" ; then
				unsupported_osver="true"
			fi
			if [ "$(lsb_release -s -i)" = "Ubuntu" ]; then
				export reponame=ubuntu
			else
				export reponame=debian
			fi
		;;
	esac
	if [ "#${OSVER}" = "#unknown" ]; then
		Error "Unknown os version. Try to use \"--osversion\" option"
		exit 1
	fi
	if [ "#${unsupported_osver}" = "#true" ]; then
		Error "Unsupported os version (${OSVER})"
		exit 1
	fi
}

CheckRepo() {
	# Check if repository added
	# $1 - repo name
	case ${OSTYPE} in
		REDHAT)
			# shellcheck disable=SC2086
			yum repolist enabled 2>/dev/null | awk '{print $1}' | grep -q ${1}
			;;
		DEBIAN)
			# shellcheck disable=SC2086,SC2086
			apt-cache policy | awk -vrname=${1}/main '$NF == "Packages" && $(NF-2) == rname' | grep -q ${1}
			;;
	esac
}

InstallEpelRepo() {
	# Install epel repo
	# ${1} = true - Use cdn or mirrorlist
	test "${OSTYPE}" = "REDHAT" || return 0
	Infon "Checking epel... "
	if [ ! -f /etc/yum.repos.d/epel.repo ] || ! CheckRepo epel ; then
		if rpm -q epel-release >/dev/null ; then
			Warn "Epel repo file broken. Removing epel-release package"
			rpm -e --nodeps epel-release
		else
			Info "Epel repo not exists"
		fi
		rm -f /etc/yum.repos.d/epel.repo
	fi
	if grep -iq cloud /etc/redhat-release ; then
		Info "Importing EPEL key.."
		# shellcheck disable=SC2086
		rpm --import http://mirror.yandex.ru/epel/RPM-GPG-KEY-EPEL-${OSVER} || return 1
		if ! rpm -q epel-release >/dev/null ; then
			Info "Adding repository EPEL.."
			if [ "${OSVER}" = "6" ]; then
				rpm -iU http://download.ispsystem.com/repo/centos/epel/6/x86_64/epel-release-6-8.noarch.rpm || return 1
			elif [ "${OSVER}" = "7" ]; then
				rpm -iU http://download.ispsystem.com/repo/centos/epel/7/x86_64/e/epel-release-7-10.noarch.rpm || return 1
			fi
		fi
	else
		if ! rpm -q epel-release >/dev/null ; then
			# epel-release already in extras repository which enabled by default
			Info "Installing epel-release package.."
			yum -y install epel-release || return 1
		else
			Info "Epel package already installed"
		fi
	fi
	if ! grep -qE "mirrorlist=http://download.ispsystem.com/" /etc/yum.repos.d/epel.repo ; then
		sed -i -r '/\[epel\]/,/\[epel/s|^(mirrorlist=).*|\1http://download.ispsystem.com/repo/centos/epel/mirrorlist.txt|' /etc/yum.repos.d/epel.repo
		yum clean all || :
	fi
}

OSDetect
CheckHostname
CheckAppArmor
CheckSELinux
InstallEpelRepo

while true
do
	case "${1}" in
		--kvs)
			kvs="true"
			shift 1
			;;
		--isp)
			isp="true"
			shift 1
			;;
		--fpm)
			fpm="true"
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

Info "Install software.."
case ${OSTYPE} in
	REDHAT)
		yum update -y
		yum install -y nano mc htop iftop
		if [ -e /var/run/auditd.pid ]; then 
			service auditd stop >/dev/null 2>&1
			chkconfig auditd off >/dev/null 2>&1
			Info "Auditd stopped"
		fi
		if [ "#${kvs}" == "#true" ]; then
			yum install -y memcached ffmpeg ImageMagick curl zip unzip gcc-c++
			sed -i "s/"CACHESIZE=\"64\""/"CACHESIZE=\"1024\""/g" /etc/sysconfig/memcached
			systemctl restart memcached && systemctl start memcached && systemctl enable memcached
			cd /tmp && wget https://cytranet.dl.sourceforge.net/project/yamdi/yamdi/1.9/yamdi-1.9.tar.gz && tar xzvf yamdi-1.9.tar.gz
			cd yamdi-1.9 && make && make install
			Info "Software for KVS installed"
		fi
		yum -y makecache || yum -y makecache || return 1
	;;
	DEBIAN)
		apt-get -y update 
		if [ "#${kvs}" == "#true" ]; then
			apt install -y memcached ffmpeg imagemagick curl zip unzip
			Info "Software for KVS installed"
		fi
	;;
	*)
		Error "Unsupported OS family: ${OSTYPE}"
	;;
esac

if [ "#${kvs}" == "#true" ]; then
	curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && chmod a+rx /usr/local/bin/youtube-dl
fi

if [ "#${isp}" == "#true" ]; then
	# Custom profile
	cat > /etc/profile.d/oneinstack.sh << EOF
HISTSIZE=10000
PS1="\[\e[37;40m\][\[\e[32;40m\]\u\[\e[37;40m\]@\h \[\e[35;40m\]\W\[\e[0m\]]\\\\$ "
HISTTIMEFORMAT="%F %T \$(whoami) "
alias l='ls -AFhlt'
alias lh='l | head'
alias vi=vim
GREP_OPTIONS="--color=auto"
alias grep='grep --color'
alias egrep='egrep --color'
alias fgrep='fgrep --color'
EOF

	[ -z "$(grep ^'PROMPT_COMMAND=' /etc/bashrc)" ] && cat >> /etc/bashrc << EOF
PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });logger "[euid=\$(whoami)]":\$(who am i):[\`pwd\`]"\$msg"; }'
EOF

	cat > /etc/security/limits.conf <<EOF
* soft nproc 1000000
* hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
EOF

	[ ! -e "/etc/sysctl.conf_bk" ] && /bin/mv /etc/sysctl.conf{,_bk}
	cat > /etc/sysctl.conf << EOF
fs.file-max=1000000
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_rmem = 4096 87380 4194304
net.ipv4.tcp_wmem = 4096 16384 4194304
net.ipv4.tcp_max_syn_backlog = 16384
net.core.netdev_max_backlog = 32768
net.core.somaxconn = 32768
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_syncookies = 1
#net.ipv4.tcp_tw_len = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.ip_local_port_range = 1024 65000
net.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_max = 6553500
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_established = 3600
EOF

	sysctl -p
	
	# ip_conntrack table full dropping packets
	[ ! -e "/etc/sysconfig/modules/iptables.modules" ] && { echo -e "modprobe nf_conntrack\nmodprobe nf_conntrack_ipv4" > /etc/sysconfig/modules/iptables.modules; chmod +x /etc/sysconfig/modules/iptables.modules; }
	modprobe nf_conntrack
	modprobe nf_conntrack_ipv4
	echo options nf_conntrack hashsize=131072 > /etc/modprobe.d/nf_conntrack.conf
	
	cd /tmp && wget "http://cdn.ispsystem.com/install.sh" && sh install.sh --release stable ispmanager-lite-common 
else
	if [ "#${fpm}" == "#true" ]; then
		wget http://mirrors.linuxeye.com/oneinstack-full.tar.gz && tar xzf oneinstack-full.tar.gz && ./oneinstack/install.sh --nginx_option 1 --php_option 7 --phpcache_option 1 --pureftpd 
	else
		wget http://mirrors.linuxeye.com/oneinstack-full.tar.gz && tar xzf oneinstack-full.tar.gz && ./oneinstack/install.sh --nginx_option 1 --apache_option 1 --php_option 4 --phpcache_option 1 --php_extensions ioncube,imagick,memcache --phpmyadmin  --db_option 5 --dbinstallmethod 2 --dbrootpwd ayvug3al --pureftpd  --memcached  --iptables 
	fi
fi

# Set nano editor by default
echo "export EDITOR=/usr/bin/nano" >> /root/.bashrc && export EDITOR=/usr/bin/nano && . /etc/profile

# Set timezone
rm -rf /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Moscow /etc/localtime

cd && rm -rf setup.sh
echo "Installation complete"
