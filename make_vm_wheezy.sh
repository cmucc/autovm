#!/bin/bash
set -o errexit
set -o nounset

AUTOVM_DIR=/afs/club.cc.cmu.edu/service/autovm
CCLUB_SECRETS=$AUTOVM_DIR/secret/

#VM_HOSTNAME=
#VM_CCLUB=yes
#VM_ROOT_PASSWORD_HASH=$(printf "password" | mkpasswd -s -m md5)
NUMCPUS=1
MEMORY=512
DISKSIZE=8

while [ -z "${VM_HOSTNAME:-}" ]; do
    read -e -p "VM hostname: " VM_HOSTNAME
done

while [ -z "${VM_CCLUB:-}" ]; do
    read -e -p "Clubify this VM (yes/no)? " VM_CCLUB
done

while [ -z "${VM_ROOT_PASSWORD_HASH:-}" ]; do
    echo "Enter a root password:"
    echo "WARNING! WILL BE DISPLAYED! HIDE YO KIDS, HIDE YO TERMINAL!"
    read -e VM_PASSWORD
    VM_ROOT_PASSWORD_HASH=$(echo "$VM_PASSWORD" | mkpasswd -s -m md5)
    unset VM_PASSWORD
done

echo "You have reached the point of no return."
echo "Further progress will make changes to the state of the world!"
echo "If you want to be non-interactive past here, make sure you have"
echo "run \"kinit \$YOUR_USERNAME/admin\" and \"aklog\"."
read -p "Will now attempt to claim an IP, continue (yes/no)? " choice
case "$choice" in 
  yes|YES ) echo "Okay";;
  * ) exit 1;;
esac
VM_IP=$($AUTOVM_DIR/netreg/get_ip.sh $VM_HOSTNAME)

#### Create VM
DEBIAN_LOCATION=http://ftp.us.debian.org/debian/dists/wheezy/main/installer-amd64/
PRESEED_MAIN_TEMPLATE=$AUTOVM_DIR/materials/debian7_preseed.cfg
CCLUB_ROOT_PUBKEY=$AUTOVM_DIR/materials/cclub_root.pub

LASTOCTET=$(echo $VM_IP | cut -d . -f 4)
MAC_ADDRESS=00:00:80:ed:9d:$(printf '%x' $LASTOCTET)

echo "Now creating a VM with:"
echo "$NUMCPUS CPU cores"
echo "$MEMORY MB of RAM"
echo "$DISKSIZE GB of main disk"
echo "$VM_HOSTNAME as a hostname"
echo "$VM_IP as an IP address"
echo "$MAC_ADDRESS as a MAC address"
echo "$VM_CCLUB to being Clubified"
echo "Connect with \"virsh console $VM_HOSTNAME\" elsewhere to watch \
the install progress."

# make the preseed.cfg
TMPDIR=$(mktemp -d)
cp $PRESEED_MAIN_TEMPLATE $TMPDIR/preseed.cfg 
sed -i "s/REPLACE_WITH_IP/$VM_IP/" $TMPDIR/preseed.cfg 
sed -i "s/REPLACE_WITH_HOSTNAME/$VM_HOSTNAME/" $TMPDIR/preseed.cfg
# gotta escape the hash - it could have character combos special to sed in it
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

#### Perform clubification
CCLUB_ROOT_PRVKEY=$CCLUB_SECRETS/cclub_root
CCLUB_CLUBIFY_SCRIPT=$AUTOVM_DIR/clubify_wheezy.sh

if [[ "$VM_CCLUB" == "yes" ]]; then
    echo "Waiting for VM to reboot before starting Clubification..."
    sleep 30
    scp -o StrictHostKeyChecking=no -i $CCLUB_ROOT_PRVKEY -r $CCLUB_SECRETS root@$VM_IP:/root/
    ssh -o StrictHostKeyChecking=no -i $CCLUB_ROOT_PRVKEY root@$VM_IP "bash -s" < $CCLUB_CLUBIFY_SCRIPT
fi

echo "Done!"
