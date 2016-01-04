#!/bin/sh

#echo "RUN JOB"

export RPT_PATH=/global/soft/aleph/src/annex

export PERL5LIB=$RPT_PATH
#~ /home/jrittenh/aleph/scripts/annex/shelfTrayCount.pl -e jrittenh@nd.edu



if [ `date +%H` = "08" ]; then
    $RPT_PATH/shelfTrayCount.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu -d `date +%Y%m%d -d yesterday`
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d yesterday`
    #~ $RPT_PATH/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d yesterday` -h
    $RPT_PATH/shelfFillRpt.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
    #~ $RPT_PATH/ingestTime.pl
    if [ `date +%w` = "1" ]; then
        $RPT_PATH/fillRequestRpt.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu
        $RPT_PATH/fillRequestRpt.pl -f 2015-08-24 -u `date +%Y-%m-%d -d "last sunday"` -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu
    fi
fi
