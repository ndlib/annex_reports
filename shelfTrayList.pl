#!/usr/bin/env perl

use strict;
use 5.10.1;

use DateTime;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;

use Annex qw/:env annex_prod/;

$|++;
select STDERR;
$|++;
select STDOUT;

my ($test, $debug, $file);
my (@eml);

GetOptions(
    'e|email|emails:s'  => \@eml,
    'f|file=s'          => \$file,
    't|test'            => \$test,
    'debug+'            => \$debug,
);

my $file = $file || 'annex_tray_counts_'.DateTime->now(time_zone => "America/Indianapolis")->datetime.'.csv';

@eml = $test ?(scalar(@eml) ? ('jrittenh@nd.edu') : undef) : split(/,; /, join(',', @eml));

my $emails = join(',', @eml);

my $annexSQL = ''.
    "SELECT shelves.barcode AS \"shelf\", trays.barcode AS \"tray\", shelves.size AS \"size\" ".
    "FROM shelves INNER JOIN trays ON shelves.id = trays.shelf_id ".
    "ORDER BY shelves.barcode, trays.barcode, shelves.size ".
    "";

my $data = annexQuery($annexSQL);

my $cols = getColumns($annexSQL);

my $table = createTable($cols, $data);

my $csv = createCSV($cols, $data);

my ($fh, $filePath) = tempfile();
print $fh $csv;
close($fh);

sendMail2(
    'subject'   => 'Aisle Tray Counts '.DateTime->now(time_zone => "America/Indianapolis")->datetime,
    'body'      => htmlEmailBody('Aisle Tray Counts '.DateTime->now(time_zone => "America/Indianapolis")->datetime, $table),
    'emails'    => $emails,
    'atch'      => {$file, => {'path' => $filePath, 'type' => 'text/csv'}},
    ($test ? ('test' => $test) : ()),
    'html'      => 'H',
    'from'      => 'Library Annex <noreply@library.nd.edu>',
) if ($emails);
