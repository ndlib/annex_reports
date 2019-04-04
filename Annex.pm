package Annex;

use strict;
use Exporter;
use 5.10.1;
#~ use experimental qw/switch/;

use Carp;
use DateTime;
use DateTime::Duration;
use DateTime::Format::Duration;
use DBI;
use DBI qw/:sql_types/;
use MIME::Lite;
use Params::Validate 0.76 qw/validate validate_pos UNDEF SCALAR BOOLEAN ARRAYREF HASHREF/;
use Sys::Hostname;
use YAML::XS qw/LoadFile/;

binmode(STDOUT, ":utf8");

our ($VERSION, @ISA, @DEFAULT, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, @REQUIRED);
my (%libraries);
my ($environment);
my ($params);
chomp(our $start_es = `date +%s.%N`);

$VERSION = 1.00;
@ISA = qw/Exporter/;
@EXPORT = qw/alephQuery3 annexQuery getTimeChron getTimeString getTimeStringLong sendMail2/;
#~ @EXPORT_OK = qw//;
@DEFAULT = @EXPORT;
@REQUIRED = qw//;

use Env;            # import environmental variables
Env::import();      # equate env variables with Perl variables of same name

sub import {
    my $pkg = shift;
    my @in = @_;
    my %syms;
    @syms{@DEFAULT} = ('1') x scalar(@DEFAULT);
    $environment = 'local';
    while (my $symbol = shift @in) {
        if ($symbol =~ /^:env/) {
            $environment = lc(shift @in);
            if (-d 's' and -s "s/$environment") {
                $params = LoadFile("s/$environment");
            }
            p($params);
        } elsif ($symbol =~ /^(?:!|no_?)(.*)$/) {
            $syms{$1} = 0;
        } else {
            $syms{$symbol} = 1;
        }
    }
    unless (scalar(keys(%syms))) {
        @syms{@EXPORT} = ();
    } else {
        @syms{@REQUIRED} = 1;
    }
    local $Exporter::ExportLevel = 1;
    my @stuff = grep {%syms{$_} == 1} keys(%syms);
    $pkg->SUPER::import(@stuff);
}

sub alephQuery3 {
    my ($sql, $val, $prm) = @_;

    #~ say p($sql);
    #~ say p($val);
    #~ say p($prm);
    #~ return;

    my @values;
    if ($val) {
        @values = @$val;
    } else {
        @values = undef;
    }
    #~ say p(@values);

    my %params = %$prm if (ref($prm) eq 'HASH');

    state %lastSQL;

    $sql =~ s/\n//g;

    #~ my $key = getSQLKey($sql);

    state $sid = $params->{'db'};
    state $host = $params->{'host'};
    state $dbuser = $params->{'user'};
    state $dbpass = $params->{'pass'};
    state $port = $params->{'port'};

    state $dsn = "DBI:Oracle:host=$host;sid=$sid;port=$port";
    state $dbh = DBI->connect($dsn,$dbuser,$dbpass,{ ora_charset => 'AL32UTF8', RaiseError => 0, AutoCommit => 0 }) or croak("Unable to connect: $DBI::errstr");

    $lastSQL{$sql}{'sth'} = $dbh->prepare($sql) or croak("Could not prepare [ $sql ]: $!") unless (exists($lastSQL{$sql}));

    my $rslt = $val ? $lastSQL{$sql}{'sth'}->execute(@values) : $lastSQL{$sql}{'sth'}->execute() or croak("Could not execute [ $sql ]: $!");

    if (uc($sql) =~ /^SELECT (.*) FROM/) {
        if ($params{'return'} eq 'hash') {
            $rslt = $lastSQL{$sql}{'sth'}->fetchall_hashref(getSQLKey($sql));
        } elsif ($lastSQL{$sql}{'sth'}->{NUM_OF_FIELDS} == 1) {
            $rslt = $lastSQL{$sql}{'sth'}->fetchall_arrayref([0]);
        } else {
            $rslt = $lastSQL{$sql}{'sth'}->fetchall_arrayref({});
        }
    }

    if (defined($params{'last'}) && $params{'last'}) {
        if ($params{'last'} > 0) {
            $dbh->commit;
            $dbh->disconnect;
        } else {
            $dbh->rollback;
            $dbh->disconnect;
        }
    }

    return $rslt;
}

sub annexQuery {
    my ($sql, $val, $prm) = @_;

    #~ say p($sql);
    #~ say p($val);
    #~ say p($prm);
    #~ return;

    my @values;
    if ($val) {
        @values = @$val;
    } else {
        @values = undef;
    }
    my %params = %$prm if ($prm);

    state %lastSQL;

    $sql =~ s/\n//g;

    #~ my $key = getSQLKey($sql);


    state $host = $params->{'host'};
    state $dbuser = $params->{'user'};
    state $dbpass = $params->{'pass'};
    state $port = $params->{'port'};
    state $db = $params->{'db'};

    state $dsn = "DBI:Pg:host=$host;dbname=$db";
    state $dbh = DBI->connect($dsn,$dbuser,$dbpass,{ ora_charset => 'AL32UTF8', RaiseError => 0, AutoCommit => 0 }) or croak("Unable to connect: $DBI::errstr");

    $lastSQL{$sql}{'sth'} = $dbh->prepare($sql) or croak("Could not prepare [ $sql ]: $!") unless (exists($lastSQL{$sql}));

    my $rslt = $val ? $lastSQL{$sql}{'sth'}->execute(@values) : $lastSQL{$sql}{'sth'}->execute() or croak("Could not execute [ $sql ]: $!");

    if (uc($sql) =~ /^SELECT (.*) FROM/) {
        if ($params{'return'} eq 'hash') {
            $rslt = $lastSQL{$sql}{'sth'}->fetchall_hashref(lc(getSQLKey($sql)));
        } elsif ($lastSQL{$sql}{'sth'}->{NUM_OF_FIELDS} == 1) {
            $rslt = $lastSQL{$sql}{'sth'}->fetchall_arrayref([0]);
        } else {
            $rslt = $lastSQL{$sql}{'sth'}->fetchall_arrayref({});
        }
    }

    if (defined($params{'last'}) && $params{'last'}) {
        if ($params{'last'} > 0) {
            $dbh->commit;
            $dbh->disconnect;
        } else {
            $dbh->rollback;
            $dbh->disconnect;
        }
    }

    return $rslt;
}


sub sendMail2 {
    my $sendMailValidate = {
        'subject' => {
            'type'      => SCALAR,
            'optional'  => 1,
        },
        'body' => {
            'type'      => SCALAR,
            'optional'  => 1,
        },
        'emails' => {
            'type'      => SCALAR | ARRAYREF,
            'optional'  => 1,
        },
        'from' => {
            'type'      => SCALAR,
            'optional'  => 1,
        },
        'html' => {
            'type'      => SCALAR,
            'optional'  => 1,
        },
        'atch' => {
            'type'      => HASHREF,
            'optional'  => 1,
            'default'   => undef,
        },
        'length' => {
            type      => SCALAR,
            default   => 72,
            callbacks => {
                'an integer greater than 1' =>
                    sub { $_[0] =~ /^\d+$/ && $_[0] >= 1 },
            },
        },
        'test' => {
            type      => BOOLEAN,
            default   => 0,
            callbacks => {
                'a boolean integer, defaulting >0 to true' =>
                    sub { $_[0] =~ /^\d+$/ && $_[0] >= 0, },
            },
        },
        'silent' => {
            type      => BOOLEAN,
            default   => 0,
            callbacks => {
                'a boolean integer, defaulting >0 to true' =>
                    sub { $_[0] =~ /^\d+$/ && $_[0] >= 0, },
            },
        },
    };

    my %p = validate(@_, $sendMailValidate) or carp("Unable to validate parameters: $!");

    $p{'test'} += 0;
    $p{'silent'} += 0;

    $p{'subject'} .= '';
    chomp($p{'subject'});

    $p{'body'} .= '';
    chomp($p{'body'});

    carp("ALERT: Both subject and body are blank") if ($p{'subject'}.$p{'body'} eq '');

    $p{'emails'} = join(',', @{$p{'emails'}}) if (ref($p{'emails'}) eq 'ARRAY');
    $p{'test'}++ unless ($p{'emails'});

    $p{'length'} += 0;
    $p{'length'} = 72 unless ($p{'length'} > 1);

    delete $p{'atch'} unless(defined($p{'atch'}));

    exists($p{'from'}) ? () : ($p{'from'} = mailName('Admin', ($ENV{LOGNAME} || $ENV{USER} || getpwuid($<)).'@'.getHostName()));

    unless ($p{'silent'}) {
        print getLine(80, '=')."\n\n";

        unless ((defined($p{'test'}) && ($p{'test'} > 0)) || $p{'emails'} =~ /^$/) {
            print "Sending mail...";
        } elsif ($p{'emails'} =~ /^$/) {
            print "Nobody to send mail to. Would have sent the following message...";
        } else {
            print "Would send mail...";
        }
        print "\n\n";

        print getLine(80, '~')."\n";
        print "From: $p{'from'}\n";
        print "To:   $p{'emails'}\n";
        print getLine(5, '-')."\n";
        my $subject = wrapString("Subject: $p{'subject'}", 80);
        print $subject.(($subject =~ /\n$/) ? '' : "\n");
        print "Attachments: ".join(', ', keys(%{$p{'atch'}}))."\n" if (exists($p{'atch'}));
        print getLine(80, "-")."\n";
        my $body = $p{'body'}; #wrapString($p{'body'}, 80);
        if (defined($p{'html'}) && ($p{'html'} eq 'H')) {
            print $body.(($body =~ /\n$/) ? '' : "\n");
        } else {
            print wrapString($body).(($body =~ /\n$/) ? '' : "\n");
        }
        print getLine(80, '=')."\n";
    }

    unless ($p{'test'}) {
        utf8::encode($p{'body'});
        my $message = MIME::Lite->new(
            'From'          => $p{'from'},
            'To'            => $p{'emails'},
            'Subject'       => $p{'subject'},
            'Type'          => (exists($p{'atch'}) ? 'multipart/mixed' : ((defined($p{'html'}) && ($p{'html'} eq 'H')) ? 'text/html' : 'text/plain')),
            (exists($p{'atch'}) ? () : Data => $p{'body'}),
        );

        $message->attach(
            'Type'      => ((defined($p{'html'}) && ($p{'html'} eq 'H')) ? 'text/html' : 'text/plain'),
            'Encoding'  => 'quoted-printable',
            #~ 'Encoding'  => '8bit',
            'Data'      => $p{'body'}."\n",
        ) if (exists($p{'atch'}));

        foreach my $atch (keys(%{$p{'atch'}})) {
            $message->attach(
                Type        => $p{'atch'}{$atch}{'type'},
                Path        => $p{'atch'}{$atch}{'path'},
                Filename    => $atch,
                Disposition => 'attachment',
            );
        }

        $message->send();
        #~ $message->send_by_sendmail(SetSender => $p{'from'}, FromSender => $p{'from'});
    }
}

sub getTimeString {
    my ($rsec, $live) = @_;

    my $string = ((int($rsec / 3600) > 0) ? sprintf('%02d', int($rsec / 3600)).'h' : '').(((int(($rsec % 3600)/60) > 0) or ($live and (int($rsec / 3600) > 0))) ? sprintf('%02d', int(($rsec % 3600)/60)).'m' : '').(($live or ($rsec % 60 > 0)) ? (($rsec  < 10) ? sprintf('%0.1f', $rsec).'s' : sprintf('%02d', $rsec % 60).'s') : ((($rsec > 60) && ($rsec % 60 == 0)) ? '' : sprintf('%02d', $rsec).'s'));

    return $string;
}

sub getTimeChron {
    my ($rsec, $live) = @_;

    my $string = sprintf('%02d', int($rsec / 3600)).':'.sprintf('%02d', int(($rsec % 3600)/60)).':'.sprintf('%02d', $rsec % 60);

    return $string;
}

sub getTimeStringLong {
    my ($rsec) = @_;
    my %timeHash = getTimeHash($rsec);

    my $hours = $timeHash{'hours'} ? (($timeHash{'hours'} > 1) ? $timeHash{'hours'}." hours" : $timeHash{'hours'}." hour") : '';
    my $minutes = $timeHash{'minutes'} ? (($timeHash{'minutes'} > 1) ? $timeHash{'minutes'}." minutes" : $timeHash{'minutes'}." minute") : '';
    my $seconds = $timeHash{'seconds'} ? (($timeHash{'seconds'} > 1) ? $timeHash{'seconds'}." seconds" : $timeHash{'seconds'}." second") : '';

    my $time = $hours.($minutes ? ($hours ? ', ' : '').$minutes : '').($seconds ? (($hours || $minutes) ? ', ' : '').$seconds : (($hours || $minutes) ? '' : sprintf('%0.2f', $rsec)." seconds"));
    #~ (($hours || $minutes) ? ($seconds ? ", $seconds" : '') : ($seconds ? $seconds : sprintf('%0.2f', $rsec)." seconds"));

    return $time;
}

sub getTimeHash {
    my ($rsec) = @_;

    my %duration = (
        'hours' => int($rsec / 3600),
        'minutes' => int(($rsec % 3600)/60),
        'seconds' => $rsec % 60,
    );

    return %duration;
}

sub getLine {
    my $length = 72;
    my $char = '=';
    my $end = '';
    my $line = '';

    if (defined($_[0])) {
        $_[0] =~ /\d+/ ? $length = $_[0] : $char = $_[0];
    }

    if (defined($_[1])) {
        if ($_[1] =~ /\d+/) {
            $length = $_[1];
        } elsif ($_[1] =~ /.+/) {
              $char = $_[1];
        }
    }

    if (length($char) > 1) {
        $length = $length/length($char);
        if ($length%length($char) > 0) {
            $end = substr($char,0,$length%length($char));
        }
    }
    $line = ${char}x$length;
    $line = $line.$end if $end ne '';
    #~ $line = "$line\n";

    return $line;
}

sub wrapString {
    my $string = $_[0];
    my $length = defined($_[1]) ? $_[1] : 72;
    my @lines = split(/\n/, $string);
    my $line = '';
    my $wrapped = '';
    my $x = 0;
    my $y = 0;
    my $z = 0;

    my $indent;
    if ($string =~ /^(\w+: )/) {
        $indent = ' ' x length($1);
    }

    return $string if (length($string) <= $length);

    while ($x < @lines) {
        my $tab = '';
        unless(length($lines[$x]) > $length) {
            if ($wrapped eq '') {
                $wrapped = $lines[$x];
            } else {
                $wrapped = "$wrapped\n".$indent.$lines[$x];
            }
            $x++;
        } else {
            if ($lines[$x] =~ / \*  /) {
                $tab = "    ";
            }
            my @words = split(/(?<=\S) (?=[\S])/, $lines[$x]);
            $y = 0;
            $line = '';
            $z = 0;
            while ($y < @words) {
                unless (length("$line ".$words[$y]) > $length) {
                    # Length < 80;
                    if ($line eq '') {
                        $line = $words[$y];
                    } else {
                        $line = "$line ".$words[$y];
                    }
                    $y++;
                } else {
                    if ($wrapped eq '') {
                        $wrapped = $line;
                    } else {
                        if ($z == 0) {
                            $wrapped = "$wrapped\n$line";
                        } else {
                            $wrapped = "$wrapped\n$indent$tab$line";
                        }
                    }
                    $z++;
                    $line = '';
                }

                if ($y == scalar(@words)) {
                    $wrapped = "$wrapped\n$indent$tab$line";
                }
            }
            $x++;
        }
    }

    return "$wrapped\n";
}

1;
