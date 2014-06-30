#!/bin/bash
# this script is really just a lame wrapper around virt-install
set -o errexit
set -o nounset

#VM_HOSTNAME=
#VM_IP=128.237.157.
#VM_CCLUB=yes
#VM_ROOT_PASSWORD_HASH=$(printf "password" | mkpasswd -s -m md5)
NUMCPUS=1
MEMORY=512
DISKSIZE=8

DEBIAN_LOCATION=http://ftp.us.debian.org/debian/dists/wheezy/main/installer-amd64/
PRESEED_MAIN_TEMPLATE=/root/creation_scripts/vmtemplates/debian7_preseed.cfg
PRESEED_CCLUB=/root/creation_scripts/vmtemplates/debian7_preseed_cclub.cfg
CCLUB_APT_PUBKEY=/root/creation_scripts/vmtemplates/cclub_apt_pubkey
PRESEED_CCLUB_SECRETS=/root/creation_scripts/vmtemplates/debian7_preseed_cclub_secrets.cfg

while [ -z "${VM_HOSTNAME:-}" ]; do
    read -e -p "VM hostname: " VM_HOSTNAME
done

while [ -z "${VM_IP:-}" ]; do
    read -e -i "128.237.157." -p "VM IP address: " VM_IP
    LASTOCTET=$(echo $VM_IP | cut -d . -f 4)
    if [[ ! "$LASTOCTET" =~ ^1?[0-9][0-9]$ ]]; then
	echo "You've entered the IP wrong, giving \"$LASTOCTET\" as the last octet." 
	unset VM_IP
    fi
done

MAC_ADDRESS=00:00:80:ed:9d:$(printf '%x' $LASTOCTET)

while [ -z "${VM_CCLUB:-}" ]; do
    read -e -p "Clubify this VM (yes/no)? " VM_CCLUB
done

while [ -z "${VM_ROOT_PASSWORD_HASH:-}" ]; do
    echo "Enter a root password:"
    echo "WARNING! WILL BE DISPLAYED! HIDE YO KIDS, HIDE YO TERMINAL!"
    # displayed deliberately because it would be annoying as HECK to typo
    read -e VM_PASSWORD
    VM_ROOT_PASSWORD_HASH=$(echo "$VM_PASSWORD" | mkpasswd -s -m md5)
    unset VM_PASSWORD
done

echo "Now creating a VM with:"
echo "$NUMCPUS CPU cores"
echo "$MEMORY MB of RAM"
echo "$DISKSIZE GB of main disk"
echo "$VM_HOSTNAME as a hostname"
echo "$VM_IP as an IP address"
echo "$MAC_ADDRESS as a MAC address"
echo "$VM_CCLUB to being Clubified"
echo "PLEASE NOTE: You can disconnect from the VM console with Ctrl-]
during the install, and reconnect with \"virsh console $VM_HOSTNAME\",
so you don't have to be bored watching it."

read -p "Continue (yes/no)? " choice
case "$choice" in 
  yes|YES ) echo "Okay, starting install.";;
  * ) exit;;
esac

# make the preseed.cfg
TMPDIR=$(mktemp -d)
cp $PRESEED_MAIN_TEMPLATE $TMPDIR/preseed.cfg 
sed -i "s/REPLACE_WITH_IP/$VM_IP/" $TMPDIR/preseed.cfg 
sed -i "s/REPLACE_WITH_HOSTNAME/$VM_HOSTNAME/" $TMPDIR/preseed.cfg
sed -i "s/REPLACE_WITH_ROOTPW_HASH/$VM_ROOT_PASSWORD_HASH/" $TMPDIR/preseed.cfg

if [[ "$VM_CCLUB" == "yes" ]]; then
    cp $PRESEED_CCLUB $TMPDIR/extra_preseed.cfg 
    cp $PRESEED_CCLUB_SECRETS $TMPDIR/cclub_secrets.cfg
fi

exec virt-install \
    --name=$VM_HOSTNAME \
    --vcpus=$NUMCPUS \
    --ram=$MEMORY \
    --disk size=$DISKSIZE,pool=default \
    --network bridge=br0,mac=$MAC_ADDRESS \
    --location=$DEBIAN_LOCATION \
    --extra-args="console=ttyS0" \
    --initrd-inject=$TMPDIR/preseed.cfg \
    --initrd-inject=$TMPDIR/extra_preseed.cfg \
    --initrd-inject=$TMPDIR/cclub_secrets.cfg \
    --initrd-inject=$CCLUB_APT_PUBKEY

