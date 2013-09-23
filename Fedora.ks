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
network --bootproto=dhcp --device=eth0 --onboot=on --hostname={{ hostname }}
#reboot
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
part / --fstype=ext4 --size=1024 --asprimary --grow
EOF

%end #%pre


%packages --excludedocs --nobase --ignoremissing
bash
kernel
e2fsprogs
passwd
policycoreutils
chkconfig
rootfiles
yum
dhclient
iputils
lvm2
man
lsof
strace
which
sudo
at
cronie
smartmontools
wget
dmidecode
openssh
selinux-policy
chrony
-sendmail
-kudzu
-iscsi-initiator-utils
-prelink
-setserial
-ed
-kbd
-udftools
-cups-libs
-freetype
-libX11
-xorg-x11-filesystem

%end #%packages


# Harden sshd, permit root login the first time
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


%post --log=/root/kspost.log

# run in subshell
(
{{ extra_post }}
)

%end #%post