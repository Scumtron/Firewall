#!/bin/bash

#
# chmod +x nginx.sh && ./nginx.sh
#

export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1

export NGX_VER=1.13.9
export SSL_VER=1.1.0g
export LUA_VER=2.1.0-beta3

apt-mark unhold nginx
apt update && apt upgrade -y
apt build-dep nginx -y
apt install -y zlib1g-dev libpcre3 libpcre3-dev build-essential libssl-dev gcc make git brotli zopfli

cd /opt

# NGINX MODULES
git clone https://github.com/masterzen/nginx-upload-progress-module.git ngx_upload_progress_module
git clone https://github.com/simplresty/ngx_devel_kit.git
git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git
git clone https://github.com/openresty/lua-nginx-module.git ngx_lua_module

# git clone https://github.com/FRiCKLE/ngx_cache_purge.git
# git clone https://github.com/vozlt/nginx-module-vts.git ngx_vts_module

# BROTLI
git clone https://github.com/google/ngx_brotli.git
cd /opt/ngx_brotli
git submodule update --init

cd /opt

# OPENSSL
wget https://www.openssl.org/source/openssl-$SSL_VER.tar.gz
tar xf openssl-$SSL_VER.tar.gz
rm openssl-$SSL_VER.tar.gz

# LuaJIT
wget http://luajit.org/download/LuaJIT-$LUA_VER.tar.gz
tar -xzvf LuaJIT-$LUA_VER.tar.gz
rm LuaJIT-$LUA_VER.tar.gz
cd LuaJIT-$LUA_VER
make 
make install
ln -sf luajit-$LUA_VER /usr/local/bin/luajit

cd /opt

# NGINX
wget http://nginx.org/download/nginx-$NGX_VER.tar.gz
tar xf nginx-$NGX_VER.tar.gz
rm nginx-$NGX_VER.tar.gz

cd /opt/nginx-$NGX_VER

./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt='-g -O2 -fdebug-prefix-map=/home/jenkins/workspace/Nginx_packages/label/debian9amd64/nginx-1.12.2=. -specs=/usr/share/dpkg/no-pie-compile.specs -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
    --with-ld-opt='-specs=/usr/share/dpkg/no-pie-link.specs -Wl,-z,relro -Wl,-z,now -Wl,-rpath,/usr/local/bin/luajit,--as-needed -pie' \
    --with-openssl=/opt/openssl-$SSL_VER \
    --add-module=/opt/ngx_brotli \
    --add-module=/opt/ngx_http_substitutions_filter_module \
    --add-module=/opt/ngx_upload_progress_module \
    --add-module=/opt/ngx_lua_module \
    --add-module=/opt/ngx_devel_kit
    # --add-module=/opt/ngx_cache_purge
    # --add-module=/opt/ngx_vts_module


make && make install

nginx -t && systemctl restart nginx

apt-mark hold nginx
