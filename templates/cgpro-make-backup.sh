#!/bin/bash
# usage: sudo -E cgpro-make-backup.sh [aes]
# Create CommuniGate Pro mail backups
# ansible-managed
#set -x

cgpro_dir="{{ cgpro_dir }}"
tar_dir="{{ ansible_user_dir }}"
owner_gid="{{ ansible_user_uid }}:{{ ansible_user_gid }}"

mail_subdir=Accounts/ivandeex.macnt

timestamp=$(date '+%Y%m%d')

cd $cgpro_dir

tar -cpf $tar_dir/cgpro-data.${timestamp}.tar \
    . \
    --exclude "$mail_subdir/*.mbox" \
    --exclude "./Queue/*.tmp" \
    --exclude "./Submitted/*.tmp" \
    --exclude "./ProcessID"

find . -name "*.mbox"  -print0 | xargs -0 \
 tar -cpf $tar_dir/cgpro-mail.${timestamp}.tar \
    --exclude "Archive*.*" \
    --exclude "Box.*"

find ./$mail_subdir \
     \( -name "Archive*.*" \
     -o -name "Box.*" \) \
     -print0 | xargs -0 \
 tar -cpf $tar_dir/cgpro-bigmail.${timestamp}.tar

chown $owner_gid $tar_dir/cgpro-*.${timestamp}.tar

if [ "$1" = "aes" ]; then
    cd $tar_dir
    for tar in cgpro-*.${timestamp}.tar ; do
        gz-encrypt.sh $tar
        rm -f $tar
        chown $owner_gid $tar.gz.aes
    done
fi
