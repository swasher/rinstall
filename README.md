Script for automatic install rtorrent and rutorrent.
----------------------------------------------------

Tested on ubuntu 13.04. Must work on other debian-based system.

Usage:

    wget https://raw.github.com/swasher/rinstall/master/rinstall.sh
    chmod 744 rinstall.sh
    ./rinstall.sh

To clean system from previous install, type

    ./rinstall.sh clean

This command purge rtorrent, libtorrent, xmlrpc, rutorrent and lighttpd. Be careful!