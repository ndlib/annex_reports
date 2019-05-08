#!/bin/sh

#echo "RUN JOB"

export RPT_PATH=/global/soft/aleph/src/annex

cd $RPT_PATH

if [[ $(date +%H) = "08" ]]; then
    # Daily Jobs
    ## Regular Jobs
    $RPT_PATH/workerStats.pl -e annex-reports-list@nd.edu -d $(date +%Y%m%d -d yesterday)

    if [[ $(date +%w) = "1" ]]; then
        # Weekly Jobs
        $RPT_PATH/fillRequestRpt.pl -e annex-reports-list@nd.edu
        $RPT_PATH/fillRequestRpt.pl -f 2015-08-24 -u $(date +%Y-%m-%d -d "last sunday") -e annex-reports-list@nd.edu
        $RPT_PATH/shelfTrayCount.pl -e annex-reports-list@nd.edu
        $RPT_PATH/shelfFillRpt.pl -e annex-reports-list@nd.edu
    fi
fi
