#! /bin/bash
# install deps
apt update && apt install -y sshpass

# get version
VERSION="$(grep -R "CONFIG_VERSION_NUMBER" /charlinhos*/.config  | awk -F[\"] '{print $2}')"

# send to sftp
{
echo -mkdir Files/hlk7628/$VERSION
echo -cd Files/hlk7628/$VERSION
echo -put /output/charlinhos-sysupgrade.bin charlinhos-sysupgrade.bin
} | sshpass -v -p $SFTP_PASSWORD sftp -o StrictHostKeyChecking=no $SFTP_USER@$SFTP_HOST
