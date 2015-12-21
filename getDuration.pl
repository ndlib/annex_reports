#!/bin/env perl

use strict;
use 5.10.1;

use Justin;

my $h = 14;
my $d = 7;
my $sec = 700000;

say getTimeStringLong($sec);
say 3600*24*7;
say 3600*14;
say "Work Hours: $h";
say "Work Days:  $d";
say "Done Sec:   $sec";
say "Done Weeks: ".int($sec/(3600*$h*$d));
say "Sec Left:   ".($sec%(3600*$h*$d));
say "Done Days:  ".int(($sec%(3600*$h*$d))/(3600*$h));
say "Sec Left:   ".(($sec%(3600*$h*$d))%(3600*$h));
say "Done Hours: ".int((($sec%(3600*$h*$d))%(3600*$h))/3600);
say "Sec Left:   ".((($sec%(3600*$h*$d))%(3600*$h))%3600);
say "Done Min:   ".int(((($sec%(3600*$h*$d))%(3600*$h))%3600)/60);
say "Sec Left:   ".(((($sec%(3600*$h*$d))%(3600*$h))%3600)%60);
