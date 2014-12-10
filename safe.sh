#!/bin/bash
#
# safe.sh - wrapper to interact with my encrypted file archive

usage() {
  echo "Usage: $(basename $0) OPTION"
  echo "Options:"
  echo -e "\t-l list contents"
  echo -e "\t-c create the safe"
  echo -e "\t-x extract contents"
  echo -e "\t-b HOST; backup (scp) to HOST. Multiple -b options are supported"
  echo -e "\t-a FILE; add FILE to the safe and shred the original"
  echo -e "\t-A FILE; add FILE to the safe but do not shred the original"
  echo -e "\t-r FILE; remove FILE from the safe"
  echo -e "\t-o FILE; cat FILE from inside the safe"
  echo -e "\t-v show version"
}

is_or_die() {
  if [ ! -d ${1:-$TAR_ENC} -a ! -f ${1:-$TAR_ENC} ]; then
    echo "Unknown or missing: ${1:-$TAR_ENC}"
    exit 1
  fi
}

shred_source_dir() {
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
  [ $# -eq 1 ] && OPTS+=" $SOURCE_BASE/$1 -O"
  gpg --batch -q -d $TAR_ENC | $TAR $OPTS
}

create_safe() {
  is_or_die $SOURCE_DIR
  $TAR -cz $SOURCE_BASE | gpg -ear $(whoami) --yes -o $TAR_ENC
  shred_source_dir
}

search_safe() {
  is_or_die
  FILE=$(basename $1)
  for f in $(list_safe); do
    ARCHIVE_FILE=${f##$SOURCE_BASE/}
    [ "${f##$SOURCE_BASE/}" == "$FILE" ] && return
  done
  false
}

[ $# -ge 1 ] || { usage; exit 1; }

CONF=${HOME}/.saferc
[ -f $CONF ] && . $CONF
[ -z "$SOURCE_DIR" ] && SOURCE_DIR=${HOME}/safe
VERSION=1.0.0
SOURCE_BASE=$(basename $SOURCE_DIR)
TAR_ENC=$HOME/${SOURCE_BASE}.tar.gz.asc
TAR="tar -C $(dirname $SOURCE_DIR)"

while getopts "vlxcb:a:A:r:o:" opt; do
  case $opt in
    x)
      extract_safe
      ;;
    a|A)
      [ -f $OPTARG ] || { echo "Error: $OPTARG is not a file."; exit 1; }
      search_safe $OPTARG && {
        echo "Duplicate filename in $TAR_ENC: $FILE"
        exit 1
      }
      extract_safe
      cp $OPTARG $SOURCE_DIR
      [ "$1" == "-a" ] && shred -u $OPTARG
      create_safe
      ;;
    r)
      search_safe $OPTARG || {
        echo "File not found in $TAR_ENC: $FILE"
        exit 1
      }
      extract_safe
      shred -u ${SOURCE_DIR}/$FILE
      create_safe
      ;;
    l)
      list_safe
      ;;
    c)
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
    b)
      BACKUP_HOSTS+=("$OPTARG")
      is_or_die
      ;;
    v)
      echo "Version $VERSION"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

for BACKUP_HOST in ${BACKUP_HOSTS[@]}; do
  echo -en "Copying to $BACKUP_HOST... "
  scp $TAR_ENC ${BACKUP_HOST}: &> /dev/null
  [ $? -eq 0 ] && echo OK || echo Failed
done
