#!/bin/bash
set -e

### ----------- CONFIGURATION ----------- ###
DNS_SERVERS="192.168.0.1,192.168.0.2"
NTP_SERVER="192.168.0.1"
DOMAIN_NAME="YOUR_DOMAIN.local"
DOMAIN_USER="YOUR_USER"
DOMAIN_CONTROLLER_HOSTNAME="dc1.YOUR_DOMAIN.local"
DOMAIN_CONTROLLER_IP="192.168.0.1"

### ----------- Ensure /etc/hosts entry ----------- ###
if ! grep -qE "^\s*$DOMAIN_CONTROLLER_IP\s+.*\b$DOMAIN_CONTROLLER_HOSTNAME\b" /etc/hosts; then
    echo "Adding $DOMAIN_CONTROLLER_IP $DOMAIN_CONTROLLER_HOSTNAME to /etc/hosts"
    echo "$DOMAIN_CONTROLLER_IP    $DOMAIN_CONTROLLER_HOSTNAME" >> /etc/hosts
fi

### ----------- Optional Hostname Change ----------- ###
echo ""
read -p "Do you want to change the hostname before proceeding? (Y/n): " CHANGE_HOSTNAME
if [[ "$CHANGE_HOSTNAME" =~ ^[Yy]$ ]]; then
    read -p "Enter new hostname: " NEW_HOSTNAME
    hostnamectl set-hostname "$NEW_HOSTNAME"
    echo "Hostname changed to $NEW_HOSTNAME."
fi

HOSTNAME=$(hostnamectl --static)
echo "Using hostname: $HOSTNAME"

### ----------- Detect OS ----------- ###
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Unsupported OS."
    exit 1
fi

### ----------- Install Required Packages ----------- ###
echo "Installing required packages..."
if [[ "$OS" =~ (ubuntu|debian|mint) ]]; then
    apt update && apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir krb5-user chrony || exit 2
    PAM_FILE="/etc/pam.d/common-session"
elif [[ "$OS" =~ (centos|rhel|almalinux|rocky) ]]; then
    yum install -y realmd sssd adcli samba-common samba-common-tools oddjob oddjob-mkhomedir krb5-workstation chrony || exit 3
    PAM_FILE="/etc/pam.d/system-auth"
else
    echo "Unsupported distribution."
    exit 4
fi

### ----------- Configure DNS ----------- ###
echo "Configuring persistent DNS..."
resolved_dns=$(echo "$DNS_SERVERS" | tr ',' ' ')
if [ -f /etc/systemd/resolved.conf ]; then
    sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
    sed -i '/^#\?DNS=/d' /etc/systemd/resolved.conf
    echo "DNS=$resolved_dns" >> /etc/systemd/resolved.conf
    systemctl restart systemd-resolved
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    echo "DNS configured via systemd-resolved"
else
    echo "nameserver $(echo $DNS_SERVERS | cut -d',' -f1)" > /etc/resolv.conf
    echo "DNS set in /etc/resolv.conf only"
fi

### ----------- Configure NTP (chrony) ----------- ###
echo "Configuring chrony NTP client..."
cat > /etc/chrony/chrony.conf <<EOF
server $NTP_SERVER iburst
maxdistance 16.0
driftfile /var/lib/chrony/chrony.drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

[[ "$OS" =~ (ubuntu|debian|mint) ]] && systemctl enable --now chrony
[[ "$OS" =~ (centos|rhel|almalinux|rocky) ]] && systemctl enable --now chronyd

chronyc makestep
echo "Time synchronized with $NTP_SERVER."

### ----------- Enable Required Services ----------- ###
systemctl enable --now sssd
systemctl enable --now realmd
systemctl enable --now oddjobd

### ----------- Join Domain ----------- ###
echo "Joining the AD domain $DOMAIN_NAME..."
realm join -U "$DOMAIN_USER" --computer-name "$HOSTNAME" "$DOMAIN_NAME" || { echo "Failed to join the domain."; exit 6; }

### ----------- Configure sssd ----------- ###
SSSD_CONF="/etc/sssd/sssd.conf"
[ -f "$SSSD_CONF" ] && chmod 600 "$SSSD_CONF"

grep -q "fallback_homedir" $SSSD_CONF || echo -e "\nfallback_homedir = /home/%u\noverride_homedir = /home/%u" >> $SSSD_CONF
if grep -q "use_fully_qualified_names" $SSSD_CONF; then
    sed -i 's/use_fully_qualified_names.*/use_fully_qualified_names = False/' $SSSD_CONF
else
    echo "use_fully_qualified_names = False" >> $SSSD_CONF
fi

systemctl restart sssd

### ----------- Configure PAM ----------- ###
if ! grep -q "pam_mkhomedir.so" "$PAM_FILE"; then
    echo "session required pam_mkhomedir.so skel=/etc/skel umask=0077" >> "$PAM_FILE"
fi

### ----------- Grant sudo access to domain groups ----------- ###
echo "%LinuxAdmins ALL=(ALL) ALL" > /etc/sudoers.d/domain_groups
echo "%domain\\ admins ALL=(ALL) ALL" >> /etc/sudoers.d/domain_groups
chmod 440 /etc/sudoers.d/domain_groups

### ----------- Cleanup Option ----------- ###
read -p "Do you want me to remove this script file after execution? (y/N): " ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    echo "Removing script $(basename "$0")..."
    rm -- "$0"
fi

echo ""
echo " All done! System is now domain-joined and ready."

