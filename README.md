##### Overview

A wrapper to act as a safe. By default, the safe will look for a ~/safe
directory and produce ~/safe.tar.gz.asc

##### Assumptions

* Your [GnuPG](http://gnupg.org) config is sane

##### Usage

  ./safe.sh -h

##### Configuration

The following variables are supported. These can be maintained in ~/.saferc or
any usual environment file such as ~/.bashrc

If you want to create a safe of /my/stuff, create a ~/.saferc with:

SOURCE_DIR - This directory will be encrypted into a safe. For example, setting this to /my/stuff will result in /my/stuff.tar.gz.asc being created.

When not defined, SOURCE_DIR will default to ~/safe

MY_GPG_KEY -  The gpg key ID used for encryption

When not set, the script will fall back to using `whoami`. This assumes your
key can be identified using the id you are logged in with.

SAFE_BACKUP_HOST - A host to scp backups to. It is always best to maintain a
a definition of this host in your ~/.ssh/config in order to specify details
such as a non-standard port, etc.

SAFE_AUTO_BACKUP - Setting this to 1 will trigger a backup any time the
contents of the safe are modified

##### Examples (using default configuration and my cat's account)

    $ pwd
    /home/evil
    $ ls safe*
    ls: cannot access safe*: No such file or directory
    $ mkdir safe
    $ for i in $(seq 3); do echo "secret number $i" > safe/file$i; done
    $ safe.sh -C
    $ ls safe*
    safe.tar.gz.asc
    $ safe.sh -l
    safe/
    safe/file1
    safe/file2
    safe/file3
    $ safe.sh -o file3
    secret number 3
    $ safe.sh -r file1
    $ safe.sh -l
    safe/
    safe/file2
    safe/file3
    $ > /tmp/foobar
    $ safe.sh -a /tmp/foobar
    $ test -f /tmp/foobar || echo gone
    gone
    $ safe.sh -l
    safe/
    safe/file2
    safe/file3
    safe/foobar
    $ > ~/please_do_not_shred_me
    $ safe.sh -A ~/please_do_not_shred_me
    $ safe.sh -l
    safe/
    safe/file2
    safe/file3
    safe/foobar
    safe/please_do_not_shred_me
    $ test -f ~/please_do_not_shred_me && echo still here
    still here

See -h for other features like editing, backups, and comparing timestamps
