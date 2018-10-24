#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

##### CHECK OS #####
lowercase(){
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

OS=`lowercase \`uname\``
KERNEL=`uname -r`
MACH=`uname -m`

if [ "{$OS}" == "windowsnt" ]; then
    OS=windows
elif [ "{$OS}" == "darwin" ]; then
    OS=mac
else
    OS=`uname`
    if [ "${OS}" = "SunOS" ] ; then
        OS=Solaris
        ARCH=`uname -p`
        OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
    elif [ "${OS}" = "AIX" ] ; then
        OSSTR="${OS} `oslevel` (`oslevel -r`)"
    elif [ "${OS}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DistroBasedOn='RedHat'
            DIST=`cat /etc/redhat-release |sed s/\ release.*//`
            PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/SuSE-release ] ; then
            DistroBasedOn='SuSe'
            PSUEDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            DistroBasedOn='Mandrake'
            PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
            DistroBasedOn='Debian'
            DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
            PSUEDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
            REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
        fi
        OS=`lowercase $OS`
        DistroBasedOn=`lowercase $DistroBasedOn`
        readonly OS
        readonly DIST
        readonly DistroBasedOn
        readonly PSUEDONAME
        readonly REV
        readonly KERNEL
        readonly MACH
    fi

fi

## Check OS and do the install 
# Remove spaces
DISTRIB=${DIST// /-} 					

# Check OS
case "$DISTRIB" in
"Ubuntu") echo $DISTRIB

#########################################
apt-get update

curl -s http://install.iccluster.epfl.ch/scripts/icitsshkeys.sh >> icitsshkeys.sh ; chmod +x icitsshkeys.sh; ./icitsshkeys.sh
#########################################
# Install LDAP + Autmount
apt-get install sssd libpam-sss libnss-sss sssd-tools tcsh nfs-common -y
mkdir -p /etc/openldap/cacerts
wget http://rauth.epfl.ch/Quovadis_Root_CA_2.pem -O /etc/openldap/cacerts/quovadis.pem
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

#########################################
# Create /scratch
curl -s http://install.iccluster.epfl.ch/scripts/it/scratchVolume.sh  >> scratchVolume.sh ; chmod +x scratchVolume.sh ; ./scratchVolume.sh
chmod 775 /scratch
chown root:MLO-unit /scratch


#########################################
# Create and mount mlodata1 (you can manage the access from groups.epfl.ch)
mkdir /mlodata1
echo "#mlodata1" >> /etc/fstab
echo "ic1files.epfl.ch:/ic_mlo_1_files_nfs/mlodata1      /mlodata1     nfs     soft,intr,bg 0 0" >> /etc/fstab

#Mount during the setup
mount -a

#########################################
# Install CUDA !!! INSTALL APRES REBOOT !!!
echo '#!/bin/sh -e' > /etc/rc.local

echo '
FLAG="/var/log/firstboot.cuda.log"
if [ ! -f $FLAG ]; then
	touch $FLAG
        curl -s http://install.iccluster.epfl.ch/scripts/soft/cuda/cuda_9.2.88_396.26.sh  >> /tmp/cuda.sh ; chmod +x /tmp/cuda.sh; /tmp/cuda.sh;
fi' >> /etc/rc.local

echo '
FLAGSCRATCH="/var/log/firstboot.scratch.log"
if [ ! -f $FLAGSCRATCH ]; then
        touch $FLAGSCRATCH
	chown root:MLO-unit /scratch
fi' >> /etc/rc.local

echo 'exit 0' >> /etc/rc.local
chmod +x /etc/rc.local

#########################################
# Some basic necessities
apt-get install -y emacs tmux htop mc git subversion vim iotop dos2unix wget screen zsh software-properties-common pkg-config zip g++ zlib1g-dev unzip strace vim-scripts virtualenv
#########################################
# Compiling related
apt-get install -y gdb cmake cmake-curses-gui autoconf gcc gcc-multilib g++-multilib

#########################################
# Python related stuff
apt-get install -y python-pip python-dev python-setuptools build-essential python-numpy python-scipy python-matplotlib python-pandas python-sympy python-nose python3 python3-pip python3-dev python-wheel python3-wheel python-boto

pip install ipython[all]

wget https://repo.continuum.io/archive/Anaconda3-5.0.1-Linux-x86_64.sh -P /tmp; chmod +x /tmp/Anaconda3-5.0.1-Linux-x86_64.sh; /tmp/Anaconda3-5.0.1-Linux-x86_64.sh -b -p /opt/anaconda3
echo PATH="/opt/anaconda3/bin:$PATH"  > /etc/environment
export PATH="/opt/anaconda3/bin:$PATH"

########################################
## Install Docker
apt-get install -y docker.io
# docker-compose
pip install -U docker-compose

#########################################
# bazel
## JAVA
add-apt-repository ppa:webupd8team/java -y
apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections
apt-get install -y oracle-java8-installer
echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list
curl https://bazel.build/bazel-release.pub.gpg | apt-key add -
apt-get update 
apt-get -y install bazel

#######################################
# TORCH
curl -s https://raw.githubusercontent.com/torch/ezinstall/master/install-deps | bash
git clone https://github.com/torch/distro.git /opt/torch --recursive
cd /opt/torch; yes | ./install.sh
echo PATH="/opt/torch/install/bin:$PATH" > /etc/environment

# PyTorch
conda install -y pytorch torchvision cuda80 -c soumith
# PyTorch 4
#pip3 install http://download.pytorch.org/whl/cu91/torch-0.4.0-cp36-cp36m-linux_x86_64.whl
#pip3 install torchvision
/opt/anaconda3/bin/conda install pytorch torchvision -c pytorch -y

# Tensorflow
conda install -y -c anaconda tensorflow-gpu

# Renganathan Suresh Nikhil Krishna <nikhil.renganathansuresh@epfl.ch>
/opt/anaconda3/bin/pip install tensorboardX

# Franceschi Jean-Yves <jean-yves.franceschi@epfl.ch>
/opt/anaconda3/bin/pip install fastdtw

# install other necessary packages
conda install -y nltk tpdm ipdb

# sudoers mlologins members
echo "%mlologins ALL=(ALL:ALL) ALL" > /etc/sudoers.d/mlologins

# Add users to docker group
curl -s http://install.iccluster.epfl.ch/scripts/it/lab2group.sh  >> /tmp/lab2group.sh ; chmod +x /tmp/lab2group.sh; /tmp/lab2group.sh mlologins docker 

# Service Account for GPU-Monitor
echo "mlo-gpu-monitor ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/mlo-gpu-monitor
#setup GUI for monitoring
#   https://github.com/ThomasRobertFr/gpu-monitor

# runuser -l mlo-gpu-monitor -c '/mlodata1/gpu-monitor/install_scripts/install.sh' >> /var/log/mlo.log

apt-get install -y nvidia-docker2=2.0.3+docker17.12.1-1 nvidia-container-runtime=2.0.0+docker17.12.1-1
apt-get install -y bc
usermod -a -G docker mlo-gpu-monitor
su -c "/mlodata1/gpu-monitor/scripts/install.sh" -s /bin/sh mlo-gpu-monitor

mkdir /mlo-container-scratch
su -c "cp /mlodata1/mlo.ceph.container.client.key /tmp" mlo-gpu-monitor
cp /tmp/mlo.ceph.container.client.key /etc/ceph/

mount -t ceph icadmin006,icadmin007,icadmin008:/mlo-scratch /mlo-container-scratch -o rw,relatime,name=mlo,secretfile=/etc/ceph/mlo.ceph.container.client.key,acl,noatime,nodiratime

export DEBIAN_FRONTEND=noninteractive
echo "force-confold" >> /etc/dpkg/dpkg.cfg
echo "force-confdef" >> /etc/dpkg/dpkg.cfg
echo "SERVER_GID=164045" >>  /etc/default/ceph
apt-get install -y ceph-common


	;;
"CentOS-Linux") echo $DISTRIB
    ;;
*) echo "Invalid OS: " $DISTRIB
   ;;
esac

rm -- "$0"
