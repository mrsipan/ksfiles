auth  --useshadow  --enablemd5
bootloader --location=mbr
clearpart --all --initlabel
text
firewall --disable
firstboot --disable
keyboard us
lang en_US
selinux --disabled
skipx
timezone  America/New_York
install
zerombr
network --bootproto=dhcp --device=eth0 --onboot=on
reboot
url --url={{ installurl }}
logging --level=info

rootpw --iscrypted {{ root_passwd }}

# partition code
%include /tmp/partinfo

%pre
## Determine how many drives are available
set $(list-harddrives)
let numd=$#/2
d1=$1
d2=$3

cat << EOF > /tmp/partinfo
clearpart --drives=$d1 --initlabel
part / --fstype=ext3 --size=1024 --asprimary --grow
EOF

%end # end pre

%packages --excludedocs --nobase
bash
{{ kernel-type }}
#kernel-xen
#kernel
grub
e2fsprogs
passwd
policycoreutils
chkconfig
rootfiles
yum
acpid
dhclient
iputils
lvm2
man
lsof
screen
strace
which
sudo
postfix
at
ntp
xinetd
vixie-cron
smartmontools
wget
dmidecode
redhat-lsb
openssh
-kudzu
-iscsi-initiator-utils
-prelink
-setserial
-ed
-kbd
-udftools
-cups-libs
-selinux-policy
-selinux-policy-targeted
-freetype
-libX11
-xorg-x11-filesystem
-NetworkManager
%end

%post

# Disable stock definitions
#mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.disabled
mv /etc/yum.repos.d/CentOS-Media.repo /etc/yum.repos.d/CentOS-Media.repo.disabled
mv /etc/yum.repos.d/CentOS-Debuginfo.repo /etc/yum.repos.d/CentOS-Debuginfo.repo.disabled
mv /etc/yum.repos.d/CentOS-Vault.repo /etc/yum.repos.d/CentOS-Vault.repo.disabled

# Enable services
services="ntpd
          sshd
          xinetd
          syslog-ng
          postfix
          network
          crond"

for service in $services; do
  if test -f /etc/init.d/$service; then
    /sbin/chkconfig --add $service
    /sbin/chkconfig --level 2345 $service on
  fi
done

# Disable services if they exist
services="atd
          sendmail
          rpcidmapd
          portmap
          nfslock
          gpm
          nscd
          puppet
          syslog
          rsyslog
          smartd
          cups
          avahi-daemon
          yum-updatesd
          firstboot
          avahi-dnsconfd"

for service in $services; do
  if test -f /etc/init.d/$service; then
    /sbin/chkconfig --del $service
  fi
done

# Harden SSH
cat <<'EOF' >/etc/ssh/sshd_config
Protocol 2
SyslogFacility AUTHPRIV
#PermitRootLogin no
PermitRootLogin yes
#PasswordAuthentication no
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
GSSAPIAuthentication yes
GSSAPICleanupCredentials yes
UsePAM yes
X11Forwarding no
X11DisplayOffset 10
Subsystem sftp /usr/libexec/openssh/sftp-server
EOF

cat <<'EOF' >/etc/ssh/ssh_config
Host *
  ForwardAgent yes
  ForwardX11 yes
  GSSAPIAuthentication yes
  ForwardX11Trusted yes
EOF

# Add Dell Open Manage if this is a Dell machine
if test "`/usr/sbin/dmidecode -s system-manufacturer`" = 'Dell Inc.'; then
  wget -q -O - http://linux.dell.com/repo/hardware/latest/bootstrap.cgi | bash
  /usr/bin/yum clean all
  /usr/bin/yum -y install srvadmin-all dell_ft_install
fi

# Allow the use of sudo without a tty
sed -i 's/^Defaults.*requiretty$/#&/' /etc/sudoers

# disabling SELinux. This is mainly a centos-5.6 issue.
sed -i -e 's/\(^SELINUX=\).*$/\1disabled/' /etc/selinux/config

# sysctl.conf
cat <<'EOF' >/etc/sysctl.conf
# Controls source route verification
net.ipv4.conf.default.rp_filter = 1

# Controls the System Request debugging functionality of the kernel
kernel.sysrq = 0

# Respond to IPv4 ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 0
net.ipv6.icmp_echo_ignore_broadcasts = 0

# zim needs broadcasts pings
net.ipv4.icmp_echo_ignore_all = 0

# Do not route
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Reject source routing
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable SYN cookies
net.ipv4.tcp_syncookies = 1
net.ipv6.tcp_syncookies = 1

# Minimize kernel core dump space
kernel.core_uses_pid = 0

# Disable non-router ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.send_redirects = 0

# Increase ephemeral port availability
net.ipv4.ip_local_port_range = 22000 65535
net.ipv4.tcp_tw_reuse = 1
EOF

# clean yum local cache
/usr/bin/yum clean all

# extra scripts
{{ extra }}
%end
