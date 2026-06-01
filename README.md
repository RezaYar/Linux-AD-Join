# Linux Active Directory Domain Join Script

A fully automated Bash script for joining Linux systems to a Microsoft Active Directory domain with proper DNS, NTP, SSSD, PAM, and sudo configuration.

## Features

* Automatic operating system detection

  * Ubuntu
  * Debian
  * Linux Mint
  * CentOS
  * RHEL
  * AlmaLinux
  * Rocky Linux

* Installs all required packages automatically

* Configures persistent DNS settings

* Configures Chrony for time synchronization

* Adds Domain Controller entry to `/etc/hosts`

* Optional hostname change before joining the domain

* Joins Linux systems to Active Directory using `realmd`

* Configures SSSD authentication

* Creates user home directories automatically on first login

* Enables domain users to log in without fully qualified usernames

* Grants sudo access to predefined AD groups

* Optional self-removal after successful execution

---

## Requirements

Before running the script, update the configuration section:

```bash
DNS_SERVERS="192.168.0.1,192.168.0.2"
NTP_SERVER="192.168.0.1"
DOMAIN_NAME="YOUR_DOMAIN.local"
DOMAIN_USER="YOUR_USER"
DOMAIN_CONTROLLER_HOSTNAME="dc1.YOUR_DOMAIN.local"
DOMAIN_CONTROLLER_IP="192.168.0.1"
```

### Required Permissions

Run the script as root:

```bash
sudo bash domain-join.sh
```

---

## What the Script Does

### 1. Host Configuration

* Verifies Domain Controller entry in `/etc/hosts`
* Optionally changes the system hostname

### 2. Package Installation

Installs:

* realmd
* sssd
* adcli
* samba tools
* oddjob
* chrony
* kerberos packages

### 3. DNS Configuration

Configures persistent DNS settings using:

* systemd-resolved (when available)
* `/etc/resolv.conf` fallback

### 4. Time Synchronization

Configures Chrony and synchronizes time with the specified NTP server.

### 5. Active Directory Join

Joins the machine to the specified Active Directory domain:

```bash
realm join -U DOMAIN_USER DOMAIN_NAME
```

### 6. SSSD Configuration

Automatically configures:

```ini
fallback_homedir = /home/%u
override_homedir = /home/%u
use_fully_qualified_names = False
```

This allows users to log in using:

```text
username
```

instead of:

```text
username@domain.local
```

### 7. Home Directory Creation

Creates home directories automatically on first login using:

```text
pam_mkhomedir.so
```

### 8. Sudo Access

Adds sudo permissions for:

```text
LinuxAdmins
Domain Admins
```

through:

```text
/etc/sudoers.d/domain_groups
```

---

## Usage

Download and execute:

```bash
chmod +x domain-join.sh
sudo ./domain-join.sh
```

Follow the prompts:

1. Change hostname (optional)
2. Enter Active Directory credentials
3. Confirm script removal (optional)

---

## Supported Distributions

| Distribution | Supported |
| ------------ | --------- |
| Ubuntu       | ✅         |
| Debian       | ✅         |
| Linux Mint   | ✅         |
| AlmaLinux    | ✅         |
| Rocky Linux  | ✅         |
| CentOS       | ✅         |
| RHEL         | ✅         |

---

## Security Notes

* The script modifies system authentication settings.
* Review configuration values before execution.
* Ensure DNS and NTP settings point to trusted infrastructure.
* Use a dedicated domain join account when possible.

---

## Verification

Check domain membership:

```bash
realm list
```

Check user lookup:

```bash
id username
```

Check SSSD:

```bash
systemctl status sssd
```

Check Kerberos:

```bash
klist
```

---

## License

MIT License

---

## Author

Infrastructure & Security Automation Script

Designed to simplify Linux-to-Active Directory integration in enterprise environments.
