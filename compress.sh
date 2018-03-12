#!/bin/bash

filetypes=(js css)
user=user:user

zcomp() {
  for file in ./static/*.${1}; do
    zopfli --i1000 ${file}
    chown $user ${file}.gz
  done
}

bcomp() {
  for file in ./static/*.${1}; do
    brotli --force --quality 11 --input ${file} --output ${file}.br
    chmod 644 ${file}.br
    chown $user ${file}.br
  done
}

for type in ${filetypes[@]}; do
  zcomp ${type}
  bcomp ${type}
done
