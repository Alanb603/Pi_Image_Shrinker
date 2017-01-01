#!/bin/bash
# Automatic Image file resizer
# Originally Written by SirLagz
# Editted and commented by Alan Burnham
strImgFile=$1

# Verify user is root
if [[ ! $(whoami) =~ "root" ]]; then
echo ""
echo "**********************************"
echo "*** This should be run as root ***"
echo "**********************************"
echo ""
exit
fi

# Verify variable is not zero lenth
if [[ -z $1 ]]; then
echo "Usage: ./autoresize.sh  /path/to/file.img"
exit
fi

# if file not (!) exists (-e) or (|| prevents command after pipe from executing if command before pipe fail$
# if [[ ! -e $1 || ! $(file $1) =~ "x86" || ! $(file $1) =~ "x83" || ! $(file $1) =~ "xe"  ]]; then
if [[ ! -e $1 || ! $(file $1) =~ "x83" ]]; then
echo "Error : Not an image file, or file doesn't exist"
exit
fi

# print/output machine parsable Bytes
partinfo=`parted -m $1 unit B print`
# Get the ext4 (non-boot) partition number
# search partinfo for ext4
# use awk to parse the line containing ext4
# awk parses line into sections using ":" as a separator
# awk prints the first section which is the partition number
partnumber=`echo "$partinfo" | grep ext4 | awk -F: ' { print $1 } '`

# Get the byte starting position for the ext partition
# search partinfo for ext4
# use awk to parse the line containing ext4
# awk parses line into sections using ":" as a separator
# awk prints the second section which is the starting position of the partition containing ext4
# awk substr well explained here: http://www.linuxnix.com/awk-substr-function-explained-with-examples/
# substr prints section 2 starting at position 1 and ending with the length of the string minus 1 character$
partstart=`echo "$partinfo" | grep ext4 | awk -F: ' { print substr($2,1,length($2)-1) } '`


# setup loopback device using first available loop device show the dev/loop file
# use partstart as offset from beginning of disk
loopback=`losetup -f --show -o $partstart $1`

# force file system check on the loopback device and assume yes to any responses
e2fsck -f -y $loopback

# use resize2fs utility to find minimum filesystem size in 4K blocks (4096 bytes)
# awk parses line into sections using ": " as a separator and print the second section
minsize=`resize2fs -P $loopback | awk -F': ' ' { print $2 } '`

# add 1000 4K blocks to minimum size(2000*4096 bytes = ~7.8MB) for safety margin
# pipe calculation to bc (bash doesn't do it's own calculations)
minsize=`echo $minsize+2000 | bc`
resize2fs -p $loopback $minsize
sleep 1
losetup -d $loopback

# Multiply block count by 4096 to convert to bytes for new partition size
partnewsize=`echo "$minsize * 4096" | bc`

# Calculate partition ending position
newpartend=`echo "$partstart + $partnewsize" | bc`

# remove partition 2 label from partition table
part1=`parted $1 rm 2`

# recreate partition 2 with smaller size in partition table
part2=`parted $1 unit B mkpart primary $partstart $newpartend`


# get free bytes to trim from end of img file
endresult=`parted -m $1 unit B print free | tail -1 | awk -F: ' { print substr($2,1,length($2)-1) } '`
truncate -s $endresult $1


