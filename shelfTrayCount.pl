#!/usr/bin/env perl

use strict;
use 5.10.1;

use DateTime;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use HTML::Entities;

use Justin;
use Justin qw/:annex sendMail2/;

$|++;

my ($emails, $test);

GetOptions(
    'e|email|emails=s'  => \$emails,
    't|test'            => \$test,
);

$emails = $test ? 'jrittenh@nd.edu' : ($emails ? $emails : 'jrittenh@nd.edu');


my %shelfSize = (
    'AL'    => 16,
    'AH'    => 16,
    'BL'    => 14,
    'BH'    => 14,
    'CL'    => 12,
    'CH'    => 12,
    'DL'    => 10,
    'DH'    => 10,
    'EL'    => 12,
    'EH'    => 12,
);

my $sql = 'SELECT shelves.barcode AS "barcode", shelves.size AS "tray_size", COUNT(*) as "trays" FROM trays, shelves WHERE trays.shelf_id = shelves.id GROUP BY shelves.barcode, shelves.size ORDER BY shelves.barcode';

my $data = annexQuery($sql);

my $rpt = "Partially Full Shelves\n".sprintf('%-13s', 'Shelf')." | Trays | Expected | Size\n".('-' x 39)."\n";
my $printout = "Partially Full Shelves\nShelf,Trays,Exepected,Size\n";

my $erpt = "Invalid Shelves\n".sprintf('%-26s', 'Shelf')." | Trays | Expected | Size\n".('-' x 51)."\n";
my $eprintout = "Invalid Shelves\nShelf,Trays,Expected,Size\n";

my $frpt = "Full Shelves\n".sprintf('%-13s', 'Shelf')." | Trays\n".('-' x 21)."\n";
my $fprintout = "Full Shelves\nShelf,Trays\n";

#~ say p($data);
#~ exit;

my ($table, $etable);

$table = "<table>\n";
$table .= "    <tr>\n";
$table .= "        <th>Shelf</th>\n";
$table .= "        <th style=\"text-align: right;\">Trays</th>\n";
$table .= "        <th style=\"text-align: right;\">Expected</th>\n";
$table .= "        <th style=\"text-align: center;\">Size</th>\n";
$table .= "    </tr>\n";

$etable = $table;

foreach my $sf (@{$data}) {
    my %shelf = %$sf;
    
    if (($shelf{'barcode'} =~ /^SHELF-\w-\d{3}-\w$/) && ($shelf{'trays'} == $shelfSize{$shelf{'tray_size'}})) {
        $frpt .= sprintf('%-13s', $shelf{'barcode'})." | ".sprintf('%5d', $shelf{'trays'})."\n";
        $fprintout .= "$shelf{'barcode'},$shelf{'trays'}\n";
    } elsif (($shelf{'barcode'} =~ /^SHELF-\w-\d{3}-\w$/) && (($shelf{'trays'} < $shelfSize{$shelf{'tray_size'}}) || ($shelf{'tray_size'} =~ /SHELF/))) {
        $rpt .= sprintf('%-13s', $shelf{'barcode'})." | ".sprintf('%5d', $shelf{'trays'})." | ".sprintf('%8d', $shelfSize{$shelf{'tray_size'}})." | ".sprintf('%-4s', $shelf{'tray_size'})."\n";
        $printout .= "$shelf{'barcode'},$shelf{'trays'},$shelfSize{$shelf{'tray_size'}},$shelf{'tray_size'}\n";
        $table .= "    <tr>\n";
        $table .= "        <td>$shelf{'barcode'}</td>\n";
        $table .= "        <td style=\"text-align: right;\">$shelf{'trays'}</td>\n";
        $table .= "        <td style=\"text-align: right;\">$shelfSize{$shelf{'tray_size'}}</td>\n";
        $table .= "        <td style=\"text-align: center;\">$shelf{'tray_size'}</td>\n";
        $table .= "    </tr>\n";
    } else {
        $erpt .= sprintf('%-26s', $shelf{'barcode'})." | ".sprintf('%5d', $shelf{'trays'})." | ".sprintf('%8d', $shelfSize{$shelf{'tray_size'}})." | ".sprintf('%-4s', $shelf{'tray_size'})."\n";
        $eprintout .= "$shelf{'barcode'},$shelf{'trays'},$shelfSize{$shelf{'tray_size'}},$shelf{'tray_size'}\n";
        $etable .= "    <tr>\n";
        $etable .= "        <td>$shelf{'barcode'}</td>\n";
        $etable .= "        <td style=\"text-align: right;\">$shelf{'trays'}</td>\n";
        $etable .= "        <td style=\"text-align: right;\">$shelfSize{$shelf{'tray_size'}}</td>\n";
        $etable .= "        <td style=\"text-align: center;\">$shelf{'tray_size'}</td>\n";
        $etable .= "    </tr>\n";
    }
}

$table .= "</table>\n";
$etable .= "</table>\n";

my $body = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional //EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n";
$body .= "<html>\n";
$body .= "<head>\n";
$body .= "    <meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\"/>\n";
$body .= "    <title>Annex Shelf Tray Count</title>\n";
$body .= "    <style type=\"text/css\">\n";
$body .= "        table, tr, th, td {\n";
$body .= "             border: 1px solid black;\n";
$body .= "             border-collapse: collapse;\n";
$body .= "             padding: 3px;\n";
$body .= "             text-align: left;\n";
$body .= "        }\n";
$body .= "    </style>\n";
$body .= "</head>\n";
$body .= "<body>\n";
$body .= "Invalid/Overfull Shelves\n$etable<br/>Partially Full Shelves\n$table";
$body .= "</body>\n";
#~ $body .= "<body><pre style=\"font-size: 12pt;\">".encode_entities("$erpt\n$rpt\n$frpt")."</pre></body>";
$body .= "</html>";


my $rptFile = 'annexShelfTrayCount'.DateTime->now(time_zone => "America/Indianapolis")->datetime().'.csv';
my ($fh, $rptPath) = tempfile();
print $fh "$eprintout\n$printout\n$fprintout";
close($fh);

sendMail2(
    'subject'   => "Annex Shelf Tray Count ".DateTime->now(time_zone => "America/Indianapolis")->datetime(),
    'body'      => $body,
    'html'      => 'H',
    'atch'      => {$rptFile, => {'path' => $rptPath, 'type' => 'text/csv'}},
    'emails'    => $emails,
    'from'      => 'Library Annex <noreply@library.nd.edu>',
);
