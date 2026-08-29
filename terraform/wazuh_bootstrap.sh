#!/bin/bash
set -euo pipefail

# Wazuh all-in-one (manager + indexer + dashboard) - installation non interactive
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh
bash wazuh-install.sh --all-in-one --ignore-check

# Fichier contenant les identifiants générés (admin, kibanaserver, etc.)
mv wazuh-install-files.tar /root/wazuh-install-files.tar

echo "Wazuh install finished at $(date)" > /var/log/wazuh_bootstrap_done.log