#!/usr/bin/env perl

use strict;
use 5.10.1;

use Data::Printer;
use DateTime;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use HTML::Entities;

use Justin;
use Justin qw/:annex sendMail2/;

$|++;

my ($date, $emails, $hourly, $test);

GetOptions(
    'd|date=s'          => \$date,
    'e|email|emails=s'  => \$emails,
    'h|hourly'          => \$hourly,
    't|test'            => \$test,
);

$emails = $test ? 'jrittenh@nd.edu' : ($emails ? $emails : 'jrittenh@nd.edu');

if ($date =~ /(\d{4})[-\/]?(\d{2})[-\/]?(\d{2})/) {
    $date = DateTime->now(time_zone => 'America/Indianapolis')->set(
        'year'  => $1,
        'month' => $2,
        'day'   => $3,
    );
} else {
    $date = DateTime->now(time_zone => 'America/Indianapolis')->subtract(days => 1);
}

#~ SELECT DATE(action_timestamp::timestamp AT TIME ZONE 'UTC') AS "date", DATE_PART('hour', action_timestamp::timestamp AT TIME ZONE 'UTC') AS "hour", username, COUNT(*) AS "items"
#~ FROM activity_logs
#~ WHERE action = 'AssociatedItemAndTray' AND DATE(action_timestamp::timestamp AT TIME ZONE 'UTC') = '2015-07-23'
#~ GROUP BY DATE(action_timestamp::timestamp AT TIME ZONE 'UTC'), DATE_PART('hour', action_timestamp::timestamp AT TIME ZONE 'UTC'), username

my $tzSQL = "SET TIME ZONE 'EST5EDT'";

annexQuery($tzSQL);

my $sql = "SELECT DATE(action_timestamp::timestamp AT TIME ZONE 'UTC') AS \"date\", ".($hourly ? "DATE_PART('hour', action_timestamp::timestamp AT TIME ZONE 'UTC') AS \"hour\", " : "")."username, COUNT(*) AS \"items\" ".
    "FROM activity_logs ".
    "WHERE action = 'AssociatedItemAndTray' ".
    "AND DATE(action_timestamp::timestamp AT TIME ZONE 'UTC') = '".$date->ymd."' ".
    "GROUP BY DATE(action_timestamp::timestamp AT TIME ZONE 'UTC'), ".($hourly ? "DATE_PART('hour', action_timestamp::timestamp AT TIME ZONE 'UTC'), " : "")."username ".
    "";

#~ say $sql;
#~ exit;

#~ $sql = "SELECT current_setting('TIMEZONE')";

my $data = annexQuery($sql);

#~ say p($data);
#~ exit;

#~ my $rpt = "Partially Full Shelves\n".sprintf('%-13s', 'Shelf')."\tTrays\n";
#~ my $printout = "Partially Full Shelves\nShelf,Trays\n";
#~
#~ my $erpt = "Invalid Shelves\n".sprintf('%-30s', 'Shelf')."\tTrays\n";
#~ my $eprintout = "Invalid Shelves\nShelf,Trays\n";
#~
#~ my $frpt = "Full Shelves\n".sprintf('%-13s', 'Shelf')."\tTrays\n";
#~ my $fprintout = "Full Shelves\nShelf,Trays\n";

#~ say p($data);
#~ exit;

my $rpt = ($hourly ? "Hour | " : "")."Username | Items\n".('-' x 23)."\n";
my $printout = ($hourly ? "Hour," : "")."Username,Items\n";

foreach my $w (sort {($hourly ? $a->{'hour'} <=> $b->{'hour'} : ()) || $b->{'items'} <=> $a->{'items'}} @$data) {
    my %worker = %$w;
    #~ say p(%worker);
    #~ exit;
    $rpt .= ($hourly ? sprintf('%4d', $worker{'hour'})." | " : "").sprintf('%-8s', $worker{'username'})." | ".sprintf('%5d', $worker{'items'})."\n";
    $printout .= ($hourly ? "$worker{'hour'}," : "")."$worker{'username'},$worker{'items'}\n";
}

#~ say $rpt;
#~ exit;
my $body = "<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\"><title>Annex Worker Ingest Stats</title></head>";
$body .= "<body><pre style=\"font-size: 12pt;\">".encode_entities($rpt)."</pre></body>";
$body .= "</html>";

my $rptFile = 'annexWorkerStats'.$date->date().'.csv';
my ($fh, $rptPath) = tempfile();
print $fh $printout;
close($fh);

sendMail2(
    'subject'   => "Annex Worker Ingest Stats ".$date->date(),
    'body'      => $body,
    'html'      => 'H',
    'atch'      => {$rptFile, => {'path' => $rptPath, 'type' => 'text/csv'}},
    'emails'    => $emails,
    'from'      => 'Library Annex <noreply@library.nd.edu>',
);
