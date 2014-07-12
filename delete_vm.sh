#!/bin/bash
set -o errexit
set -o nounset

print_usage()
{
echo "Usage: delete_vm.sh shortname"
echo "Destroys, undefines, and removes the host record for the given VM"
}

### Validate arguments
# check whether $1 is blank
if [ -z "${1:-}" ]; then 
    print_usage
    echo "You did not provide a shortname"
    exit 1
fi

SHORTNAME=$1
# check whether $1 is legal
if [[ "$SHORTNAME" =~ [^a-zA-Z0-9] ]]; then 
    print_usage
    echo "Shortname is illegal under ALMIGHTY CCLUB LAW"
    echo "So you probably typo'd it"
    exit 1
fi

### Get Kerberos and AFS permissions
# check for admin Kerberos token 
# if not there:
if [ -z "$(klist | grep admin)" ]; then
    echo "Run something like \"kinit $USER/admin\", with your Kerberos username."
    exit 1
fi

if ! aklog club.cc.cmu.edu; then
    echo "Failed to get AFS token, do you have AFS?"
    exit 1
fi

## force power off the machine
virsh destroy $SHORTNAME

## remove the machine from libvirt's memory
virsh undefine $SHORTNAME --delete-all-storage

## remove the host record
DNS_FILE=/afs/club.cc.cmu.edu/service/dns/DB.club.cc.cmu.edu
sed -i "/^=$SHORTNAME.club.cc.cmu.edu:.*/d" $DNS_FILE

echo "Done!"
