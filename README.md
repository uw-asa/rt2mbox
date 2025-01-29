# rt2mbox

This script connects to the RT database and exports all of the mail into mbox format. An mbox file is created for each queue in the current directory. It does a little bit of subject tweaking to try to encourage good threading habits, and the results imported into Mail.app very nicely. This script also extremely fast, since it doesn't use the RT API.

## Usage

    rt2mbox --dsn dbi:Pgdbname=rt3 --username rt_user --password secret

## Options

    -d --dsn DSN            RT database DSN to which DBI can connect. Required.
    -n --rtname   NAME      RT name, usually domain name. Required.
    -u --username USERNAME  RT database username.
    -p --password PASSWORD  RT database password.
    -x --no-autoreplies     Do not export autoreply messages.
    -q --queue QUEUENUM     Only export specific queue. (Can specify multiple times.)

## Author

David E. Wheeler <david@kineticode.com>

## Copyright and License

Copyright (c) 2008 David E. Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

## Prerequisites

-  DBI
-  Your DBD (DBD::mysql, DBD::Pg, etc.).
-  Mail::Box perl-module
-  POSIX (comes with Perl)
-  Getopt::Long (comes with Perl)
-  Caveat:

I've tested this with my PostgreSQL database and added code so that it should also work with MySQL, but all other databases might have to tweak the $epoch variable.
