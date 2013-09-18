#!/usr/bin/env perl

=head1 NAME

extract_tss_search_regions.pl

=head1 SYNOPSIS

  extract_tss_search_regions.pl
      -species species
      [-tssf FILE]
      -up up_bp
      -dn down_bp
      -obed FILE
      [-oseq FILE]
      [-log FILE]

=head1 ARGUMENTS

Argument switches may be abbreviated where unique. Arguments enclosed by
brackets [] are optional.

    -species species
            The common species name for which the analysis is being
            performed, e.g.: human.

    -tssf FILE
            Input file containing a list of TSS names.

    -up
            Amount up upstream flank to apply to TSS regions.

    -dn
            Amount up downstream flank to apply to TSS regions.

    -obed FILE
            Output file of regions in BED format.

    -oseq FILE
            Output file of sequences corresponding to ouput regions.

    -log FILE
            Log messages to the given file

=head1 DESCRIPTION

Given an optional input file of TSS names (all TSSs in the FANTOM5-oPOSSUM
DB are used if none provided), compute the merged regions with given upstream
and downstream bp applied and output to BED. Optionally also extract sequences
for each region and output as fasta.

=head1 AUTHOR

David Arenillas
Wasserman Lab
Centre for Molecular Medicine and Therapeutics
University of British Columbia

E-mail: dave@cmmt.ubc.ca

=cut

use strict;

use warnings;

use lib '/devel/FANTOM5_oPOSSUM/lib';
use lib '/usr/local/src/ensembl-64/ensembl/modules';

use Getopt::Long;
use Pod::Usage;
use Carp;

use Log::Log4perl qw(get_logger :levels);
use Bio::SeqIO;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

use OPOSSUM::Include::BaseInclude;
use OPOSSUM::DBSQL::DBAdaptor;
use OPOSSUM::TSS;
use OPOSSUM::SearchRegion;

use constant DEBUG              => 0;
use constant LOG_FILE           => 'extract_tss_search_regions.log';
use constant ENSEMBL_DB_HOST    => 'vm2.cmmt.ubc.ca';
use constant ENSEMBL_DB_USER    => 'ensembl_r';
use constant ENSEMBL_DB_PASS    => undef;

my $species;
my $tss_names_file;
my $upstream_bp;
my $downstream_bp;
my $out_bed_file;
my $out_seq_file;
my $log_file;
GetOptions(
    'species|s=s'   => \$species,
    'tssf=s'        => \$tss_names_file,
    'up=i'          => \$upstream_bp,
    'dn=i'          => \$downstream_bp,
    'obed=s'        => \$out_bed_file,
    'oseq=s'        => \$out_seq_file,
    'log=s'         => \$log_file
);

$log_file = LOG_FILE unless $log_file;

unless ($species) {
    pod2usage(
        -msg        => "No species specified",
        -verbose    => 1
    );
}

unless ($upstream_bp) {
    pod2usage(
        -msg        => "No upstream flanking bp specified",
        -verbose    => 1
    );
}

unless ($downstream_bp) {
    pod2usage(
        -msg        => "No downstream flanking bp specified",
        -verbose    => 1
    );
}

unless ($out_bed_file) {
    pod2usage(
        -msg        => "No output BED file specified",
        -verbose    => 1
    );
}

my %job_args;

my $logger = get_logger();
if (DEBUG) {
    $logger->level($DEBUG);
} else {
    $logger->level($INFO);
}

#my $layout = Log::Log4perl::Layout::PatternLayout->new("%M:%L %p: %m%n");
my $layout = Log::Log4perl::Layout::PatternLayout->new("[%d] %p\t%m%n");

my $appender = Log::Log4perl::Appender->new(
    "Log::Dispatch::File",
    filename    => $log_file,
    mode        => "append"
);

$appender->layout($layout);
$logger->add_appender($appender);

$job_args{-logger} = $logger;

#
# Connect to FANTOM5_oPOSSUM DB and get the necessary adaptors
#
my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);

my $opdba = opossum_db_connect($species)
    || die "Could not connect to FANTOM5 oPOSSUM database $db_name\n";

my $tssa = $opdba->get_TSSAdaptor
    || die "Could not get TSSAdaptor";

#
# Only needed if ouputting sequences
#
my $ens_dba;
if ($out_seq_file) {
    my $dbia = $opdba->get_DBInfoAdaptor
        || die "Could not get DBInfoAdaptor";

    my $db_info = $dbia->fetch_db_info();
    unless ($db_info) {
        die "Error fetching FANTOM5-oPOSSUM DB info\n";
    }

    my $ens_db = $db_info->ensembl_db;

    $ens_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -host       => ENSEMBL_DB_HOST,
        -user       => ENSEMBL_DB_USER,
        -pass       => ENSEMBL_DB_PASS,
        -dbname     => $ens_db
    );

    unless ($ens_dba) {
        die "Error connecting to Ensembl DB $ens_db\n";
    }
}

my $tss;
if ($tss_names_file) {
    $tss = fetch_tss_by_names_file(
        $tssa, 'target', $tss_names_file, 0, undef, \%job_args
    );
} else {
    $tss = $tssa->fetch();
}

my $tss_regions = compute_tss_search_regions(
    $tss, $upstream_bp, $downstream_bp, undef, \%job_args
);

unless ($tss_regions) {
    die "Error computing TSS search regions";
}

write_regions($tss_regions, $out_bed_file, $out_seq_file);

exit;

sub write_regions
{
    my ($regions, $bed_file, $seq_file) = @_;

    unless (open(BED, ">$bed_file")) {
        die "Error opening output regions BED file $bed_file - $!\n";
    }

    my $seqIO;
    my $ens_sa;
    if ($seq_file) {
        $ens_sa = $ens_dba->get_SliceAdaptor();
        unless ($ens_sa) {
            die "Error getting Ensembl SliceAdaptor\n";
        }

        $seqIO = Bio::SeqIO->new(-file => ">$seq_file", -format => 'fasta');
        unless ($seqIO) {
            die "Error opening output sequences fasta file $seq_file - $!\n";
        }
    }

    foreach my $sr (@$regions) {
        printf BED "chr%s\t%d\t%d\n",
            $sr->chrom,
            $sr->start - 1,     # BED format uses 0-based coords
            $sr->end;

        if ($seq_file) {
            my $seq_id = sprintf("chr%s:%d-%d",
                $sr->chrom, $sr->start, $sr->end
            );

            my $ens_chrom = $sr->chrom;
            if ($ens_chrom eq 'M') {
                $ens_chrom = 'MT';
            }

            my $slice = $ens_sa->fetch_by_region(
                "chromosome", $ens_chrom, $sr->start, $sr->end
            );

            unless ($slice) {
                die "Error fetching Ensembl Slice for $seq_id\n";
            }

            $seqIO->write_seq(
                Bio::Seq->new(
                    -id     => $seq_id,
                    -seq    => $slice->seq()
                )
            );
        }
    }

    close(BED);
}

