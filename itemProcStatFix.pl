#!/usr/bin/env perl

use strict;
use 5.10.1;

use Getopt::Long  qw/:config bundling no_ignore_case no_auto_abbrev/;
use Text::CSV;


use Justin;
use Justin qw/:oracle :annex/;

$|++;

BEGIN { $ENV{PERL_TEXT_CSV} = 'Text::CSV_PP' }

my ($file);

GetOptions(
    'f|file=s'  => \$file,
);

my $queryCount = 1000;

chomp(my $count = `wc -l $file`);
$count--;
open (my $fh, '<', $file) or die("Unable to open $file: $!");

my $csv = Text::CSV->new();
$csv->column_names($csv->getline($fh));

#~ my $historyQuery = "SELECT z30_85x_type, z30_alpha, z30_arrival_date, TRIM(z30_barcode), z30_call_no, z30_call_no_2, z30_call_no_2_key, z30_call_no_2_type, z30_call_no_key, z30_call_no_type, z30_cataloger, z30_chronological_i, z30_chronological_j, z30_chronological_k, z30_chronological_l, z30_chronological_m, z30_collection, z30_copy_id, z30_date_last_return, z30_depository_id, z30_description, z30_enumeration_a, z30_enumeration_b, z30_enumeration_c, z30_enumeration_d, z30_enumeration_e, z30_enumeration_f, z30_enumeration_g, z30_enumeration_h, z30_expected_arrival_date, z30_gap_indicator, z30h_85x_type, z30h_alpha, z30h_arrival_date, TRIM(z30h_barcode), z30h_call_no, z30h_call_no_2, z30h_call_no_2_type, z30h_call_no_type, z30h_cataloger, z30h_chronological_i, z30h_chronological_j, z30h_chronological_k, z30h_chronological_l, z30h_chronological_m, z30h_collection, z30h_copy_id, z30h_copy_sequence_2, z30h_date_last_return, z30h_depository_id, z30h_description, z30h_doc_number_2, z30h_enumeration_a, z30h_enumeration_b, z30h_enumeration_c, z30h_enumeration_d, z30h_enumeration_e, z30h_enumeration_f, z30h_enumeration_g, z30h_enumeration_h, z30h_expected_arrival_date, z30h_gap_indicator, z30h_h_cataloger, z30h_h_date, z30h_h_hour, z30h_hol_doc_number, z30h_hour_last_return, z30h_h_reason, z30h_h_reason_type, z30h_inventory_number, z30h_inventory_number_date, z30h_invoice_number, z30h_ip_last_return, z30h_ip_last_return_v6, z30h_issue_date, z30h_item_process_status, z30h_item_statistic, z30h_item_status, z30h_last_shelf_report_date, z30h_line_number, z30h_linking_number, z30h_maintenance_count, z30h_material, z30h_no_loans, z30h_note_circulation, z30h_note_internal, z30h_note_opac, z30_hol_doc_number_x, z30h_on_shelf_date, z30h_on_shelf_seq, z30h_open_date, z30h_order_number, z30_hour_last_return, z30h_pages, z30h_price, z30h_process_status_date, z30h_rec_key, z30h_schedule_sequence_2, z30h_shelf_report_number, z30h_sub_library, z30h_supp_index_o, z30h_temp_location, z30h_update_date, z30h_upd_time_stamp, z30h_vendor_code, z30_inventory_number, z30_inventory_number_date, z30_ip_last_return, z30_ip_last_return_v6, z30_issue_date, z30_item_process_status, z30_item_statistic, z30_item_status, z30_last_shelf_report_date, z30_linking_number, z30_maintenance_count, z30_material, z30_no_loans, z30_note_circulation, z30_note_internal, z30_note_opac, z30_on_shelf_date, z30_on_shelf_seq, z30_open_date, z30_order_number, z30_pages, z30_price, z30_process_status_date, z30_rec_key, z30_rec_key_2, z30_rec_key_3, z30_shelf_report_number, z30_sub_library, z30_supp_index_o, z30_temp_location, z30_update_date, z30_upd_time_stamp
my $historyQuery = "SELECT z30_rec_key, TRIM(z30_barcode) AS z30_barcode, TRIM(z30_sub_library) AS z30_sub_library, z30_process_status_date, z30h_process_status_date, z30_item_process_status, z30h_item_process_status, z30h_h_date ".
    "FROM ndu50.z30 LEFT JOIN ndu50.z30h ON TRIM(z30_barcode) = TRIM(z30h_barcode) AND z30_upd_time_stamp = z30h_upd_time_stamp ".
    "WHERE z30_rec_key IN (".join(', ', ('?') x $queryCount).") ".
    "AND z30_process_status_date > 20150701 ".
    "AND z30_item_process_status <> z30h_item_process_status ".
    "AND z30_item_process_status IN (NULL, '', ' ', '  ') ".
    "AND TRIM(z30_cataloger) IN ('APIANNEX', 'RFOX2')";

my $annexQuery = "SELECT items.barcode, tray_id, issue_type ".
    "FROM items LEFT JOIN issues ON items.barcode = issues.barcode ".
    "WHERE items.barcode = ? ".
    "";


open (my $rpt, '>', 'items_need_fixed.csv');
open (my $log, '>', 'items_need_fixed.log');

my $x = 0;

writeLine($rpt, "ItemNo,Barcode,Sublib,OldProc,InTray,Issue");
my @nums;
my @bcs;
my $last = 0;
while (my $l = $csv->getline_hr($fh)) {
    $x++;
    my %line = %$l;

    if ($line{'doc_nbr'} eq $line{'adm_doc_nbr'}) {
        monitor($x, $count, 1);
        next;
    }

    push(@nums, $line{'doc_nbr'}.$line{'itm_seq_nbr'});
    push(@bcs, $line{'brcde'});
    if (scalar(@nums) == $queryCount || $x == $count) {
        #~ say STDERR scalar(@nums);
        #~ say STDERR scalar(@bcs);
        #~ say STDERR p(@bcs);
        push (@nums, ((undef) x ($queryCount - scalar(@nums)))) if (scalar(@nums) < $queryCount);
        push (@bcs, ((undef) x ($queryCount - scalar(@bcs)))) if (scalar(@bcs) < $queryCount);
        $last++ if ($x == $count);
        my $bad = alephQuery3($historyQuery, \@nums, {'host' => 'aleph1.library.nd.edu', 'last' => $last});
        #~ my $imsData = annexQuery($annexQuery, \@bcs, {'return' => 'hash', 'last' => $last});
        #~ say STDERR p($imsData);
        #~ exit;
        @nums = ();
        @bcs = ();
        #~ my %imsRecs = %$imsData;
        #~ say STDERR p(%imsRecs);

        foreach my $badRec (sort {$a->{'Z30_BARCODE'} <=> $b->{'Z30_BARCODE'}} @$bad) {
            my $bc = $badRec->{'Z30_BARCODE'};
            my $imsData = annexQuery($annexQuery, [$bc], {'last' => $last});
            my $imsItem = shift(@$imsData);
            say STDERR p($imsItem);


            #~ if ($bc eq '00000018223768') {
                #~ say STDERR p($imsData->{$bc});
                #~ say STDERR $bc;
                #~ say STDERR p($imsRecs{$bc});
                #~ say STDERR getLine('-', 15);
                #~ say STDERR p(%imsRecs);
                #~ say STDERR getLine(30);
            #~ }
            writeLine($rpt, $badRec->{'Z30_REC_KEY'}.",".$badRec->{'Z30_BARCODE'}.",".$badRec->{'Z30_SUB_LIBRARY'}.",".$badRec->{'Z30H_ITEM_PROCESS_STATUS'}.",".($imsItem->{'tray_id'} ? 'Y' : 'N').",".$imsItem->{'issue_type'});
            #~ writeLine($log, p($badRec)."\n".p($imsItem->{$bc})."\n");
        }
    }

    monitor($x, $count, 1);
}

close($rpt);
