#!/bin/sh

#echo "RUN JOB"

export RPT_PATH=/global/soft/aleph/src/annex

cd $RPT_PATH

if [ `date +%H` = "08" ]; then
    # Daily Jobs
    ## Ingest Jobs/Jobs with Hallet copied on message
    #~ $RPT_PATH/shelfTrayCount.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d yesterday`
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d yesterday` -h
    #~ $RPT_PATH/shelfFillRpt.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
    #~ $RPT_PATH/ingestTime.pl

    ## Regular Jobs
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu -d `date +%Y%m%d -d yesterday`
    $RPT_PATH/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d yesterday`
    if [ `date +%w` = "1" ]; then
        # Weekly Jobs
        $RPT_PATH/fillRequestRpt.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
        $RPT_PATH/fillRequestRpt.pl -f 2015-08-24 -u `date +%Y-%m-%d -d "last sunday"` -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
        $RPT_PATH/shelfTrayCount.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
        $RPT_PATH/shelfFillRpt.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
    fi
fi

if [ `date +%H` = "18" ]; then
    echo ""
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d today`
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d today` -h
fi
