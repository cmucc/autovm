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
PRESEED_MAIN_TEMPLATE=/root/creation_scripts/materials/debian7_preseed.cfg

# this root pubkey should be in a package! that'd be cool!
# TODO make a package with it! yeah! cclub-keyring, perhaps!
CCLUB_ROOT_PUBKEY=/root/creation_scripts/materials/cclub_root.pub

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
LASTOCTET=$(echo $VM_IP | cut -d . -f 4)

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

read -p "Continue (yes/no)? " choice
case "$choice" in 
  yes|YES ) echo "Okay, starting install.";;
  * ) exit;;
esac

echo "Connect with \"virsh console $VM_HOSTNAME\" elsewhere to watch \
the install progress."

# make the preseed.cfg
TMPDIR=$(mktemp -d)
cp $PRESEED_MAIN_TEMPLATE $TMPDIR/preseed.cfg 
sed -i "s/REPLACE_WITH_IP/$VM_IP/" $TMPDIR/preseed.cfg 
sed -i "s/REPLACE_WITH_HOSTNAME/$VM_HOSTNAME/" $TMPDIR/preseed.cfg
sed -i "s/REPLACE_WITH_ROOTPW_HASH/$(echo $VM_ROOT_PASSWORD_HASH | sed -e 's/[\/&]/\\&/g')/" $TMPDIR/preseed.cfg

virt-install \
    --noautoconsole \
    --wait=-1 \
    --name=$VM_HOSTNAME \
    --vcpus=$NUMCPUS \
    --ram=$MEMORY \
    --disk size=$DISKSIZE,pool=default \
    --network bridge=br0,mac=$MAC_ADDRESS \
    --location=$DEBIAN_LOCATION \
    --extra-args="console=ttyS0" \
    --initrd-inject=$TMPDIR/preseed.cfg \
    --initrd-inject=$CCLUB_ROOT_PUBKEY

CCLUB_ROOT_PRVKEY=/root/secret/cclub_root
CCLUB_SECRETS=/root/creation_scripts/secret/
CCLUB_CLUBIFY_SCRIPT=/root/creation_scripts/clubify.sh

if [[ "$VM_CCLUB" == "yes" ]]; then
    "Waiting for VM to reboot before starting Clubification..."
    sleep 15
    # TODO this secret dir should live in AFS
    scp -o StrictHostKeyChecking=no -i $CCLUB_ROOT_PRVKEY -r $CCLUB_SECRETS root@$VM_IP:/root/
    ssh -o StrictHostKeyChecking=no -i $CCLUB_ROOT_PRVKEY root@$VM_IP "bash -s" < $CCLUB_CLUBIFY_SCRIPT
fi
