#!/usr/bin/perl -w
##
## popclean.pl: is a perl script to clean POP3 mailboxes
## remotely using spamassassin; meanwhile, saves them
## in a local mailbox in Maildir format.
##
## Copyright (c) 2003 Ali Onur Cinar <root@zdo.com>
##
## Latest version may be downloaded from http://www.zdo.com
##
## This program is free software; you can redistribute it and/or
## modify it under the terms of the GNU General Public License
## as published by the Free Software Foundation; either version 2
## of the License, or any later version. And also please
## DO NOT REMOVE my name, and give me CREDIT when you use
## whole or a part of this program in an other program.
##
## To Configure:
## =============
##   update the @servers array according to your email accounts
##   such as:
##
##   @servers = (
##        ['pop3.host1.com','username','password'],
##        ['pop3.host2.com','username','password']
##   );
##
##   since the passwords are written in plain text, please
##   change the script's permissions to 700 to prevent
##   people to access your passwords.
##
##   update the path for Spamassassin.
##
##   $spamc = "/usr/bin/spamc";
##
##   create a mailbox in Maildir format, using Qmail's
##   maildirmake,  and here define its path.
##
##   $maildir = "/tmp/spam";
##
## To Use:
## =======
##
##   Start the script from shell prompt.
##
##   $ ./popclean.pl
##

## configuration begins
@servers = (
            [
             'pop3.host1.com', 'user', 'pass'
            ],
            [
             'pop3.host2.com', 'user', 'pass'
            ],
            );
$spamc   = "/usr/bin/spamc";
$maildir = "/tmp/spam";
## configuration ends

use Net::POP3;
use IPC::Open2;
use POSIX;
use Sys::Hostname;

sub lprint
{
  my $msg = shift;
  my $stamp = strftime "--%H:%M:%S--", localtime;
  print "$stamp $msg";
}

sub main
{

  # check spamc executable
  if (!-x $spamc)
  {
    lprint "$spamc is not a valid executable.\n";
    exit(1);
  }

  for (my $i = 0 ; $i <= $#servers ; $i++)
  {

    # info
    lprint "connecting " . $servers[$i][0] . "\n";

    # connect to server
    my $pop =
      Net::POP3->new($servers[$i][0],
                     Timeout => 60);
    if (!defined $pop)
    {
      lprint "error connecting to server.\n";
      exit(1);
    }

    # send username and password and check
    my $nm =
      $pop->login($servers[$i][1],
                  $servers[$i][2]);
    if (!defined $nm)
    {
      lprint "server said incorrect password.\n";
      exit(1);
    }

    # show the number of available messages
    lprint "mailbox has "
      . int($nm)
      . " messages.\n";

    # check each message for spam
    for (my $j = 1 ; $j <= $nm ; $j++)
    {

      # fetch the message
      my $PR = $pop->getfh($j);

      # by default it is not spam
      my $isSpam = 0;

      # open spamassassin
      open2(\*SR, \*SW, "$spamc");

      # input the message
      while (<$PR>)
      {
        if (/^From:/)
        {
          lprint $_;
        }
        print SW $_;
      }
      close($PR);
      close(SW);

      # get the result
      my $body = "";
      while (<SR>)
      {
        $body .= $_;
        if ($_ =~ /^X-Spam-Status: Yes/)
        {
          $isSpam = 1;
          lprint "identified spam\n";
        }
      }
      close(SR);

      # if isSpam then delete it
      if ($isSpam == 1)
      {
        my $now    = time;
        my $host   = hostname;
        my $msg_id = "new/$now.$$.$host";

        # log it first as mbox
        open(LOG, "> $maildir/$msg_id");
        print LOG "$body\n\n";
        close(LOG);

        # delete it
        $pop->delete($j);
      }
    }

    # close the connection
    $pop->quit();
  }
}

main;

