#!/usr/bin/perl -w

use strict;
use DBI;
use Getopt::Long qw(:config auto_help auto_version);
use POSIX qw(asctime);
our $VERSION = '0.01';

GetOptions(
    'dsn|d=s'          => \my $dsn,
    'username|u=s'     => \my $username,
    'password|p=s'     => \my $password,
    'rtname|n=s'       => \my $rtname,
    'no-autoreplies|x' => \my $noauto,
    'queues|q=s'       => \my @queues,
)  or require Pod::Usage && Pod::Usage::pod2usage(2);

require Pod::Usage && Pod::Usage::pod2usage(1) unless $dsn && $rtname;

my $dbh = DBI->connect(
    $dsn,
    $username,
    $password,
    { RaiseError => 1 }
);

END {
    $dbh->disconnect if $dbh;
}

my $qsel = $dbh->prepare(q{
    SELECT id, Name, CorrespondAddress, CommentAddress
    FROM Queues
    ORDER BY Name
});


my $exclude = $noauto ? "\n       AND Users.id <> 1" : '';
my $epoch   = $dsn =~ /^dbi:Pg/
    ? 'EXTRACT( EPOCH FROM Attachments.Created )'
    : 'UNIX_TIMESTAMP( Attachments.Created )';

my $msel = $dbh->prepare(qq{
    SELECT Tickets.id, Transactions.id, Transactions.Type, Attachments.id,
        Parent, Users.EmailAddress,
        ContentType, COALESCE( ContentEncoding, '' ),
        $epoch,
        Headers, Content, Tickets.Subject
    FROM Tickets, Transactions, Attachments, Users
    WHERE Tickets.Queue = ?
    AND Tickets.id = Transactions.ObjectId
    AND Transactions.ObjectType = ?
    AND Transactions.id = Attachments.TransactionId
    AND Transactions.Creator = Users.id$exclude
    ORDER BY Transactions.id, Attachments.id, Parent
});

$qsel->execute;
$qsel->bind_columns( \my ( $qid, $qname, $correspond, $comment ) );

while ($qsel->fetch) {
    if (@queues && ! grep { $_ eq $qid } @queues) {
        next;
    }

    # Normalize the name.
    $qname =~ s{[/.]}{}g;

    # Open the mbox file.
    open my $mbox, '>', "$qname.mbox" or die "Cannot open $qname.mbox: $!\n";
    $msel->execute( $qid, 'RT::Ticket' );
    $msel->bind_columns(\my ( $tid, $txid, $ttype, $aid, $parent, $email, $type, $encoding, $time, $headers, $body, $subject));

    my @parents;
    my @bounds;
    while ($msel->fetch) {
        if (!$parent) {
            # Top level of a message. Close the previous message.
            @parents = ();
            while (my $bound = pop @bounds) {
                print $mbox "--$bound--\n\n";
            }

            # Start the new message.
            ( my $asctime = asctime( gmtime $time ) ) =~ s/\s+$//ms;
            $email ||= $ttype =~ /comment/i ? $comment : $correspond;
            print $mbox "From $email $asctime\n";

            # Make sure that the body ends in a blank line.
            $body =~ s/(\n{0,2})?$/\n\n/ if $body;

            # Adjust headers. They always end with a single newline.
            $headers .= "RT-Transaction-Id: $txid\n";
            if ( $headers !~ /^From:/mi ) {
                $headers .= "From: $email\n";
            }
            if ( $headers !~ /^Subject:/mi ) {
                $headers .= "Subject: [$rtname #$tid] $subject\n";
            } else {
                $headers =~ s/^(Subject:\s*(?:(?:Re|Fwd):\s*)?)/$1\[$rtname #$tid] /mi
                    unless $headers =~ /^Subject:\s*(?:(?:Re|Fwd):\s*)?[[]\Q$rtname\E/mi
            }

        } else {
            # Close any parents.
            while (@parents && $parents[-1] != $parent) {
                pop @parents;
                my $bound = pop @bounds;
                print $mbox "--$bound--\n\n";
            }
        }

        # Add the Attachment ID to the headers, so simplify backtracking.
        $headers .= "RT-Attachment-Id: $aid\n";

        # Handle this part.
        if ($type =~ m{^multipart/}) {
            # Part is multipart. Push the parent ID onto the stack.
            push @parents, $aid;

            # Determine the bounary.
            my $bound;
            if ($headers =~ qr{\bboundary=(.+)}mi) {
                # Retain the original boundary.
                ($bound = $1) =~ s/^"//;
                $bound =~ s/"$//;
            } else {
                # Just invent a boundary.
                $bound = join '', ('a'..'z', 'A'..'Z', 0..9)[ map { rand 62 } 0..10];
            }

            # Output the part.
            print $mbox "--$bounds[-1]\n" if @bounds;
            print $mbox "$headers\n";
            print $mbox $body if $body;

            # Push the boundary onto the stack.
            push @bounds, $bound;
        } else {
            # Is a standalone part.
            print $mbox "--$bounds[-1]\n" if @bounds;
            print $mbox "$headers\n";
            print $mbox $body if $body;
        }
    }
    close $mbox or die "Cannot close $qname.mbox: $!\n";
}

1;
__END__

=head1 Name

rt2mbox - Export RT messages to mbox files, one for each queue

=head1 Synopsis

=begin comment

Fake-out Pod::Usage

=head1 SYNOPSIS

=end comment

rt2mbox --dsn dbi:Pgdbname=rt3 --username rt_user --password secret

=head1 Options

-d --dsn DSN            RT database DSN to which DBI can connect. Required.
-n --rtname   NAME      RT name, usually domain name. Required.
-u --username USERNAME  RT database username.
-p --password PASSWORD  RT database password.
-x --no-autoreplies     Do not export autoreply messages.
-q --queue QUEUENUM     Only export specific queue. (Can specify multiple times.)

=head1 Author

David E. Wheeler <david@kineticode.com>

=head1 Copyright and License

Copyright (c) 2008 David E. Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
