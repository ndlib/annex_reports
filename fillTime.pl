#!/usr/bin/env perl

use strict;
use 5.10.1;

use DateTime;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use HTML::Entities;

use Annex qw/:env annex_prod/;

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

my $title = "Annex Fill Times (".$start->ymd()." - ".$end->ymd().")";

#~ say $start->date;
#~ say $end->date;
#~ exit;

my $sql = 'SELECT '.
        "EXTRACT(EPOCH FROM b.created_at AT TIME ZONE 'UTC') AS \"req\", ".
        "EXTRACT(EPOCH FROM p.created_at AT TIME ZONE 'UTC') AS \"pull\", ".
        "EXTRACT(EPOCH FROM a.created_at AT TIME ZONE 'UTC') AS \"fill\" ".
    "FROM activity_logs a ".
        "LEFT JOIN activity_logs b ON a.data->'request'->'id' = b.data->'request'->'id' AND b.action = 'ReceivedRequest' ".
        "LEFT JOIN activity_logs p ON a.data->'request'->'id' = p.data->'request'->'id' AND p.action = 'AssociatedItemAndBin' AND p.created_at BETWEEN b.created_at AND a.created_at".
    "WHERE a.action = 'FilledRequest' ".
        "AND date(a.created_at::timestamp AT TIME ZONE 'UTC') BETWEEN '".$start->date()."' AND '".$end->date()."' ".
    "ORDER BY EXTRACT(EPOCH FROM p.created_at AT TIME ZONE 'UTC'), EXTRACT(EPOCH FROM b.created_at AT TIME ZONE 'UTC'), EXTRACT(EPOCH FROM a.created_at AT TIME ZONE 'UTC') ".
    '';

my @rptCols = (
    {
        'id'    => 'req',
        'label' => 'Requested',
    },
    {
        'id'    => 'pull',
        'label' => 'Pulled',
    },
    {
        'id'    => 'fill',
        'label' => 'Filled',
    },
    {
        'id'    => 'time',
        'label' => 'Time to Fill',
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
    #~ my ($start, $pulled, $stop) = ($request->{'req'}, $request->{'pull'}, $request->{'fill'});
    $request->{'start'} = DateTime->from_epoch(epoch => $request->{'req'}, time_zone => "America/Indianapolis");
    $request->{'pulled'} = DateTime->from_epoch(epoch => $request->{'pull'}, time_zone => "America/Indianapolis");
    $request->{'stop'} = DateTime->from_epoch(epoch => $request->{'fill'}, time_zone => "America/Indianapolis");
    $request->{'psecs'} = $request->{'pull'} - $request->{'req'};
    $request->{'secs'} = $request->{'fill'} - $request->{'req'};
    #~ my $timeString = getTimeStringLong($request->{'secs'});
    my $timeString = getTimeChron($request->{'secs'});
    my $pTimeSTring = getTimeChron($request->{'psecs'});

    say $fh '"'.$request->{'start'}->ymd().' '.$request->{'start'}->hms().'","'.$request->{'stop'}->ymd().' '.$request->{'stop'}->hms().'","'.$timeString.'"';
    $table .= "<tr>\n";
    $table .= '    <td>'.$request->{'start'}->ymd().' '.$request->{'start'}->hms()."</td>\n";
    $table .= '    <td>'.$request->{'stop'}->ymd().' '.$request->{'stop'}->hms()."</td>\n";
    $table .= "    <td style=\"text-align: right\">$timeString</td>\n";
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
$body .= "             text-align: left;\n";
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
