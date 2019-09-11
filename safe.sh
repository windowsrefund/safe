#!/bin/bash
#
# safe.sh - wrapper to interact with my encrypted file archive

error() {
  echo Error: $@
  exit 1
}

usage() {
cat << EOF
Usage: $(basename $0) OPTION
Options:
  -l        list contents
  -C        create the safe
  -x        extract contents
  -b        backup (scp) to SAFE_REMOTE_HOST defined in ~/.saferc
  -c        compare date of remote backup on SAFE_REMOTE_HOST defined in ~/.saferc
  -o FILE   cat FILE from inside the safe
  -v        show version

The following options create a temporary plaintext copy of the safe
  -e        edit safe contents
  -a FILE   add FILE to the safe and shred the original
  -A FILE   add FILE to the safe but do not shred the original
  -r FILE   remove FILE from the safe
EOF
}

is_or_die() {
  if [ ! -d ${1:-$TAR_ENC} -a ! -f ${1:-$TAR_ENC} ]; then
    error Unknown or missing: ${1:-$TAR_ENC}
  fi
}

shred_source_dir() {
  chmod -R u+w $SOURCE_DIR
  find $SOURCE_DIR -type f | xargs shred -u
  rm -fr $SOURCE_DIR
}

list_safe() {
  is_or_die
  gpg --batch -q -d $TAR_ENC | tar -zt | sort
}

# cat the file if passed in as an arg.
# otherwise, just extract the dir
extract_safe() {
  is_or_die
  OPTS=" -zx"
  [ $# -eq 1 ] && OPTS+=" $SOURCE_BASE/${1#*/} -O"
  gpg --batch -q -d $TAR_ENC | $TAR $OPTS
}

create_safe() {
  is_or_die $SOURCE_DIR
  $TAR -cz $SOURCE_BASE | gpg -ear $MY_GPG_KEY --yes -o $TAR_ENC
  shred_source_dir
  auto_backup
}

search_safe() {
  is_or_die
  FILE=${1#*/}
  for f in $(list_safe); do
    ARCHIVE_FILE=${f#${SOURCE_BASE}/}
    [ "$ARCHIVE_FILE" == "$FILE" ] && return
  done
  false
}

auto_backup() {
  [[ "$SAFE_AUTO_BACKUP" -eq 1 ]] && backup_safe
}

backup_safe() {
  is_or_die
  echo -n "Backup to ${SAFE_REMOTE_HOST}: "
  scp $TAR_ENC ${SAFE_REMOTE_HOST}: &> /dev/null
  [[ $? -eq 0 ]] && echo OK || echo Failed
}

edit_safe() {
  extract_safe
  $EDITOR $SOURCE_DIR
  create_safe
}

[ $# -ge 1 ] || { usage; exit 1; }

CONF=${HOME}/.saferc
[ -f $CONF ] && . $CONF
[ -z "$SOURCE_DIR" ] && SOURCE_DIR=${HOME}/safe
VERSION=1.4.0
SOURCE_BASE=$(basename $SOURCE_DIR)
TAR_ENC=$HOME/${SOURCE_BASE}.tar.gz.asc
TAR="tar -C $(dirname $SOURCE_DIR)"
[ -z "$MY_GPG_KEY" ] && MY_GPG_KEY=$(whoami)

while getopts "hvlxBCecba:A:r:o:" opt; do
  case $opt in
    x)
      extract_safe
      ;;
    a|A)
      [ -f $OPTARG ] || error $OPTARG is not a file
      search_safe $(basename $OPTARG) && error Duplicate in $TAR_ENC: $FILE
      extract_safe
      cp $OPTARG $SOURCE_DIR
      [ "$1" == "-a" ] && {
        chmod u+w $OPTARG
        shred -u $OPTARG
      }
      create_safe
      ;;
    r)
      search_safe $OPTARG || {
      error File not found in $TAR_ENC: $FILE
      }
      extract_safe
      chmod u+w ${SOURCE_DIR}/$FILE
      shred -u ${SOURCE_DIR}/$FILE
      create_safe
      ;;
    l)
      list_safe
      ;;
    e)
      [[ -n $EDITOR ]] || error Please set \$EDITOR in your shell
      edit_safe
      ;;
    C)
      # we could support an optarg here to encrypt to a different reciever
      # and fall back to whomai if not used.
      create_safe
      ;;
    o)
      search_safe $OPTARG || error File not found in $TAR_ENC: $FILE
      extract_safe $OPTARG
      ;;
    b)
      [[ -n "$SAFE_REMOTE_HOST" ]] || error SAFE_REMOTE_HOST missing in $CONF
      backup_safe
      ;;
    c)
      [[ -n "$SAFE_REMOTE_HOST" ]] || error SAFE_REMOTE_HOST missing in $CONF
      is_or_die
      TIMESTAMP_REMOTE=$(ssh ${SAFE_REMOTE_HOST} ls -l --time-style=long-iso $TAR_ENC | awk '{print $6, $7}')
      TIMESTAMP_LOCAL=$(ls -l --time-style=long-iso $TAR_ENC | awk '{print $6, $7}')
      echo $TIMESTAMP_REMOTE $SAFE_REMOTE_HOST
      echo $TIMESTAMP_LOCAL local
      ;;
    v)
      echo "Version $VERSION"
      ;;
    h)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

