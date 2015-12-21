#!/bin/sh

#echo "RUN JOB"

export PERL5LIB=/Users/jrittenh/aleph/scripts/modules
#~ /home/jrittenh/aleph/scripts/annex/shelfTrayCount.pl -e jrittenh@nd.edu



if [ `date +%H` = "08" ]; then
    /Users/jrittenh/aleph/scripts/annex/shelfTrayCount.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
    #~ /home/jrittenh/aleph/scripts/annex/workerStats.pl -e jrittenh@nd.edu -d `date +%Y%m%d -d yesterday`
    #~ /home/jrittenh/aleph/scripts/annex/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d yesterday`
    #~ /home/jrittenh/aleph/scripts/annex/workerStats.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu -d `date +%Y%m%d -d yesterday` -h
    /Users/jrittenh/aleph/scripts/annex/shelfFillRpt.pl -e jrittenh@nd.edu,abales@nd.edu,tmorton@nd.edu,michael@professionalsystems.co,miranda.r.vannevel.7@nd.edu,swalton@nd.edu
    #~ /home/jrittenh/aleph/scripts/annex/ingestTime.pl
    if [ `date +%w` = "1" ]; then
        /Users/jrittenh/aleph/scripts/annex/fillRequestRpt.pl -e jrittenh@nd.edu #,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu
        /Users/jrittenh/aleph/scripts/annex/fillRequestRpt.pl -f 2015-08-24 -u `date +%Y-%m-%d -d "last sunday"` -e jrittenh@nd.edu #,abales@nd.edu,tmorton@nd.edu,miranda.r.vannevel.7@nd.edu
    fi
fi
