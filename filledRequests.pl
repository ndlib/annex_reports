#!/usr/bin/env perl

use strict;
use 5.10.1;

use Justin;
use Justin qw/:annex/;

use Data::Printer;
use DateTime;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use HTML::Entities;

use Justin;
use Justin qw/:annex sendMail2/;

$|++;

my ($dates, $emails, $test);

GetOptions(
    'd|dates=s'         => \$dates,
    'e|email|emails=s'  => \$emails,
    't|test'            => \$test,
);

$emails = $test ? 'jrittenh@nd.edu' : ($emails ? $emails : 'jrittenh@nd.edu');

my ($start, $end);
if ($dates) {
    if ($dates =~ /,/) {
        ($start, $end) = split(/,/, $dates);
    } else {
        ($start, $end) = ($dates, $dates);
    }
    for ($start, $end) {
        if ($_ =~ /(\d{4})[\/\.-]?(\d{2})[\/\.-]?(\d{2})/) {
            $_ = DateTime->new(
                year => $1,
                month => $2,
                day => $3,
            );
        }
    }
} else {
    $end = DateTime->today(time_zone => "America/Indianapolis");
    $end->subtract(days => 1) while ($end->day_of_week() < 7);
    $start = $end->clone();
    $start->subtract(days => 1) while ($start->day_of_week() > 1);
}

my $title = "Annex Filled Requests (".$start->ymd()." - ".$end->ymd().")";

#~ say $start->date;
#~ say $end->date;
#~ exit;

my $sql = 'SELECT '.
        "date(a.created_at::timestamp AT TIME ZONE 'UTC') AS \"date\", ".
        "data->'request'->'source' AS \"src\", ".
        "data->'request'->'req_type' AS \"type\", ".
        "data->'request'->'patron_status' AS \"patron\", ".
        "data->'request'->'patron_institution' AS \"inst\", ".
        "data->'request'->'patron_department' AS \"dept\", ".
        "data->'request'->'pickup_location' AS \"dest\", ".
        "TRIM(SUBSTR(i.call_number,1,2)) AS \"class\" ".
    "FROM activity_logs a ".
        "LEFT JOIN items i ON CAST(data->'request'->>'item_id' AS INTEGER) = i.id ".
    "WHERE action = 'FilledRequest' ".
        "AND CAST(data->'request'->>'item_id' AS INTEGER) = i.id ".
        "AND date(a.created_at::timestamp AT TIME ZONE 'UTC') BETWEEN '".$start->date()."' AND '".$end->date()."' ".
    "ORDER BY date(a.created_at::timestamp AT TIME ZONE 'UTC') ".
    '';

my @rptCols = (
    {
        'id'    => 'date',
        'label' => 'Date',
        'width' => '65px',
    },
    {
        'id'    => 'src',
        'label' => 'Source',
    },
    {
        'id'    => 'type',
        'label' => 'Type',
    },
    {
        'id'    => 'patron',
        'label' => "Patron Status",
    },
    {
        'id'    => 'inst',
        'label' => 'Institution',
        'width' => '150px',
    },
    {
        'id'    => 'dept',
        'label' => 'Department',
    },
    {
        'id'    => 'dest',
        'label' => 'Pickup Location',
        'width' => '160px',
    },
    {
        'id'    => 'class',
        'label' => 'Class',
    },
);

my $data = annexQuery($sql);

my $table;

$table = "<table>\n";
$table .= "<tr>\n";
$table .= join('', map {"    <th>".$_->{'label'}."</th>\n"} @rptCols);
$table .= "</tr>\n";

my ($fh, $rptPath) = tempfile();
say $fh join(",", map {'"'.$_->{'label'}.'"'} @rptCols);
#~ say join("\t", map {$_->{'label'}} @rptCols);
foreach my $request (@$data) {
    foreach my $col (keys(%$request)) {
        $request->{$col} =~ s/^"(.*)"$/$1/;
    }
    say $fh join(",", map {'"'.$request->{$_->{'id'}}.'"'} @rptCols);
    #~ say join("\t", map {$request->{$_->{'id'}}} @rptCols);
    $table .= "<tr>\n";
    $table .= join('', map {"    <td ".(($_->{'align'} || $_->{'width'}) ? 'style="'.($_->{'align'} ? "text-align: ".$_->{'align'}.';' : '').($_->{'width'} ? "width: ".$_->{'width'}.';' : '') : '').'">'.$request->{$_->{'id'}}."</td>\n"} @rptCols);
    $table .= "</tr>\n";
}
close($fh);
say $rptPath;

$table .= "</table>\n";

my $body = '';
$body .= "<html>\n";
$body .= "<head>\n";
$body .= "    <meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\"/>\n";
$body .= "    <title>$title</title>\n";
$body .= "    <style type=\"text/css\">\n";
$body .= "        table, tr, th, td {\n";
$body .= "             border: 1px solid black;\n";
$body .= "             border-collapse: collapse;\n";
$body .= "             padding: 3px;\n";
$body .= "             text-align: center;\n";
$body .= "        }\n";
$body .= "    </style>\n";
$body .= "</head>\n";
$body .= "<body>\n";
$body .= "<h1>$title</h1>";
$body .= $table;
$body .= "</body>\n";
#~ $body .= "<body><pre style=\"font-size: 12pt;\">".encode_entities("$erpt\n$rpt\n$frpt")."</pre></body>";
$body .= "</html>";

my $rptFile = $title.DateTime->now(time_zone => "America/Indianapolis")->datetime().".csv";
$rptFile =~ s/ //g;

sendMail2(
    'subject'   => "$title ".DateTime->now(time_zone => "America/Indianapolis")->datetime(),
    'body'      => $body,
    'html'      => 'H',
    'atch'      => {$rptFile, => {'path' => $rptPath, 'type' => 'text/csv'}},
    'emails'    => $emails,
    'from'      => 'Library Annex <noreply@library.nd.edu>',
);
