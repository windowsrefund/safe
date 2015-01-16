##### Overview

A wrapper to act as a safe. By default, the safe will look for a ~/safe
directory and produce ~/safe.tar.gz.asc

##### Assumptions

* Your [GnuPG](http://gnupg.org) config is sane

##### Usage

  ./safe.sh -h

##### Configuration

If you want to create a safe of /my/stuff, create a ~/.saferc with:

  SOURCE_DIR=/my/stuff

In that event, the safe will be created as /my/stuff.tar.gz.asc

You can specifiy the gpg key ID used for encryption in ~/.saferc

  MY_GPG_KEY=0x1234567890ABCDEF

When not set, the script will fall back to using `whoami`. This assumes your
key can be identified using the id you are logged in with.

##### Examples (using default configuration and my cat's account)

    $ pwd
    /home/evil
    $ ls safe*
    ls: cannot access safe*: No such file or directory
    $ mkdir safe
    $ for i in $(seq 3); do echo "secret number $i" > safe/file$i; done
    $ safe.sh -c
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

See -h for other features like editing and backups
