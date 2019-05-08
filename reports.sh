#!/bin/sh

#echo "RUN JOB"

export PERL5LIB=/home/app/perl5/lib/perl5
export RPT_PATH=/global/soft/aleph/src/annex

export EMAILS=${1:-annex-reports-list@nd.edu}

export DEBUG=${2:-false}

cd $RPT_PATH

if [[ $(date +%-H) -eq "8" ]] || [[ "$DEBUG" == "true" ]]; then
    # Daily Jobs
    ## Regular Jobs
    $RPT_PATH/workerStats.pl -e $EMAILS -d $(date +%Y%m%d -d "yesterday")

    if [[ $(date +%w) -eq "1" ]] || [[ "$DEBUG" == "true" ]]; then
        # Weekly Jobs
        $RPT_PATH/fillRequestRpt.pl -e $EMAILS
        $RPT_PATH/fillRequestRpt.pl -f 2015-08-24 -u $(date +%Y-%m-%d -d "last sunday") -e $EMAILS
        $RPT_PATH/shelfTrayCount.pl -e $EMAILS
        $RPT_PATH/shelfFillRpt.pl -e $EMAILS
    fi
    if { [[ $(date +%-d) -eq "1" ]] && [[ $(expr $(date +%m) / 3) -eq $(expr $(date +%m) / 3) ]] 2> /dev/null; } || [[ "$DEBUG" == "true" ]]; then
        $RPT_PATH/aisleTrayCounts.pl -e $EMAILS
        $RPT_PATH/shelfTrayList.pl -e $EMAILS
    fi
fi
