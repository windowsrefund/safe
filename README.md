### Overview

A wrapper to act as a safe. By default, the safe will look for a ~/safe
directory and produce ~/safe.tar.gz.asc

### Assumptions

* Your [GnuPG](http://gnupg.org) config is sane

### Usage

  ./safe.sh -h

### Configuration

If you want to create a safe of /data/critical, create a ~/.saferc with:

  SOURCE_DIR=/data/critical

In that event, the safe will be created as /data/crital.tar.gz.asc

### Example (using default configuration)

    $ pwd
    /home/akosmin

    $ ls safe*
    ls: cannot access safe*: No such file or directory
    $ mkdir safe
    $ for i in $(seq 5); do echo "it is a secret" > safe/file$i; done
    $ safe.sh -c
    $ ls safe*
    safe.tar.gz.asc
    $ safe.sh -l
    safe/
    safe/file1
    safe/file2
    safe/file3
    safe/file4
    safe/file5
    $ safe.sh -o file4
    it is a secret
    $ safe.sh -r file5
    $ safe.sh -l
    safe/
    safe/file1
    safe/file2
    safe/file3
    safe/file4
