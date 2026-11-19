#!/bin/bash
# Run through pkexec by the widget: installs the root helper and its sudo rule.
set -eu
u=$(id -nu "$PKEXEC_UID")
install -m 755 -o root -g root "$(dirname "$(readlink -f "$0")")/getfocused" /usr/local/bin/getfocused
echo "$u ALL=(root) NOPASSWD: /usr/local/bin/getfocused" > /etc/sudoers.d/getfocused
chmod 440 /etc/sudoers.d/getfocused
visudo -cf /etc/sudoers.d/getfocused >/dev/null || { rm -f /etc/sudoers.d/getfocused; exit 1; }
