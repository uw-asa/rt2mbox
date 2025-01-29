# rt2mbox
Export messages from RT to mbox

This script connects to the RT database and exports all of the mail into mbox format. An mbox file is created for each queue in the current directory. It does a little bit of subject tweaking to try to encourage good threading habits, and the results imported into Mail.app very nicely. This script also extremely fast, since it doesn't use the RT API.

A to how to use it, well just run it and it will tell you how. :-)

Prerequisites:

-  DBI
-  Your DBD (DBD::mysql, DBD::Pg, etc.).
-  Mail::Box perl-module
-  POSIX (comes with Perl)
-  Getopt::Long (comes with Perl)
-  Caveat:

I've tested this with my PostgreSQL database and added code so that it should also work with MySQL, but all other databases might have to tweak the $epoch variable.
