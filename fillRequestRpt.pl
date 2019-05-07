#!/usr/bin/env perl

use strict;
use 5.10.1;

use DateTime;
use File::Temp qw/tempfile/;
use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use HTML::Entities;

use Annex qw/:env annex_prod/;

$|++;

my ($complete, $dates, $debug, $range, $showstats, $test, $from, $until);
my (@eml);

GetOptions(
    'c|complete'        => \$complete,
    'd|dates=s'         => \$dates,
    'e|email|emails=s'  => \@eml,
    'r|range=s'         => \$range,
    't|test'            => \$test,
    'f|from=s'          => \$from,
    'u|until=s'         => \$until,
    'debug+'            => \$debug,
);

my $datePattern = '^(\d{4})[\/\.-]?(\d{2})?[\/\.-]?(\d{2})?$';

my $emails = join(',', split(/,; /, join(',', @eml)));

$emails = $test ? 'jrittenh@nd.edu' : ($emails ? $emails : 'jrittenh@nd.edu');

die("Unable to process a defined range with start and end dates") if ($range && (($dates =~ /,/) || ($from && $until)));
die("Unable to process 'dates' and 'from'/'until' together") if ($dates && ($from || $until));

unless ($from || $until || $dates || $range) {
    $complete++;
    $range = 'week';
}

if ($dates =~ /,/) {
    ($from, $until) = split(/,/, $dates);
} elsif ($dates) {
    ($from, $until) = ($dates, $dates);
} else {
    $from = $from || DateTime->today(time_zone => "America/Indianapolis")->ymd();
    $until = $until || DateTime->today(time_zone => "America/Indianapolis")->ymd();
}

for ($from, $until) {
    if (/$datePattern/) {
        $_ = DateTime->new(
            time_zone   => "America/Indianapolis",
            year        => $1,
            month       => $2,
            day         => $3,
        );
    } else {
        die("$_ !~ /$datePattern/");
    }
}

for ($range) {
    when (/^y(ear)?$/) {
        $until->set(month => 12, day => 31);
        if ($complete) {
            $until->subtract(years => 1) while (DateTime->compare($until, DateTime->today(time_zone => "America/Indianapolis")) >= 0);
        }
        $from = $until->clone()->set(month => 1, day => 1);
    }
    when (/^mo?(nth)?$/) {
        $until = DateTime->last_day_of_month(
            time_zone   => "America/Indianapolis",
            year        => $until->year,
            month       => $until->month,
        );
        if ($complete) {
            $until->subtract(months => 1) while (DateTime->compare($until, DateTime->today(time_zone => "America/Indianapolis")) >= 0);
        }
        $from = $until->clone()->set(day => 1);
    }
    when (/^w(eek)?$/) {
        if ($complete) {
            $until->add(days => 1) while ((DateTime->compare($until, DateTime->today(time_zone => "America/Indianapolis")) < 0) && ($until->day_of_week() < 7));
        } else {
            $until->add(days => 1) while ($until->day_of_week() < 7);
        }
        $until->subtract(days => 1) while ($until->day_of_week() < 7);
        #~ $until->add(days => 1) while ($until->day_of_week() < 7);
        $from = $until->clone();
        $from->subtract(days => 1) while ($from->day_of_week() > 1);
    }
}

my $title = "Annex Filled Requests (".$from->ymd()." - ".$until->ymd().")";

#~ say $from->ymd();
#~ say $until->ymd();
#~ exit;

my $sql = 'SELECT '.
        "EXTRACT(EPOCH FROM b.created_at AT TIME ZONE 'UTC') AS \"req\", ".
        "EXTRACT(EPOCH FROM p.created_at AT TIME ZONE 'UTC') AS \"pull\", ".
        "EXTRACT(EPOCH FROM a.created_at AT TIME ZONE 'UTC') AS \"fill\", ".
        "a.data->'request'->'source' AS \"src\", ".
        "a.data->'request'->'req_type' AS \"type\", ".
        "a.data->'request'->'del_type' AS \"del\", ".
        "a.data->'request'->'patron_status' AS \"patron\", ".
        "a.data->'request'->'patron_institution' AS \"inst\", ".
        "a.data->'request'->'patron_department' AS \"dept\", ".
        "a.data->'request'->'pickup_location' AS \"dest\", ".
        "TRIM(SUBSTR(i.call_number,1,2)) AS \"class\" ".
    "FROM activity_logs a ".
        "LEFT JOIN items i ON CAST(a.data->'request'->>'item_id' AS INTEGER) = i.id ".
        "LEFT JOIN activity_logs b ON CAST(a.data->'request'->>'id' AS INTEGER) = CAST(b.data->'request'->>'id' AS INTEGER) AND b.action = 'ReceivedRequest' ".
        "LEFT JOIN activity_logs p ON CAST(a.data->'request'->>'item_id' AS INTEGER) = CAST(p.data->'item'->>'id' AS INTEGER) AND p.action = 'AssociatedItemAndBin' AND p.created_at BETWEEN b.created_at AND a.created_at ".
        #~ "LEFT JOIN activity_logs p ON a.data->'request'->'id' = p.data->'request'->'id' AND p.action = 'AssociatedItemAndBin' AND p.created_at BETWEEN b.created_at AND a.created_at ".
        #~ "LEFT JOIN activity_logs p ON a.data->'request'->'id' = p.data->'request'->'id' AND p.created_at BETWEEN b.created_at AND a.created_at ".
    "WHERE a.action = 'FilledRequest' ".
        "AND date(p.created_at::timestamp AT TIME ZONE 'UTC') BETWEEN '".$from->date()."' AND '".$until->date()."' ".
    "ORDER BY ".
    "EXTRACT(EPOCH FROM p.created_at AT TIME ZONE 'UTC'), ".
    "EXTRACT(EPOCH FROM b.created_at AT TIME ZONE 'UTC'), ".
    "EXTRACT(EPOCH FROM a.created_at AT TIME ZONE 'UTC') ".
    '';

say $sql if ($debug);

my @rptCols = (
    {
        'id'    => 'requested',
        'label' => 'Requested',
    },
    {
        'id'    => 'pulled',
        'label' => 'Pulled',
    },
    {
        'id'    => 'filled',
        'label' => 'Filled',
    },
    {
        'id'    => 'src',
        'label' => 'Source',
    },
    {
        'id'    => 'type',
        'label' => 'Request Type',
    },
    {
        'id'    => 'del',
        'label' => 'Delivery Type',
    },
    {
        'id'    => 'patron',
        'label' => "Patron Status",
    },
    {
        'id'    => 'inst',
        'label' => 'Institution',
    },
    {
        'id'    => 'dept',
        'label' => 'Department',
    },
    {
        'id'    => 'dest',
        'label' => 'Pickup Location',
    },
    {
        'id'    => 'class',
        'label' => 'Class',
    },
    {
        'id'    => 'pdur',
        'label' => 'Time to Pull',
    },
    {
        'id'    => 'dur',
        'label' => 'Time to Fill',
    },
);

my $data = annexQuery($sql);

my $table;

$table = "<table>\n";
$table .= "<tr>\n";
$table .= join('', map {"    <th>".$_->{'label'}."</th>\n"} @rptCols);
$table .= "</tr>\n";

my $stats = {};

my ($fh, $rptPath) = tempfile();
say $fh join(",", map {'"'.$_->{'label'}.'"'} @rptCols);
#~ say join("\t", map {$_->{'label'}} @rptCols);
foreach my $request (@$data) {
    foreach my $col (keys(%$request)) {
        $request->{$col} =~ s/^"(.*)"$/$1/;
    }
    $request->{'secs'} = $request->{'fill'} - $request->{'req'};
    $request->{'psecs'} = $request->{'pull'} - $request->{'req'};
    $request->{'reqDT'} = DateTime->from_epoch(epoch => $request->{'req'} // 0, time_zone => "America/Indianapolis");
    $request->{'pullDT'} = DateTime->from_epoch(epoch => $request->{'pull'} // 0, time_zone => "America/Indianapolis");
    $request->{'fillDT'} = DateTime->from_epoch(epoch => $request->{'fill'} // 0, time_zone => "America/Indianapolis");
    $request->{'requested'} = $request->{'reqDT'}->ymd().' '.$request->{'reqDT'}->hms();
    $request->{'pulled'} = $request->{'pullDT'}->ymd().' '.$request->{'pullDT'}->hms();
    $request->{'filled'} = $request->{'fillDT'}->ymd().' '.$request->{'fillDT'}->hms();
    #~ $request->{'dur'} = getTimeStringLong($request->{'secs'});
    $request->{'pdur'} = getTimeChron($request->{'psecs'});
    $request->{'dur'} = getTimeChron($request->{'secs'});

    say $fh join(",", map {'"'.$request->{$_->{'id'}}.'"'} @rptCols);
    say join("\t", map {$request->{$_->{'id'}}} @rptCols);
    $table .= "<tr>\n";
    $table .= join('', map {"    <td ".(($_->{'align'} || $_->{'width'}) ? 'style="'.($_->{'align'} ? "text-align: ".$_->{'align'}.';' : '').($_->{'width'} ? "width: ".$_->{'width'}.';' : '') : '').'">'.$request->{$_->{'id'}}."</td>\n"} @rptCols);
    $table .= "</tr>\n";

    $stats->{'psecs'}{'sum'} += $request->{'psecs'};
    $stats->{'secs'}{'sum'} += $request->{'secs'};
    $stats->{'count'}++;
}
close($fh);
say $rptPath;

if ($showstats) {
    #~ $stats->{'psecs'}{'avg'} = $stats->{'psecs'}{'sum'} / $stats->{'count'};
    #~ $stats->{'secs'}{'avg'} = $stats->{'secs'}{'sum'} / $stats->{'count'};
    $stats->{'tot'}{'dest'} = "Total:";
    $stats->{'tot'}{'pdur'} = getTimeChron($stats->{'psecs'}{'sum'});
    $stats->{'tot'}{'dur'} = getTimeChron($stats->{'secs'}{'sum'});
    $stats->{'avg'}{'dest'} = "Average:";
    $stats->{'avg'}{'pdur'} = getTimeChron($stats->{'psecs'}{'sum'} / $stats->{'count'});
    $stats->{'avg'}{'dur'} = getTimeChron($stats->{'secs'}{'sum'} / $stats->{'count'});

    $table .= "<tr>\n";
    $table .= join('', map {$stats->{'tot'}{$_->{'id'}} ? "    <td ".(($_->{'align'} || $_->{'width'}) ? 'style="'.($_->{'align'} ? "text-align: ".$_->{'align'}.';' : '').($_->{'width'} ? "width: ".$_->{'width'}.';' : '') : '').'">'.$stats->{'tot'}{$_->{'id'}}."</td>\n" : "<td/>"} @rptCols);
    $table .= "</tr>\n";
}

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
$body .= "</html>";

if ($test) {
    open(my $htmlFH, '>', 'report.html');
    say $htmlFH $body;
    close($htmlFH);
}

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
