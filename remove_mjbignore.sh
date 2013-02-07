#!/bin/sh
rm "${1}""/.mjbignore"
touch /home/rtorrent/flag_new_present
echo "${1}">/home/rtorrent/flag_new_present
