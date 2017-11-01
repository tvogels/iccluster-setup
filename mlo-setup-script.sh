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

#########################################
# Install LDAP + Autmount
curl -s http://install.iccluster.epfl.ch/scripts/it/ldapAutoMount.sh  >> ldapAutoMount.sh ; chmod +x ldapAutoMount.sh ; ./ldapAutoMount.sh
echo "+ : root pagliard (mlologins) (MLO-unit) (IC-IT-unit): ALL" >> /etc/security/access.conf
echo "- : ALL : ALL" >> /etc/security/access.conf
systemctl stop autofs
systemctl disable autofs
echo "session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session


#########################################
#PAM Mount
apt-get install -y libpam-mount cifs-utils ldap-utils
# Backup
cp /etc/security/pam_mount.conf.xml /etc/security/pam_mount.conf.xml.orig
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.orig
cd /
wget -P / install.iccluster.epfl.ch/scripts/it/pam_mount.tar.gz
tar xzvf pam_mount.tar.gz
rm -f /pam_mount.tar.gz
sed -i.bak '/and here are more per-package modules/a auth    optional      pam_exec.so /usr/local/bin/login.pl common-auth' /etc/pam.d/common-auth
# Custom Template
wget install.iccluster.epfl.ch/scripts/mlo/template_.pam_mount.conf.xml -O /etc/security/.pam_mount.conf.xml

echo manual | sudo tee /etc/init/autofs.override

echo "unix" >> /var/lib/pam/seen
pam-auth-update --force --package

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



#########################################
# Clean /etc/rc.local
echo '#!/bin/sh -e' > /etc/rc.local
echo 'sleep 30 # wait for ldap service to be started' >> /etc/rc.local

#########################################
# sudo for Lab users !!! INSTALL APRES REBOOT !!!
echo '
FLAGSUDO="/var/log/firstboot.sudo.log"
if [ ! -f $FLAGSUDO ]; then
  curl -s http://install.iccluster.epfl.ch/scripts/it/lab2sudoers.sh  >> /tmp/lab2sudoers.sh ; chmod +x /tmp/lab2sudoers.sh; /tmp/lab2sudoers.sh mlologins ;
  touch $FLAGSUDO
fi
' >> /etc/rc.local

#########################################
# add user to specific group !!! INSTALL APRES REBOOT !!!
echo '
FLAGDOCKER="/var/log/firstboot.group.log"
if [ ! -f $FLAGDOCKER ]; then
  curl -s http://install.iccluster.epfl.ch/scripts/it/lab2group.sh  >> /tmp/lab2group.sh ; chmod +x /tmp/lab2group.sh; /tmp/lab2group.sh mlologins docker ;
  touch $FLAGDOCKER
fi
' >> /etc/rc.local

#########################################
# Install CUDA !!! INSTALL APRES REBOOT !!!
echo '
FLAG="/var/log/firstboot.cuda.log"
if [ ! -f $FLAG ]; then
  touch $FLAG
  curl http://install.iccluster.epfl.ch/scripts/soft/cuda/cuda_8.0.61.sh  >> /tmp/cuda.sh ; chmod +x /tmp/cuda.sh; bash -x /tmp/cuda.sh >> /var/log/install.cuda.log
fi
' >> /etc/rc.local

echo 'exit 0' >> /etc/rc.local
chmod +x /etc/rc.local

#########################################
# export LC_ALL
export LC_ALL=C

########################################
## Install Docker
curl -sSL https://get.docker.com/ | sh

## Install Docker-compose
curl -L https://github.com/docker/compose/releases/download/1.16.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
export PATH="/usr/local/bin/:$PATH"

#########################################
# Some basic necessities
apt-get install -y emacs tmux htop mc git subversion vim iotop dos2unix wget screen zsh software-properties-common pkg-config zip g++ zlib1g-dev unzip strace vim-scripts

#########################################
# Compiling related
apt-get install -y gdb cmake cmake-curses-gui autoconf gcc gcc-multilib g++-multilib

#########################################
# Python related stuff
apt-get install -y python-pip python-dev python-setuptools build-essential python-numpy python-scipy python-matplotlib ipython ipython-notebook python-pandas python-sympy python-nose python3 python3-pip python3-dev python-wheel python3-wheel python-boto

#########################################
# Python packages using pip
# ipython in apt-get is outdated
pip install ipython --upgrade

#######################################
# MATLAB 9.1 (2016b)
# curl -s http://install.iccluster.epfl.ch/scripts/soft/matlab/R2016b.sh  >> R2016b.sh; chmod +x R2016b.sh; ./R2016b.sh

#########################################
# bazel
## JAVA
add-apt-repository ppa:webupd8team/java -y
apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
apt-get install -y oracle-java8-installer
## Next
wget -P /tmp https://github.com/bazelbuild/bazel/releases/download/0.4.1/bazel-0.4.1-installer-linux-x86_64.sh
chmod +x /tmp/bazel-0.4.1-installer-linux-x86_64.sh
/tmp/bazel-0.4.1-installer-linux-x86_64.sh

#########################################
# python3 as default
# update-alternatives --install /usr/bin/python python /usr/bin/python3 2
# update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 2

#########################################
# Install TensorFlow GPU version.
# TENSORFLOW_VERSION=1.2.1
# pip --no-cache-dir install \
#        http://storage.googleapis.com/tensorflow/linux/gpu/tensorflow_gpu-${TENSORFLOW_VERSION}-cp27-none-linux_x86_64.whl

#######################################
# ANACONDA
wget http://install.iccluster.epfl.ch/scripts/soft/anaconda/Anaconda3-4.4.0-Linux-x86_64.sh -O /tmp/Anaconda3-4.4.0-Linux-x86_64.sh
chmod +x /tmp/Anaconda3-4.4.0-Linux-x86_64.sh
/tmp/Anaconda3-4.4.0-Linux-x86_64.sh -b -p /opt/anaconda3/
echo PATH="/opt/anaconda3/bin:$PATH"  > /etc/environment
export PATH="/opt/anaconda3/bin:$PATH"

#######################################
# TORCH
curl -s https://raw.githubusercontent.com/torch/ezinstall/master/install-deps | bash
git clone https://github.com/torch/distro.git /opt/torch --recursive
cd /opt/torch; yes | ./install.sh
echo PATH="/opt/torch/install/bin:$PATH" > /etc/environment

#######################################
# PyTorch
conda install -y pytorch torchvision cuda80 -c soumith
# git clone https://github.com/pytorch/pytorch.git /opt/PyTorch --recursive
# cd /opt/PyTorch ; python setup.py install

# Tensorflow
conda install -y -c anaconda tensorflow-gpu

# install other necessary packages
conda install -y nltk tpdm ipdb

	;;
"CentOS-Linux") echo $DISTRIB
    ;;
*) echo "Invalid OS: " $DISTRIB
   ;;
esac

rm -- "$0"
