#!/bin/bash

#
# wget https://github.com/Scumtron/Firewall/raw/master/nofiles.sh && chmod +x nofiles.sh && ./nofiles.sh
#


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

Infon() {
	# shellcheck disable=SC2059,SC2145
	printf "\033[1;32m$@\033[0m"
}

Info() {
	# shellcheck disable=SC2059,SC2145
	Infon "$@\n"
}

while true
do
	case "${1}" in
		--db)
			db="true"
			shift 1
			;;
		--apache)
			apache="true"
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

OSDetect

Info "Optimization starting.."
sed -i "s/LimitNOFILE=.*/LimitNOFILE=200000/g" /etc/systemd/system/nginx.service.d/nofile.conf
case ${OSTYPE} in
	REDHAT)
		if [ "#${db}" == "#true" ]; then
			sed -i "s/LimitNOFILE=.*/LimitNOFILE=65536/g" /etc/systemd/system/mariadb.service.d/nofile.conf
		fi
		if [ "#${apache}" == "#true" ]; then
			sed -i "s/LimitNOFILE=.*/LimitNOFILE=65536/g" /etc/systemd/system/httpd.service.d/nofile.conf
		fi
	;;
	DEBIAN)
		if [ "#${db}" == "#true" ]; then
			sed -i "s/LimitNOFILE=.*/LimitNOFILE=65536/g" /etc/systemd/system/mysql.service.d/nofile.conf
		fi
		if [ "#${apache}" == "#true" ]; then
			sed -i "s/LimitNOFILE=.*/LimitNOFILE=65536/g" /etc/systemd/system/apache2.service.d/nofile.conf
		fi
	;;
	*)
		Error "Unsupported OS family: ${OSTYPE}"
	;;
esac

systemctl daemon-reload
systemctl restart nginx

if [ "#${db}" == "#db" ]; then
	systemctl restart mariadb
fi

case ${OSTYPE} in
	REDHAT)
	if [ "#${apache}" == "#apache" ]; then
		systemctl restart httpd
	fi
	;;
	DEBIAN)
		if [ "#${apache}" == "#true" ]; then
			systemctl restart apache2
		fi
	;;
	*)
		Error "Unsupported OS family: ${OSTYPE}"
	;;
esac

Info "Nginx limits"
cat /proc/$(cat /run/nginx.pid)/limits

case ${OSTYPE} in
	REDHAT)
		if [ "#${db}" == "#db" ]; then
			Info "MariaBD limits"
			cat /proc/$(cat /run/mariadb/mariadb.pid)/limits 
		fi
		if [ "#${apache}" == "#apache" ]; then
			Info "Apache limits"
			cat /proc/$(cat /run/httpd/httpd.pid)/limits
		fi
	;;
	DEBIAN)
		if [ "#${db}" == "#db" ]; then
			Info "MariaBD limits"
			cat /proc/$(cat /run/mysqld/mysqld.pid)/limits 
		fi
		if [ "#${apache}" == "#true" ]; then
			Info "Apache limits"
			cat /proc/$(cat /run/apache2/apache2.pid)/limits
		fi
	;;
	*)
		Error "Unsupported OS family: ${OSTYPE}"
	;;
esac

