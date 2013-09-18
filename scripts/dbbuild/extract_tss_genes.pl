#!/usr/bin/env perl

=head1 NAME

extract_tss_genes.pl

=head1 SYNOPSIS

  extract_tss_genes.pl -d db_name [-h db_host] -o out_file [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -d db_name       = Name of FANTOM5 oPOSSUM db we are working on.
   -h db_host       = Host name of the FANTOM5 oPOSSUM db.
   -o out_file      = Ouput TSS genes file (for import into
                      FANTOM5 oPOSSUM table using mysqlimport).
   -l log_file      = Name of log file to which processing and error
                      messages are written.
                      (Default = extract_tss_genes.log)

=head1 DESCRIPTION

This is the FANTOM5 oPOSSUM script for extracting TSS to gene mapping.

=head1 ALGORITHM

Read the UniProt and EntrezGene information out of the tss table and output
TSS ID and gene IDs to file for import into tss_genes table.

=head1 AUTHOR

  David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia

  E-mail: dave@cmmt.ubc.ca

=cut

use strict;
use warnings;

#
# Use most current (development) libs
# comment out to use installed libs
#
use lib '/devel/FANTOM5_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(get_logger :levels);

use OPOSSUM::DBSQL::DBAdaptor;

use constant DEBUG => 0;

use constant LOG_FILE 		            => 'extract_tss_genes.log';

use constant ENTREZ_GENE_ID_TYPE        => 1;
use constant UNIPROT_ID_TYPE            => 2;

use constant FANTOM5_OPOSSUM_DB_HOST    => 'fantom.cmmt.ubc.ca';
use constant FANTOM5_OPOSSUM_DB_USER    => 'opossum_r';
use constant FANTOM5_OPOSSUM_DB_PASS    => '';

my $log_file = LOG_FILE;
my $fantom_opossum_db_name;
my $fantom_opossum_db_host;
my $out_file;
GetOptions(
    'd=s'   => \$fantom_opossum_db_name,
    'h=s'   => \$fantom_opossum_db_host,
    'o=s'	=> \$out_file,
    'l=s'	=> \$log_file
);

if (!$fantom_opossum_db_name) {
    pod2usage(
        -msg        => "No FANTOM5 oPOSSUM DB name specified",
        -verbose    => 1
    );
}

if (!$out_file) {
    pod2usage(
        -msg        => "No output TSS genes file specified",
        -verbose    => 1
    );
}

if (!$fantom_opossum_db_host) {
    $fantom_opossum_db_host = FANTOM5_OPOSSUM_DB_HOST;
}

#
# Initialize logging
#
my $logger = get_logger();
if (DEBUG) {
    $logger->level($DEBUG);
} else {
    $logger->level($INFO);
}
my $appender = Log::Log4perl::Appender->new("Log::Dispatch::File",
                                            filename    => $log_file,
                                            mode        => "write");
#my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %M:%L %p: %m%n");
my $layout = Log::Log4perl::Layout::PatternLayout->new("%M:%L %p: %m%n");
$appender->layout($layout);
$logger->add_appender($appender);

my $start_time = time;
my $localtime = localtime($start_time);

$logger->info("Extract TSS genes started on $localtime\n");

my $opdba = OPOSSUM::DBSQL::DBAdaptor->new(
    -host       => $fantom_opossum_db_host,
    -dbname     => $fantom_opossum_db_name,
    -user       => FANTOM5_OPOSSUM_DB_USER,
    -password   => undef
);

if (!$opdba) {
    $logger->logdie(
        "Error connecting to FANTOM5 oPOSSUM database - $DBI::errstr"
    );
}

#
# Get some adaptors up front
#
my $dbia = $opdba->get_DBInfoAdaptor;
if (!$dbia) {
    $logger->logdie("Error getting DBInfoAdaptor");
}

my $tssa = $opdba->get_TSSAdaptor;
if (!$tssa) {
    $logger->logdie("Error getting TSSAdaptor");
}

my $db_info = $dbia->fetch_db_info;
if (!$db_info) {
    $logger->logdie("Error fetching DB info");
}

my $species = $db_info->species()
    || $logger->logdie("Species name not set in db_info table");


my $TSSs = $tssa->fetch_where();

open(OFH, ">$out_file") || $logger->logdie("opening output TSS genes file");

foreach my $tss (@$TSSs) {
    my $tss_id          = $tss->id;
    my $uniprot_ids     = $tss->uniprot_ids;
    my $entrez_gene_ids = $tss->entrez_gene_ids;

    my @entrez   = split /\s*,\s*/, $entrez_gene_ids if $entrez_gene_ids;
    my @uniprot  = split /\s*,\s*/, $uniprot_ids if $uniprot_ids;

    if (@entrez) {
        foreach my $gid (@entrez) {
            printf OFH "%d\t%d\t%s\n",
                $tss_id,
                ENTREZ_GENE_ID_TYPE,
                $gid;
        }
    }

    if (@uniprot) {
        foreach my $gid (@uniprot) {
            printf OFH "%d\t%d\t%s\n",
                $tss_id,
                UNIPROT_ID_TYPE,
                $gid;
        }
    }
}
close(OFH);

my $end_time = time;
$localtime = localtime($end_time);
my $elapsed_secs = $end_time - $start_time;

$logger->info("Extract TSS genes completed on $localtime");
$logger->info("Elapsed time (s): $elapsed_secs");

exit;
