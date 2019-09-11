#!/bin/bash
#
# safe.sh - wrapper to interact with my encrypted file archive

usage() {
cat << EOF
Usage: $(basename $0) OPTION
Options:
  -l        list contents
  -C        create the safe
  -x        extract contents
  -B        backup (scp) to host specified in DEFAULT_BACKUP_HOST variable.
  -b HOST   backup (scp) to HOST. Multiple -b options are supported
  -c HOST   compare dates of remote backups. Multiple uses of -C is supported
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
    echo "Unknown or missing: ${1:-$TAR_ENC}"
    exit 1
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

edit_safe() {
  extract_safe
  $EDITOR $SOURCE_DIR
  create_safe
}

[ $# -ge 1 ] || { usage; exit 1; }

CONF=${HOME}/.saferc
[ -f $CONF ] && . $CONF
[ -z "$SOURCE_DIR" ] && SOURCE_DIR=${HOME}/safe
VERSION=1.3.0
SOURCE_BASE=$(basename $SOURCE_DIR)
TAR_ENC=$HOME/${SOURCE_BASE}.tar.gz.asc
TAR="tar -C $(dirname $SOURCE_DIR)"
[ -z "$MY_GPG_KEY" ] && MY_GPG_KEY=$(whoami)

while getopts "hvlxBCec:b:a:A:r:o:p:" opt; do
  case $opt in
    x)
      extract_safe
      ;;
    a|A)
      [ -f $OPTARG ] || { echo "Error: $OPTARG is not a file."; exit 1; }
      search_safe $(basename $OPTARG) && {
        echo "Duplicate filename in $TAR_ENC: $FILE"
        exit 1
      }
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
        echo "File not found in $TAR_ENC: $FILE"
        exit 1
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
      [[ -n $EDITOR ]] && edit_safe || {
        echo "Please set \$EDITOR in your shell"
        exit 1
      }
      ;;
    C)
      # we could support an optarg here to encrypt to a different reciever
      # and fall back to whomai if not used.
      create_safe
      ;;
    o)
      search_safe $OPTARG || {
        echo "File not found in $TAR_ENC: $FILE"
        exit 1
      }
      extract_safe $OPTARG
      ;;
    p)
      SSH_PORT=$OPTARG
      ;;
    B)
      [[ -n "$DEFAULT_BACKUP_HOST" ]] || {
        echo DEFAULT_BACKUP_HOST missing in $CONF
        exit 1
      }
      BACKUP_HOSTS+=$DEFAULT_BACKUP_HOST
      is_or_die
      ;;

    b|c)
      [[ "$opt" == "C" ]] && COMPARE_BACKUPS=1
      BACKUP_HOSTS+=("$OPTARG")
      is_or_die
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

for BACKUP_HOST in ${BACKUP_HOSTS[@]}; do
  if [[ -z "$COMPARE_BACKUPS" ]]; then
    echo -en "Copying to $BACKUP_HOST... "
    scp -P ${SSH_PORT:-22} $TAR_ENC ${BACKUP_HOST}: &> /dev/null
    [ $? -eq 0 ] && echo OK || echo Failed
  else
    TIMESTAMP_REMOTE=$(ssh -p ${SSH_PORT:-22} ${BACKUP_HOST} ls -l --time-style=long-iso $TAR_ENC | awk '{print $6, $7}')
    echo $TIMESTAMP_REMOTE $BACKUP_HOST
  fi
done

if [[ -n "$COMPARE_BACKUPS" ]]; then
  TIMESTAMP_LOCAL=$(ls -l --time-style=long-iso $TAR_ENC | awk '{print $6, $7}')
  echo $TIMESTAMP_LOCAL local
fi
