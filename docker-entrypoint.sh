#!/bin/bash
set -e

service postgresql start
service apache2 restart
sudo -u postgres renderd -f -c /usr/local/etc/renderd.conf

/bin/bash
