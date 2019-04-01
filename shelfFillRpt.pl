#!/usr/bin/env perl

use strict;
use experimental qw/smartmatch/;
use 5.10.1;

use DateTime;
use DBI;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use HTML::Entities;
use Time::HiRes qw/time gettimeofday/;

use Data::Printer;

use Justin;
use Justin qw/:oracle :annex/;

$|++;
select STDERR;
$|++;
select STDOUT;

my ($emails, $file, $pretend, $test);

GetOptions(
    'e|emails=s'    => \$emails,
    'f|file=s'      => \$file,
    'p|pretend'     => \$pretend,
    't|test'        => \$test,
);
$emails = $test ? 'jrittenh@nd.edu' : ($emails ? $emails : 'jrittenh@nd.edu');

my %widths = (
    'A' => 140,
    'B' => 140,
    'C' => 140,
    'D' => 140,
    'E' => 92,
);
my $threshold = .9;

# A-D = 18 inches
# E = 12 inches
# Subtract .5 inches for cardboard thickness to get max item width

my $annexSQL = "SELECT shelf, size, twidth, theight, tray, COUNT(item) AS \"items\", SUM(thickness) AS \"width\", SUM(thickness) / 8::float AS \"inches\", AVG(thickness) AS \"avg\", MAX(thickness) AS \"max\", MIN(thickness) AS \"min\" ".
    "FROM ( ".
        "SELECT shelves.barcode AS \"shelf\", shelves.size AS \"size\", LEFT(shelves.size, 1) AS \"twidth\", RIGHT(shelves.size, 1) AS \"theight\", trays.barcode AS \"tray\", items.barcode AS \"item\", items.thickness ".
        "FROM shelves INNER JOIN trays ON shelves.id = trays.shelf_id ".
        #~ "INNER JOIN items ON trays.id = items.tray_id ".
        "LEFT JOIN items ON trays.id = items.tray_id ".
    ") stocked_items ".
    "GROUP BY shelf, size, tray, twidth, theight ".
    "";

my $data = annexQuery($annexSQL);

$file = $file ? $file : 'shelfFillRpt'.DateTime->now(time_zone => "America/Indianapolis")->datetime().'.csv';
my ($fh, $filePath) = tempfile();
say $fh "shelf,size,tray,items,width,inches,percent,average,maximum,minimum";

my ($rpt, $erpt);
my ($table, $etable);

$rpt .= join(' | ', (sprintf('%-13s', 'shelf'), sprintf('%-4s', 'size'), sprintf('%-12s', 'tray'), sprintf('%5s', 'items'), sprintf('%5s', 'width'), sprintf('%6s', 'percent')))."\n";
$rpt .= '-' x length(join(' | ', (sprintf('%-13s', 'shelf'), sprintf('%-4s', 'size'), sprintf('%-12s', 'tray'), sprintf('%5s', 'items'), sprintf('%5s', 'width'), sprintf('%6s', 'percent'))))."\n";

$erpt .= join(' | ', (sprintf('%-40s', 'shelf'), sprintf('%-4s', 'size'), sprintf('%-40s', 'tray'), sprintf('%5s', 'items'), sprintf('%5s', 'width'), sprintf('%6s', 'percent')))."\n";
$erpt .= '-' x length(join(' | ', (sprintf('%-40s', 'shelf'), sprintf('%-4s', 'size'), sprintf('%-40s', 'tray'), sprintf('%5s', 'items'), sprintf('%5s', 'width'), sprintf('%6s', 'percent'))))."\n";

$table = "<table>\n";
$table .= "    <tr>\n";
$table .= "        <th>Shelf</th>\n";
$table .= "        <th style=\"text-align: center;\">Size</th>\n";
$table .= "        <th>Tray</th>\n";
$table .= "        <th style=\"text-align: right;\">Items</th>\n";
$table .= "        <th style=\"text-align: right;\">Width</th>\n";
$table .= "        <th style=\"text-align: right;\">Percent</th>\n";
#~ $table .= join ('', map("        <th>$_</th>\n", ('shelf', 'size', 'tray', 'items', 'width', 'percent')));
$table .= "    </tr>\n";

$etable = $table;

foreach my $tray (sort {$a->{'shelf'} cmp $b->{'shelf'} || $a->{'tray'} cmp $b->{'tray'}} @$data) {
    next if ($tray->{'tray'} =~ /^TRAY-$tray->{'shelf'}/);
    if ($tray->{'width'} < int(($widths{$tray->{'twidth'}} * $threshold) + .5)) {
        if ($tray->{'shelf'} =~ /^SHELF-\w-\d{3}-\w$/ && $tray->{'tray'} =~ /^TRAY-\w\w\d{5}$/) {
            $rpt .= join(' | ', (sprintf('%-13s', $tray->{'shelf'}), sprintf('%-4s', $tray->{'size'}), sprintf('%-12s', $tray->{'tray'}), sprintf('%5d', $tray->{'items'}), sprintf('%5d', $tray->{'width'}), sprintf('%7.2f', 100 * ($tray->{'width'} / $widths{$tray->{'twidth'}}))))."\n";
            #~ $table .= "    <tr>\n".join ('', map("        <td>$_</td>\n", ($tray->{'shelf'}, $tray->{'size'}, $tray->{'tray'}, $tray->{'items'}, $tray->{'inches'}, 100 * ($tray->{'width'} / $widths{$tray->{'twidth'}}))))."    \n</tr>\n";
            $table .= "    <tr>\n";
            $table .= "        <td>$tray->{'shelf'}</td>\n";
            $table .= "        <td style=\"text-align: center;\">$tray->{'size'}</td>\n";
            $table .= "        <td>$tray->{'tray'}</td>\n";
            $table .= "        <td style=\"text-align: right;\">$tray->{'items'}</td>\n";
            $table .= "        <td style=\"text-align: right;\">".sprintf('%1d', $tray->{'width'})."</td>\n";
            $table .= "        <td style=\"text-align: right;\">".sprintf('%.2f', 100 * ($tray->{'width'} / $widths{$tray->{'twidth'}}))."</td>\n";
            $table .= "    </tr>\n";
        } else {
            $erpt .= join(' | ', (sprintf('%-40s', $tray->{'shelf'}), sprintf('%-4s', $tray->{'size'}), sprintf('%-40s', $tray->{'tray'}), sprintf('%5d', $tray->{'items'}), sprintf('%5d', $tray->{'width'}), sprintf('%7.2f', 100 * ($tray->{'width'} / $widths{$tray->{'twidth'}}))))."\n";
            #~ $etable .= "    <tr>\n".join ('', map("        <td>$_</td>\n", ($tray->{'shelf'}, $tray->{'size'}, $tray->{'tray'}, $tray->{'items'}, $tray->{'inches'}, 100 * ($tray->{'width'} / $widths{$tray->{'twidth'}}))))."    </tr>\n";
            $etable .= "    <tr>\n";
            $etable .= "        <td>$tray->{'shelf'}</td>\n";
            $etable .= "        <td style=\"text-align: center;\">$tray->{'size'}</td>\n";
            $etable .= "        <td>$tray->{'tray'}</td>\n";
            $etable .= "        <td style=\"text-align: right;\">$tray->{'items'}</td>\n";
            $etable .= "        <td style=\"text-align: right;\">".sprintf('%1d', $tray->{'width'})."</td>\n";
            $etable .= "        <td style=\"text-align: right;\">".sprintf('%.2f', 100 * ($tray->{'width'} / $widths{$tray->{'twidth'}}))."</td>\n";
            $etable .= "    </tr>\n";
        }
        say $fh join(',', ($tray->{'shelf'}, $tray->{'size'}, $tray->{'tray'}, $tray->{'items'}, $tray->{'width'}, $tray->{'inches'}, 100 * ($tray->{'width'} / $widths{$tray->{'twidth'}}), $tray->{'avg'}, $tray->{'max'}, $tray->{'min'}));
    }
}
close($fh);

$table .= "</table>\n";
$etable .= "</table>\n";

my $body = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional //EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n";
$body .= "<html>\n";
$body .= "<head>\n";
$body .= "    <meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\"/>\n";
$body .= "    <title>Shelf Fill Report</title>\n";
$body .= "    <style type=\"text/css\">\n";
$body .= "        table, tr, th, td {\n";
$body .= "             border: 1px solid black;\n";
$body .= "             border-collapse: collapse;\n";
$body .= "             padding: 3px;\n";
$body .= "             text-align: left;\n";
$body .= "        }\n";
#~ $body .= "        .right {\n";
#~ $body .= "             text-align: right;\n";
#~ $body .= "        }\n";
$body .= "    </style>\n";
$body .= "</head>\n";
#~ $body .= "<body>\n<pre style=\"font-size: 12pt;\">".encode_entities($rpt)."\n".encode_entities($erpt)."</pre>\n</body>";
$body .= "<body>\n";
$body .= $table;
$body .= "    <br/>\n";
$body .= $etable;
$body .= "</body>\n";
$body .= "</html>\n";


sendMail2(
    'subject'   => 'Tray Fill Report '.DateTime->now(time_zone => "America/Indianapolis")->datetime,
    'body'      => $body,
    'emails'    => $emails,
    'atch'      => {$file, => {'path' => $filePath, 'type' => 'text/csv'}},
    ($pretend ? ('test' => $pretend) : ()),
    'html'      => 'H',
    'from'      => 'Library Annex <noreply@library.nd.edu>',
);

#trays
#---
#id
#barcode
#shelf_id
#created_at
#updated_at
#shelved

#shelves
#---
#id
#barcode
#created_at
#updated_at
#size

#items
#---
#id
#barcode
#title
#author
#chron
#thickness
#tray_id
#created_at
#updated_at
#bib_number
#isbn_issn
#conditions
#call_number
#initial_ingest
#last_ingest
#bin_id
#status
#metadata_updated_at
#metadata_status
