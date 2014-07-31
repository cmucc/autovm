#!/bin/bash

# add our repo and keys
echo "deb http://debian.club.cc.cmu.edu/debian/ wheezy-cclub contrib" >> /etc/apt/sources.list 
aptitude update 
aptitude install cclub-keyring <<< "Yes" 
aptitude update 

# add our configuration
aptitude install -y cclub-debconf-settings 

# some configuration for packages that has not yet made it into cclub-debconf-settings
debconf-set-selections <<EOF
nslcd nslcd/ldap-uris string ldap://ldap1.club.cc.cmu.edu/ ldap://ldap2.club.cc.cmu.edu/ ldap://ldap3.club.cc.cmu.edu/
nslcd nslcd/ldap-base string dc=club,dc=cc,dc=cmu,dc=edu
nslcd nslcd/ldap-auth-type select none
nslcd nslcd/ldap-starttls boolean false

libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group
libpam-runtime libpam-runtime/profiles multiselect krb5, unix, afs-session

openafs-client openafs-client/cachesize string 100000
EOF

# upgrade
aptitude -y dist-upgrade 

# and finally, install the necessary club packages
# this is a minimal set - zsh, tcsh are included because they are some
# people's default shell, and vim and emacs because some people don't
# know how to use TRAMP
DEBIAN_FRONTEND=noninteractive aptitude install -y build-essential \
heimdal-clients libpam-heimdal libnss-ldapd sudo vim emacs zsh tcsh \
openafs-client libpam-afs-session

echo '%wheel  ALL=(ALL)       ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
