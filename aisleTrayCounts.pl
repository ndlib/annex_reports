#!/usr/bin/env perl

use strict;
use 5.10.1;

use DateTime;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;

use Annex qw/:env annex_prod/;

use Data::Printer;

$|++;
select STDERR;
$|++;
select STDOUT;

my ($test, $debug, $file, $pretend);
my (@eml);

GetOptions(
    'e|email|emails:s'  => \@eml,
    'f|file=s'          => \$file,
    'p|pretend'         => \$pretend,
    't|test'            => \$test,
    'debug+'            => \$debug,
);

$file = $file || 'annex_tray_counts_'.DateTime->now(time_zone => "America/Indianapolis")->datetime.'.csv';

@eml = $test ?(scalar(@eml) ? ('jrittenh@nd.edu') : undef) : split(/,; /, join(',', @eml));

my $emails = join(',', @eml);

my $annexSQL = "SELECT aisle, shelf, size, COUNT(tray) AS tray_count ".
    "FROM ( ".
        "SELECT SUBSTRING(shelves.barcode FROM 7 FOR 1) AS \"aisle\", shelves.barcode AS \"shelf\", shelves.size AS \"size\", LEFT(shelves.size, 1) AS \"twidth\", RIGHT(shelves.size, 1) AS \"theight\", trays.barcode AS \"tray\" ".
        "FROM shelves INNER JOIN trays ON shelves.id = trays.shelf_id ".
    ") shelf_trays ".
    "GROUP BY aisle, shelf, size ".
    "ORDER BY aisle, shelf, size ".
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
    ($pretend ? ('test' => $pretend) : ()),
    'html'      => 'H',
    'from'      => 'Library Annex <noreply@library.nd.edu>',
) if ($emails);
