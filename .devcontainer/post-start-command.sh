#!/bin/bash
set -e

/usr/local/bin/inject-credentials.sh
sudo /usr/local/bin/setup-firewall.sh
