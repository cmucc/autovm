#!/bin/bash

# add our repo and keys
echo "deb http://debian.club.cc.cmu.edu/debian/ wheezy-cclub contrib" >> /etc/apt/sources.list 
aptitude update 
aptitude install cclub-keyring <<< "Yes" 
aptitude update 

# add our configuration
aptitude install cclub-debconf-settings 

# some configuration for packages that hasn't yet made it into cclub-debconf-settings
debconf-set-selections <<EOF
nslcd nslcd/ldap-base string dc=club,dc=cc,dc=cmu,dc=edu
nslcd nslcd/ldap-starttls boolean false
nslcd nslcd/ldap-uris string ldap://128.237.157.19/
nslcd nslcd/ldap-auth-type select simple
nslcd nslcd/ldap-binddn string cn=read,dc=club,dc=cc,dc=cmu,dc=edu
nslcd nslcd/ldap-bindpw password $(cat /root/secret/ldap-read-password)

libnss-ldapd libnss-ldapd/nsswitch multiselect passwd, group
libpam-runtime libpam-runtime/profiles multiselect krb5, unix, afs-session

openafs-client openafs-client/cachesize string 50000
EOF

# upgrade
aptitude dist-upgrade 

# and finally, install the necessary club packages
# this is a minimal set - zsh is included because it's some people's
# default shell, and vim and emacs because some people don't know how
# to use TRAMP
DEBIAN_FRONTEND=noninteractive aptitude install -y build-essential \
heimdal-clients libpam-heimdal libnss-ldapd sudo vim emacs zsh \
openafs-client libpam-afs-session
