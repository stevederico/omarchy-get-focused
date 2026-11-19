# Get Focused

Omarchy bar plugin. Block distracting sites for a set time.

Click the lock in the bar, pick 15 min, 30 min, 1 hr or 2 hr, and flip the toggle. The listed sites are blocked system-wide through `/etc/hosts` until the timer ends. The list is locked while a block runs.

## Install

```
omarchy plugin add https://github.com/stevederico/omarchy-get-focused --enable
```

Open the popup and click **Install Helper**. It asks for your password once and installs a small root helper (`/usr/local/bin/getfocused`) plus a sudo rule that allows only that command.

## Notes

- Sites live in `~/.config/sd-getfocused/sites`, one domain per line.
- The helper schedules its own unblock with `systemd-run`, so the block ends on time even if the shell restarts.
- Browsers with "secure DNS" turned on skip `/etc/hosts`. Turn that off for blocks to hold.

MIT
