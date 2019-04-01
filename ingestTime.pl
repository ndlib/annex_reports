#!/usr/bin/env perl

use strict;
use experimental qw/smartmatch/;
use 5.10.1;

use DateTime;
use DBI;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use Time::HiRes qw/time gettimeofday/;

use Data::Printer;

use Justin;
use Justin qw/:oracle :annex/;

$|++;
select STDERR;
$|++;
select STDOUT;

my ($emails, $pretend, $test);

GetOptions(
    'e|emails=s'    => \$emails,
    'p|pretend'     => \$pretend,
    't|test'        => \$test,
);

$pretend += 0;
$test += 0;

$emails = $test ? 'jrittenh@nd.edu' : ($emails ? $emails : 'jrittenh@nd.edu');

my $startSQL = "SELECT EXTRACT(EPOCH FROM MIN(shelves.created_at) AT TIME ZONE 'UTC') ".
    "FROM shelves ".
    "";

my $totalSQL = "SELECT COUNT(*) ".
    "FROM ndu50.z30 ".
    "WHERE z30_sub_library = 'ANNEX' ".
    "";

my $doneSQL = "SELECT COUNT(items.barcode) AS \"count\", EXTRACT(EPOCH FROM MAX(trays.updated_at) AT TIME ZONE 'UTC') AS \"now\" ".
    "FROM items ".
    "LEFT JOIN trays ON items.tray_id = trays.id ".
    "LEFT JOIN shelves ON trays.shelf_id = shelves.id ".
    "LEFT JOIN issues ON items.barcode = issues.barcode ".
    "WHERE tray_id IS NOT NULL ".
    "AND shelf_id IS NOT NULL ".
    "AND issues.id IS NULL ".
    "";

my $traysSQL = "SELECT COUNT(trays.barcode) AS \"count\" ".
    "FROM trays ".
    "LEFT JOIN shelves ON Trays.shelf_id = shelves.id ".
    "WHERE shelf_id IS NOT NULL ".
    "";

my %shelfSize = (
    'AL'    => 16,
    'AH'    => 16,
    'BL'    => 14,
    'BH'    => 14,
    'CL'    => 12,
    'CH'    => 12,
    'DL'    => 10,
    'DH'    => 10,
    'EL'    => 8,
    'EH'    => 8,
);

my $shelfSQL = 'SELECT shelves.barcode AS "barcode", shelves.size AS "tray_size", COUNT(*) as "trays" FROM trays, shelves WHERE trays.shelf_id = shelves.id GROUP BY shelves.barcode, shelves.size ORDER BY shelves.barcode';


my $tzSQL = "SET TIME ZONE 'EST5EDT'";
annexQuery($tzSQL);

my %stats;

$stats{'start'} = annexQuery($startSQL)->[0][0];
$stats{'total'} = alephQuery3($totalSQL)->[0][0];
my $d = annexQuery($doneSQL)->[0];
$stats{'done'} = $d->{'count'};
$stats{'now'} = $d->{'now'};

$stats{'startHour'} = 8;
$stats{'endHour'} = 22;

getETC(\%stats);

if ($stats{'timeLeftStringLong'} =~ /,/) {
    my $commas = () = $stats{'timeLeftStringLong'} =~ /,/g;
    if ($commas > 1) {
        $stats{'timeLeftStringLong'} =~ s/(.*,)/$1 and/;
    } else {
        $stats{'timeLeftStringLong'} =~ s/(.*),/$1 and/;
    }
}

$stats{'trays'} = annexQuery($traysSQL)->[0][0];
my $sRef = annexQuery($shelfSQL);

foreach my $shelf (@$sRef) {
    $stats{'shelves'}++ if ($shelf->{'trays'} >= $shelfSize{$shelf->{'tray_size'}});
}

my $body;
$body .= "As of ".DateTime->from_epoch(epoch => $stats{'now'}, time_zone => "America/Indianapolis")->datetime().":\n\n";
$body .= "$stats{'done'} items have been shelved out of $stats{'total'} total items expected to be relocated to the Annex.  These items have been placed in $stats{'trays'} trays, which have filled $stats{'shelves'} shelves.\n\n";
$body .= "To date, these items were processed at a rate of ".sprintf('%.2f', $stats{'speed'} * 3600)." items per hour, or ".sprintf('%.2f', $stats{'speed'} * 3600 * $stats{'workHours'})." items per day.";
$body .= " Continuing at that pace, $stats{'timeLeftStringLong'} of work remain".(($stats{'timeLeftStringLong'} =~ /^1 (hour|minute|second)$/) ? 's' : '').".\n\n";
#~ $body .= "Given 14 hour workdays, 7 days a week, at this rate, ";
$body .= "Estimated time of completion: $stats{'timestamp'} ".$stats{'endDT'}->time_zone_short_name()."\n";

sendMail2(
    'subject'   => 'Annex Ingest Statistics, '.DateTime->now(time_zone => 'America/Indianapolis')->datetime(),
    'body'      => $body,
    'emails'    => $emails,
    'from'      => 'Library Annex <noreply@library.nd.edu>',
    'test'      => $pretend,
);
