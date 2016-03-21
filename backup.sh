#!/bin/bash
#
# A Bash script to backup mysql data to UKFast Vault
# Created 20_03_2016 : Sean Redmond
#
# Copyright (c) 2016, Sean Redmond
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted,
# provided that the above copyright notice and this permission notice appear in all copies
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
#
# Change Log
# 20_03_2016 - First Release
#

#Set Vars
CRYPT_KEY=/root/.vault.key
S3_BUCKET=
VAULT_ACCESS_KEY_ID=
VAULT_SECRET_ACCESS_KEY=
VAULT_HOST=vault.ecloud.co.uk
S3_EXTRA_ARGS="--limit-rate 50m"

#Unless you know what you are doing stop editing here!

#Set Vars
DATE_FORMAT="%F_%H-%M-%S"
WEEK=$(date -d "$(( $(date +%u) - 1 )) days ago" +%Y-%m-%d)
WEEK_DATE_FORMAT="[0-9]\{4\}\-[0-9]\{2\}\-[0-9]\{2\}$"
INNOBACKUP_ARGS="--encrypt=AES256 --encrypt-key-file=$CRYPT_KEY --stream=xbstream --compress /tmp"
S3_BASE_ARGS="--access_key ${VAULT_ACCESS_KEY_ID} --secret_key ${VAULT_SECRET_ACCESS_KEY} --host ${VAULT_HOST} --host-bucket ${S3_BUCKET}.${VAULT_HOST}"
S3_ARGS="${S3_BASE_ARGS} ${S3_EXTRA_ARGS}"

function func_exit {
    echo "ERROR: $1"
    exit 1
}

function func_todays_date {
    date +${DATE_FORMAT}
}

#Usage information
function func_usage {
  echo "$(basename "$0") [-h] [-s] -- program to backup mysql data to UKFast Ecloud Vault

  where:
    -h  Show this help text
    -s  Sets the encryption key
    -b  Runs a backup"
  exitval=0
}

function func_set_key {
  #Check if the encryption key already exists
  if [ ! -f $CRYPT_KEY ];
  then
    #No encryption key found in $CRYPT_KEY
    key=$(openssl aes-256-cbc -P -md sha1 | grep iv | cut -f2 -d=)
    echo "Your encryption key is ${key}. Saving in ~/.vault.key"
    echo -n ${key} > ${CRYPT_KEY}
    chmod 600 ${CRYPT_KEY}
  else
    echo "Found an existing encryption key in $CRYPT_KEY - You must delete this before setting a new key"
    exitval=1
  fi
}

function func_backup {
  # Check required progs installed
  ibex=$(which innobackupex 2> /dev/null) || func_exit "innobackupex missing, please install xtrabackup"
  s3upload=$(which s3cmd 2> /dev/null) || func_exit "s3cmd missing, please install xtrabackup"
  [ -f ${CRYPT_KEY} ] || func_exit "Vault encryption key missing. expected path: $CRYPT_KEY - run script with -s"

  backup_archive="$(func_todays_date).full.xbstream"
  echo "Creating backup $backup_archive"
  s3_path="s3://${S3_BUCKET}/${backup_archive}"
  ${ibex} ${INNOBACKUP_ARGS} | ${s3upload} ${S3_ARGS} put - ${s3_path}
}

# start the case-ing
case "$1" in
 --help|-h)
    usage="true"
    shift
    ;;
 --set-key|-s)
    set_key="true"
    shift
    ;;
 --backup|-b)
    run_backup="true"
    shift
    ;;
 *)
    usage="true"
    exitval=1
    ;;
esac

# pick which one to do based on the result of the case statement
if [ "$usage" == "true" ]; then
   func_usage
fi

if [ "$set_key" == "true" ]; then
   func_set_key
fi

if [ "$run_backup" == "true" ]; then
   func_backup
fi


exit $exitval
