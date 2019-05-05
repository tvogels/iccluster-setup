#!/bin/bash

touch /root/ldap_setup_is_done.txt  # to make sure we don't run this twice

apt-get update

#########################################
# Install LDAP + Autmount
apt-get install sssd libpam-sss libnss-sss sssd-tools tcsh nfs-common -y
wget http://install.iccluster.epfl.ch/scripts/it/sssd/sssd.conf -O /etc/sssd/sssd.conf
chmod 0600 /etc/sssd/sssd.conf
sed -i 's|simple_allow_groups = IC-IT-unit|simple_allow_groups = IC-IT-unit,MLO-unit,mlologins|g' /etc/sssd/sssd.conf
sed -i 's|nis|ldap|' /etc/nsswitch.conf
echo "session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session

#PAM Mount
apt-get install -y libpam-mount cifs-utils ldap-utils
# Backup
cp /etc/security/pam_mount.conf.xml /etc/security/pam_mount.conf.xml.orig
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.orig
cd /
wget -P / install.iccluster.epfl.ch/scripts/it/pam_mount.tar.gz
tar xzvf pam_mount.tar.gz
rm -f /pam_mount.tar.gz
# Custom Template
wget install.iccluster.epfl.ch/scripts/mlo/template_.pam_mount.conf.xml -O /etc/security/.pam_mount.conf.xml
echo manual | sudo tee /etc/init/autofs.override
echo "unix" >> /var/lib/pam/seen
pam-auth-update --force --package
sed -i.bak '/and here are more per-package modules/a auth    optional      pam_exec.so /usr/local/bin/login.pl common-auth' /etc/pam.d/common-auth
service sssd restart

export DEBIAN_FRONTEND=noninteractive
echo "force-confold" >> /etc/dpkg/dpkg.cfg
echo "force-confdef" >> /etc/dpkg/dpkg.cfg
echo "SERVER_GID=164045" >>  /etc/default/ceph
apt-get install -y ceph-common
