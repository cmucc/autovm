#!/bin/bash
set -o nounset
set -o errexit

NETREG_INFO_DIR=/afs/club.cc.cmu.edu/service/autovm/netreg

print_usage()
{
echo "Usage: get_ip.sh shortname"
echo "Finds an IP address for shortname.club.cc.cmu.edu, registers it"
echo "by creating the DNS records, and outputs the IP address."
}

### Validate arguments
# check whether $1 is blank
if [ -z "${1:-}" ]; then 
    print_usage
    echo "You did not provide a shortname"
    exit 1
fi

# check whether $1 is legal
if [[ "$1" =~ [^a-zA-Z0-9] ]]; then 
    print_usage
    echo "Shortname is illegal under ALMIGHTY CCLUB LAW"
    exit 1
fi
SHORTNAME=$1

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

### Get unused IPs
UNUSED_LIST_FILE=$(mktemp)
# for each CClub IP

for i in {1..255}; do 
    IP=128.237.157.$i
    # if that IP has no reverse DNS
    if [ -z "$(dig +short -x $IP)" ]; then
	# put it in the candidate file
	echo "$IP" >> "$UNUSED_LIST_FILE"
    fi
    # slow down a little 
    # is this actually necessary?
    sleep .01
done  

### Get valid candidate list
PREREGGED_LIST_FILE=$NETREG_INFO_DIR/preregged

### Get the intersection of the two lists
# (this is the list of IPs that we might be able to use)

# comm requires input to be sorted
sort $UNUSED_LIST_FILE -o $UNUSED_LIST_FILE
sort $PREREGGED_LIST_FILE -o $PREREGGED_LIST_FILE
IP_LIST="$(comm -12 $PREREGGED_LIST_FILE $UNUSED_LIST_FILE)"

if [ -z $IP_LIST ]; then
    # something's not right... try looking at every IP, then
    IP_LIST="$(cat $PREREGGED_LIST_FILE)"
fi

try_register() 
{
    # REQUIRES: we already have admin Kerberos token and have aklog'd for administrator AFS perms
    cd /afs/club.cc.cmu.edu/service/dns/
    ./tinydns-edit DB.club.cc.cmu.edu DB.club.cc.cmu.edu~ add host $SHORTNAME.club.cc.cmu.edu $1
}

for IP in $IP_LIST;
do
    if (try_register $IP); then
	printf $IP
	exit 0
    fi
done

echo "Eh... it looks like there are no IPs available..."
echo "Might want to preregister some more and add them to:"
echo "$PREREGGED_LIST_FILE"
echo "Alternatively email sbaugh?"
exit 1
