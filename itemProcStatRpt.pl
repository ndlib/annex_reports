#!/bin/env perl

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

my $annexItemsSQL = "SELECT TRIM(z30_barcode) AS \"barcode\", ".
        "z30_rec_key AS \"item\", ".
        "SUBSTR(z30_rec_key, 1, 9) AS \"adm\", ".
        "SUBSTR(z30_rec_key, 10, 6) AS \"seq\", ".
        "z30_item_process_status AS \"procstat\", ".
        "TO_CHAR(TO_DATE(DECODE(z30_process_status_date, 0, 19000101, z30_process_status_date), 'YYYYMMDD'), 'YYYY-MM-DD') AS \"psdate\", ".
        "TRIM(z30_cataloger) AS cataloger ".
    "FROM ndu50.z30 ".
    "WHERE z30_sub_library = 'ANNEX' ".
    "";

my $apiItemsSQL = "SELECT TRIM(z30_barcode) AS \"barcode\", ".
        "z30_rec_key AS \"item\", ".
        "z30_sub_library AS \"sublibrary\", ".
        "z30_item_process_status AS \"procstat\", ".
        "TO_CHAR(TO_DATE(DECODE(z30_process_status_date, 0, 19000101, z30_process_status_date), 'YYYYMMDD'), 'YYYY-MM-DD') AS \"psdate\" ".
    "FROM ndu50.z30 ".
    "WHERE z30_cataloger IN ('APIANNEX  ', 'RFOX2     ')".
    "UNION ".
    "SELECT TRIM(z30h_barcode) AS \"barcode\", ".
        "z30h_rec_key AS \"item\", ".
        "z30h_sub_library AS \"sublibrary\", ".
        "z30h_item_process_status AS \"procstat\", ".
        "TO_CHAR(TO_DATE(DECODE(z30h_process_status_date, 0, 19000101, z30h_process_status_date), 'YYYYMMDD'), 'YYYY-MM-DD') AS \"psdate\" ".
    "FROM ndu50.z30h ".
    "WHERE z30h_cataloger IN ('APIANNEX  ', 'RFOX2     ')".
    "";

my $admItemCount = "SELECT COUNT(*) AS \"count\" ".
    "FROM ndu50.z30 ".
    "WHERE SUBSTR(z30_rec_key, 1, 9) = ? ".
    "";


#~ id
#~ barcode
#~ title
#~ author
#~ chron
#~ thickness
#~ tray_id
#~ created_at
#~ updated_at
#~ bib_number
#~ isbn_issn
#~ conditions
#~ call_number
#~ initial_ingest
#~ last_ingest
#~ bin_id
#~ status
#~ metadata_updated_at
#~ metadata_status

my $imsItemsSQL = "SELECT items.barcode as barcode, trays.barcode as tray, shelves.barcode as shelf, items.created_at, items.updated_at, items.status, items.metadata_updated_at, items.metadata_status, issues.issue_type, issues.resolved_at ".
    "FROM items LEFT JOIN trays ON tray_id = trays.id ".
    "LEFT JOIN shelves ON trays.shelf_id = shelves.id ".
    "LEFT JOIN issues ON items.barcode = issues.barcode ".
    #~ "WHERE items.barcode NOT IN ( ".
        #~ "SELECT barcode ".
        #~ "FROM issues ".
    #~ ") ".
    "";

chomp(my $startTS = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $startTS, time_zone => "America/Indianapolis")->datetime();
my $annexItems = alephQuery3($annexItemsSQL, undef, {'host' => 'aleph1.library.nd.edu', 'return' => 'hash'});
chomp(my $doneAts = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $doneAts, time_zone => "America/Indianapolis")->datetime();
my $apiItems = alephQuery3($apiItemsSQL, undef, {'host' => 'aleph1.library.nd.edu', 'return' => 'hash'});
chomp(my $doneBts = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $doneBts, time_zone => "America/Indianapolis")->datetime();
my $imsItems = annexQuery($imsItemsSQL);
chomp(my $doneTS = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $doneTS, time_zone => "America/Indianapolis")->datetime();

say STDERR $doneAts - $startTS;
say STDERR $doneBts - $doneAts;
say STDERR $doneTS - $doneBts;
say STDERR $doneTS - $startTS;

say getLine(20);

#~ say p(@$annexItems);
#~ say p($apiItems);
#~ say p(@$imsItems);
#~ say "ANNEX    = ".scalar(@$annexItems);
#~ say "APIANNEX = ".scalar(@$apiItems);
#~ say "IMS      = ".scalar(@$imsItems);
#~ exit;
my %errors;

say STDERR scalar(keys(%$annexItems))." items found in ANNEX sublibrary.";
say STDERR scalar(keys(%$apiItems))." items found updated by API call.";
say STDERR scalar(@$imsItems)." items found in the Annex.";
chomp(my $loopStartTS = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $loopStartTS, time_zone => "America/Indianapolis")->datetime();
my %imsItemHash;
my @admItemCount;
my $x = 0;
my $cleanItemCount = 0;
my @pcts = @{getPcts(scalar(@$imsItems))};
#~ say p(@pcts);
#~ exit;
monitor(0, scalar(@$imsItems), 0);

my %fhHash;

foreach my $imsItem (@$imsItems) {
    $x++;
    my $bc = $imsItem->{'barcode'};
    $imsItemHash{$bc}++;
    if (!defined($imsItem->{'tray'}) || (defined($imsItem->{'issue_type'}) && !defined($imsItem->{'resolved_at'}))) {
        unless (defined($imsItem->{'issue_type'})) {
            open($fhHash{'IMSnoTray'}, '>', 'IMSnoTray.psv') unless(defined($fhHash{'IMSnoTray'}));
            writeLine($fhHash{'IMSnoTray'}, "$bc");
            $errors{'IMSnoTray'}{$bc}++;
        } else {
            open($fhHash{'IMSissues'}, '>', 'IMSissues.psv') unless(defined($fhHash{'IMSissues'}));
            writeLine($fhHash{'IMSissues'}, "$bc");
            $errors{'IMSissues'}{$bc}++;
        }
    } else {
        unless (exists($annexItems->{$bc})) {
            open($fhHash{'IMSnotANNEX'}, '>', 'IMSnotANNEX.psv') unless(defined($fhHash{'IMSnotANNEX'}));
            writeLine($fhHash{'IMSnotANNEX'}, "$bc");
            $errors{'IMSnotANNEX'}{$bc}++;
        } elsif ($annexItems->{$bc}{'procstat'} eq 'AT') {
            unless(defined($fhHash{'IMSstillAT'})) {
                open($fhHash{'IMSstillAT'}, '>', 'IMSstillAT.csv');
                writeLine($fhHash{'IMSstillAT'}, join(',', ('barcode', 'adm', 'seq', 'tray', 'shelf')));
            }
            open($fhHash{'IMSstillATinput'}, '>', 'IMSstillATinput') unless(defined($fhHash{'IMSstillATinput'}));
            writeLine($fhHash{'IMSstillAT'}, join(',', ("=\"$bc\"", "=\"".$annexItems->{$bc}{'adm'}."\"", "=\"".$annexItems->{$bc}{'seq'}."\"", $imsItem->{'tray'}, $imsItem->{'shelf'})));
            writeLine($fhHash{'IMSstillATinput'}, $annexItems->{$bc}{'item'});
            $errors{'IMSstillAT'}{$bc}++;
            #~ my $admCount = alephQuery3($admItemCount, [$annexItems->{$bc}{'adm'}], {'host' => 'aleph1.library.nd.edu'});
            #~ push(@admItemCount, $admCount->[0][0]);
            open($fhHash{'IMSadmAT'}, '>', 'IMSadmAT.psv') unless(defined($fhHash{'IMSadmAT'}));
            writeLine($fhHash{'IMSadmAT'}, $annexItems->{$bc}{'adm'});
            $errors{'IMSadmAT'}{$annexItems->{$bc}{'adm'}}++;
        }

        unless (exists($apiItems->{$bc})) {
            open($fhHash{'IMSnotAPI'}, '>', 'IMSnotAPI.psv') unless(defined($fhHash{'IMSnotAPI'}));
            writeLine($fhHash{'IMSnotAPI'}, "$bc");
            $errors{'IMSnotAPI'}{$bc}++;
            if (defined($errors{'IMSstillAT'}{$bc})) {
                open($fhHash{'notAPIstillAT'}, '>', 'notAPIstillAT.psv') unless(defined($fhHash{'notAPIstillAT'}));
                writeLine($fhHash{'notAPIstillAT'}, "$bc");
                $errors{'notAPIstillAT'}{$bc}++;
            } else {
                open($fhHash{'notAPInotAT'}, '>', 'notAPInotAT.psv') unless(defined($fhHash{'notAPInotAT'}));
                writeLine($fhHash{'notAPInotAT'}, "$bc");
                $errors{'notAPInotAT'}{$bc}++;
            }
        }
        $cleanItemCount++;
    }

    monitor($x, scalar(@$imsItems), 0) if ($x ~~ @pcts);
}
chomp(my $loopEndTS = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $loopEndTS, time_zone => "America/Indianapolis")->datetime();

foreach my $fh (keys(%fhHash)) {
    close($fhHash{$fh});
}

foreach my $apiItem (keys(%$apiItems)) {
    $errors{'APInotIMS'}{$apiItem}++ unless (defined($imsItemHash{$apiItem}));
}
chomp(my $loopTwoTS = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $loopTwoTS, time_zone => "America/Indianapolis")->datetime();

say STDERR scalar(keys(%{$errors{'IMSnotANNEX'}}))." IMS items not labeled with sublibrary ANNEX.";
say STDERR scalar(keys(%{$errors{'IMSstillAT'}}))." IMS items assigned to a tray are still coded with process status AT.";
say STDERR scalar(keys(%{$errors{'IMSnotAPI'}}))." IMS items not updated by APIANNEX or RFOX2.";
say STDERR "    Of those, ".scalar(keys(%{$errors{'notAPIstillAT'}}))." are also still coded with process status AT, leaving ".(scalar(keys(%{$errors{'IMSnotAPI'}})) - scalar(keys(%{$errors{'notAPIstillAT'}})))." items not touched by the API, but having a cleared or non-AT process status.";
say STDERR scalar(keys(%{$errors{'IMSnoTray'}}))." IMS items have not been assigned to a tray.";
say STDERR scalar(keys(%{$errors{'ANNEXnotIMS'}}))." ANNEX items have been touched by the IMS but no longer exist in the IMS.";
say STDERR scalar(keys(%{$errors{'IMSissues'}}))." IMS items have been flagged as issues.";
say STDERR $cleanItemCount." items are currently shelved according to the IMS.";
#~ say STDERR "On average, ".sprintf('%.2f', getAverage(@admItemCount))." items are attached to IMS items retaining the AT status.";
#~ say p(%errors);

chomp(my $scriptEndTS = scalar(gettimeofday));
say STDERR DateTime->from_epoch(epoch => $scriptEndTS, time_zone => "America/Indianapolis")->datetime();

say STDERR sprintf('%4.1f', $scriptEndTS - $startTS);
