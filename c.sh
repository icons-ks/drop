#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo)." 
   exit 1
fi

# 1. Clear  histories (bash, zsh, ash, sh)
for user_home in /home/* /root; do
    if [[ -d "$user_home" ]]; then
        > "$user_home/.bash_history" 2>/dev/null
        > "$user_home/.zsh_history" 2>/dev/null
        > "$user_home/.ash_history" 2>/dev/null
        > "$user_home/.history" 2>/dev/null
    fi
done
history -c
unset HISTFILE

# 2. Wipe system logs (truncate, not remove, to keep file permissions)
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null

# 3. Remove specific log databases and rotate
rm -f /var/log/wtmp* /var/log/btmp* /var/log/lastlog* 2>/dev/null
> /var/log/wtmp
> /var/log/btmp
> /var/log/lastlog

# 4. Clear systemd journal (all persistent logs)
journalctl --rotate
journalctl --vacuum-time=1s
rm -rf /var/log/journal/* 2>/dev/null
rm -rf /run/log/journal/* 2>/dev/null

# 5. Clear authentication logs (including failed attempts)
> /var/log/faillog
> /var/log/tallylog
chattr -i /var/log/faillog 2>/dev/null  # remove immutable flag if set
> /var/log/faillog

# 6. Remove auditd logs
if command -v auditctl &>/dev/null; then
    auditctl -e 0   # temporarily disable auditing
    rm -rf /var/log/audit/* 2>/dev/null
fi

# 7. Clear application logs (common services)
> /var/log/messages
> /var/log/syslog
> /var/log/auth.log
> /var/log/kern.log
> /var/log/dpkg.log
> /var/log/yum.log
> /var/log/dnf.log
> /var/log/secure
> /var/log/maillog
> /var/log/cron
> /var/log/boot.log
> /var/log/httpd/* 2>/dev/null
> /var/log/nginx/* 2>/dev/null
> /var/log/mysql/* 2>/dev/null
> /var/log/postgresql/* 2>/dev/null

# 8. Clear temporary files and caches
rm -rf /tmp/* /var/tmp/* /dev/shm/* 2>/dev/null
rm -rf ~/.cache/* /root/.cache/* 2>/dev/null
for user in /home/*; do rm -rf "$user/.cache" 2>/dev/null; done

# 9. Wipe package manager caches
if command -v apt &>/dev/null; then
    apt clean
    rm -rf /var/cache/apt/* 2>/dev/null
fi
if command -v yum &>/dev/null; then
    yum clean all
    rm -rf /var/cache/yum/* 2>/dev/null
fi
if command -v dnf &>/dev/null; then
    dnf clean all
fi

# 10. Remove SSH logs
> /var/log/sshd.log 2>/dev/null
> /var/log/secure 2>/dev/null
for user in /home/* /root; do
    > "$user/.ssh/known_hosts" 2>/dev/null
    > "$user/.ssh/authorized_keys" 2>/dev/null
done

# 11. Clear last login and session records
> /var/log/lastlog
last -C  # clear lastlog cache (if supported)
echo > /var/log/wtmp
echo > /var/log/btmp

# 12. Reset file timestamps for common directories (optional – comment out)
# find /var/log -type f -exec touch -t 197001010000 {} \; 2>/dev/null
# find /home -type f -name ".*history" -exec touch -t 197001010000 {} \; 2>/dev/null

# 13. Stop logging daemons (temporarily)
systemctl stop rsyslog 2>/dev/null
systemctl stop syslog 2>/dev/null
systemctl stop systemd-journald 2>/dev/null
systemctl stop auditd 2>/dev/null

# 14. Disable history in current and future shells (until reboot)
set +o history
export HISTFILE=/dev/null
export HISTSIZE=0

echo "Logs have been cleared. Reboot recommended for full effect."
echo "To re-enable logging, reboot or manually start services."
