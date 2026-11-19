#!/bin/bash
# Run through pkexec by the widget: installs the root helper and its sudo rule.
set -eu
u=$(id -nu "$PKEXEC_UID")
install -m 755 -o root -g root "$(dirname "$(readlink -f "$0")")/siteblock" /usr/local/bin/siteblock
echo "$u ALL=(root) NOPASSWD: /usr/local/bin/siteblock" > /etc/sudoers.d/siteblock
chmod 440 /etc/sudoers.d/siteblock
visudo -cf /etc/sudoers.d/siteblock >/dev/null || { rm -f /etc/sudoers.d/siteblock; exit 1; }
