#!/usr/bin/env perl

=head1 NAME

compute_tfbss.pl

=head1 SYNOPSIS

  compute_tfbss.pl ([-i regions_file ] | ([-s start] [-e end]))
    -d opossum_db_name [-h opossum_db_host]
    [-c collection] [-t tax_groups] [-ic min_ic] [-i tf_id] [-n tf_name]
    -o out_tfbs_file [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -i regions_file      = Name of input search regions file.
   -s start             = Starting search region ID.
   -e end               = Ending search region ID.
   -d opossum_db_name   = Name of FANTOM5 oPOSSUM db we are working on.
   -h opossum_db_host   = Host name of the FANTOM5 oPOSSUM db.
   -c collection        = Use the TFBS profiles from this JASPAR collection.
                          Default = CORE.
   -t tax_groups        = Limit profiles to ones of these taxonomic
                          supergroups.
   -ic min_ic           = Limit profiles to ones with at least this IC
   -id tf_id            = Use only the profile with this specific ID
   -n tf_name           = Use only the profile with this specific name
   -o out_tfbs_file     = Ouput TFBSs file (for import into
                          FANTOM5 oPOSSUM table using mysqlimport).
   -l log_file          = Name of log file to which processing and error
                          messages are written.
                          (Default = compute_tfbss.log)

=head1 DESCRIPTION

This is the FANTOM5 oPOSSUM script for computing TFBSs.

=head1 ALGORITHM

If regions file is provided, read search regions from it, otherwise fetch
search regions from the FANTOM5 oPOSSUM DB optionally limited to a start and
end search region ID. Foreach search region, extract the corresponding sequence
from Ensembl. Search the sequence for each TF and output TFBSs.

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
use lib '/apps/FANTOM5_oPOSSUM/lib';
use lib '/raid2/local/src/ensembl-64/ensembl/modules/';
use lib '/home/dave/devel/TFBS';

use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(get_logger :levels);
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use TFBS::DB::JASPAR5;

use OPOSSUM::DBSQL::DBAdaptor;
use OPOSSUM::SearchRegion;
use OPOSSUM::TFBS;


use constant DEBUG => 0;

#
# XXX
# If set, get the latest Ensembl DB from the registry. Otherwise use the
# Ensembl DB specified in the db_info table. This could be dangerous if the
# underlying genome assembly has changed!!!
# XXX
#
use constant LATEST_ENSEMBL_DB          => 0;

use constant LOG_FILE 		            => 'compute_tfbss.log';

use constant JASPAR_DB_HOST             => 'vm5.cmmt.ubc.ca';
use constant JASPAR_DB_NAME             => 'JASPAR_2010';
use constant JASPAR_DB_USER             => 'jaspar_r';
use constant JASPAR_DB_PASS             => '';

use constant ENSEMBL_DB_HOST            => 'vm2.cmmt.ubc.ca';
use constant ENSEMBL_DB_USER            => 'ensembl_r';
use constant ENSEMBL_DB_PASS            => '';

use constant FANTOM5_OPOSSUM_DB_HOST    => 'fantom.cmmt.ubc.ca';
use constant FANTOM5_OPOSSUM_DB_USER    => 'opossum_r';
use constant FANTOM5_OPOSSUM_DB_PASS    => '';

# Default profiles to use are CORE vertebrates with min. IC of 8
use constant CORE_TAX_GROUPS            => ('vertebrates');
use constant CORE_MIN_IC                => 8;

use constant MIN_TFBS_CR_OVERLAP        => 1;
use constant FILTER_OVERLAPPING_TFBSS   => 1;

use constant TFBS_THRESHOLD             => '75%';

my $log_file = LOG_FILE;
my $sr_file;
my $start_id;
my $end_id;
my $fantom_opossum_db_name;
my $fantom_opossum_db_host;
my $collection;
my @tax_groups;
my $min_ic;
my $tf_id;
my $tf_name;
my $out_tfbs_file;
GetOptions(
    'i=s'   => \$sr_file,
    's=s'   => \$start_id,
    'e=s'   => \$end_id,
    'd=s'   => \$fantom_opossum_db_name,
    'h=s'   => \$fantom_opossum_db_host,
    'c=s'   => \$collection,
    't=s'   => \@tax_groups,
    'ic=i'  => \$min_ic,
    'id=s'  => \$tf_id,
    'n=s'   => \$tf_name,
    'o=s'	=> \$out_tfbs_file,
    'l=s'	=> \$log_file
);

if (!$fantom_opossum_db_name) {
    pod2usage(
        -msg        => "No FANTOM5 oPOSSUM DB name specified",
        -verbose    => 1
    );
}

if (!$out_tfbs_file) {
    pod2usage(
        -msg        => "No output TFBSs file specified",
        -verbose    => 1
    );
}

if (!$fantom_opossum_db_host) {
    $fantom_opossum_db_host = FANTOM5_OPOSSUM_DB_HOST;
}

if (@tax_groups) {
    @tax_groups = split(/\s*,\s*/, join(',', @tax_groups));
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

$logger->info("Compute TFBSs started on $localtime\n");

my $matrix_set = fetch_matrix_set();

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

my $db_info = $dbia->fetch_db_info;
if (!$db_info) {
    $logger->logdie("Error fetching DB info");
}

my $species = $db_info->species()
    || $logger->logdie("Species name not set in db_info table");

my $ens_db_name = $db_info->ensembl_db()
    || $logger->logdie("Ensembl DB name not set in db_info table");

my $min_threshold = $db_info->min_threshold()
    || $logger->logdie("Min. threshold not set in db_info table");

$min_threshold = $min_threshold * 100 . '%';

$logger->info("Min. TFBS threshold: $min_threshold");

my $ensdba;

if (LATEST_ENSEMBL_DB) {
    Bio::EnsEMBL::Registry->load_registry_from_db(
        -host    => ENSEMBL_DB_HOST,
        -user    => ENSEMBL_DB_USER,
        -pass    => ENSEMBL_DB_PASS,
        -driver  => 'mysql'
    );

    $ensdba = Bio::EnsEMBL::Registry->get_DBAdaptor($species, 'core');
} else {
    $ensdba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
        -host    => ENSEMBL_DB_HOST,
        -user    => ENSEMBL_DB_USER,
        -pass    => ENSEMBL_DB_PASS,
        -dbname  => $ens_db_name,
        -species => $species,
        -driver  => 'mysql'
    );
}

unless ($ensdba) {
    $logger->logdie(
        "connecting to Ensembl $species DB \@" . ENSEMBL_DB_HOST
    );
}

my $enssa = $ensdba->get_SliceAdaptor()
    || $logger->logdie("getting Ensembl SliceAdaptor");

my $search_regions;
if ($sr_file) {
    $search_regions = read_search_regions_from_file($sr_file);

    unless ($search_regions) {
        $logger->logdie("No search regions read from file $sr_file");
    }
} else {
    my $where;
    if ($start_id) {
        $where = "id >= $start_id";
        if ($end_id) {
            $where .= " and id <= $end_id";
        }
    } elsif ($end_id) {
        $where = "id <= $end_id";
    }

    my $sra = $opdba->get_SearchRegionAdaptor();

    unless ($sra) {
        $logger->logdie("Error getting SearchRegionAdaptor");
    }

    $search_regions = $sra->fetch_where($where);

    unless ($search_regions) {
        $logger->logdie("No search regions fetched from DB");
    }
}

open(OTFH, ">$out_tfbs_file") || $logger->logdie("opening output TFBS file");

foreach my $sr (@$search_regions) {
    my $id    = $sr->id;
    my $chrom = $sr->chrom;
    my $start = $sr->start;
    my $end   = $sr->end;

    $logger->info("Processing search region $id: chr$chrom:$start-$end");

    my $ens_chrom;
    if ($chrom eq 'M') {
        $ens_chrom = 'MT';
    } else {
        $ens_chrom = $chrom;
    }
    my $slice = $enssa->fetch_by_region("chromosome", $ens_chrom, $start, $end);

    if (!$slice) {
        $logger->logdie(
            sprintf(
                "fetching slice chr%s:%d-%d from Ensembl", 
                $ens_chrom, $start, $end
            )
        );
    }

    my $seq = $slice->seq;

    my $site_set = $matrix_set->search_seq(
        -seq        => $seq,
        -threshold  => $min_threshold
    );

    next unless ($site_set && $site_set->size > 0);

    my $tfbs_hash = site_set_to_opossum_tfbs_hash($id, $chrom, $site_set);

    $tfbs_hash = tfbs_hash_filter_overlapping_sites($tfbs_hash);

    write_tfbs_hash(\*OTFH, $start, $tfbs_hash);
}
close(OTFH);

my $end_time = time;
$localtime = localtime($end_time);
my $elapsed_secs = $end_time - $start_time;

$logger->info("Compute TFBSs completed on $localtime");
$logger->info("Elapsed time (s): $elapsed_secs");

exit;

sub read_search_regions_file
{
    my ($file) = @_;

    open(INFH, $file)
        || $logger->logdie("Opening input search regions file $sr_file - $!");

    my @search_regions;
    my $id = 1;
    while (my $line = <INFH>) {
        chomp $line;
        my @data = split "\t", $line;

        my $chrom = $data[0];
        my $start = $data[1];
        my $end   = $data[2];

        $logger->info("Processing region $id: chr$chrom:$start-$end");

        push @search_regions, OPOSSUM::SearchRegion->new(
            -id     => $id,
            -chrom  => $chrom,
            -start  => $start,
            -end    => $end
        );

        $id++;
    }
    close(INFH);

    return @search_regions ? \@search_regions : undef;
}

sub write_tfbs_hash
{
    my ($fh, $start, $tfbs_hash) = @_;

    my @tf_ids = keys %$tfbs_hash;

    foreach my $tf_id (@tf_ids) {
        my $tfbss = $tfbs_hash->{$tf_id};

        foreach my $tfbs (@$tfbss) {
            printf $fh "%d\t%s\t%s\t%d\t%d\t%s\t%.3f\t%.3f\t%s\n",
                $tfbs->search_region_id,
                $tf_id,
                $tfbs->chrom,
                $tfbs->start + $start - 1,
                $tfbs->end + $start - 1,
                ($tfbs->strand == 1) ? '+' : '-',
                $tfbs->score,
                $tfbs->rel_score,
                $tfbs->seq
                #($tfbs->get_tag_values('conservation_level'))[0],
                #($tfbs->get_tag_values('conservation'))[0]
        }
    }
}

sub fetch_matrix_set
{
    my $jdbh = TFBS::DB::JASPAR5->connect(
        "dbi:mysql:" . JASPAR_DB_NAME . ":" . JASPAR_DB_HOST,
        JASPAR_DB_USER,
        JASPAR_DB_PASS
    );

    if (!$jdbh) {
        $logger->logdie("connecting to JASPAR database - $DBI::errstr");
    }

    my %matrix_args = (-matrixtype => 'PWM');
    if ($tf_id) {
        $matrix_args{-ID} = [$tf_id];
    } elsif ($tf_name) {
        $matrix_args{-name} = [$tf_name];
    } else  {
        $collection = 'CORE' unless $collection;

        $matrix_args{-collection} = $collection;

        if ($collection eq 'CORE') {
            @tax_groups = CORE_TAX_GROUPS unless @tax_groups;

            $matrix_args{-tax_group}    = \@tax_groups;
            $matrix_args{-min_ic}       = $min_ic || CORE_MIN_IC;
        } else {
            $matrix_args{-min_ic}     = $min_ic if defined $min_ic;
        }
    }

    my $pwm_set = $jdbh->get_MatrixSet(%matrix_args);

    if (!$pwm_set) {
        $logger->logdie("Could not fetch JASPAR matrix set");
    }

    return $pwm_set;
}

#
# Convert a TFBS::SiteSet to a hash of sites, with the keys of the hash
# being the TF IDs and the values being a listref of OPOSSUM::TFBS sites
# sorted by start.
#
sub site_set_to_opossum_tfbs_hash
{
    my ($search_region_id, $chrom, $site_set) = @_;

    my %tfbs_hash;

    my $iter = $site_set->Iterator(-sort_by => 'start');
    while (my $site = $iter->next) {
        push @{$tfbs_hash{$site->pattern->ID}}, OPOSSUM::TFBS->new(
            -tf_id              => $site->pattern->ID,
            -search_region_id   => $search_region_id,
            -chrom              => $chrom,
            -start              => $site->start,
            -end                => $site->end,
            -strand             => $site->strand,
            -score              => $site->score,
            -rel_score          => $site->rel_score,
            -seq                => $site->seq->seq
        );
    }

    return %tfbs_hash ? \%tfbs_hash : undef;
}

#
# Take a tf sites hashref and filter overlapping sites such that only
# the highest scoring site of any mutually overlapping sites is kept.
# In the event that sites score equally, the first site is kept, i.e.
# bias is towards the site with the lowest starting position.
#
sub tfbs_hash_filter_overlapping_sites
{
    my ($tfbs_hash) = @_;

    return unless defined $tfbs_hash;

    my @tf_ids = keys %$tfbs_hash;

    foreach my $tf_id (@tf_ids) {
        my $tfbss = $tfbs_hash->{$tf_id};

        if ($logger->is_debug()) {
            log_tfbss('All TFBSs', $tfbss);
        }

        my $ftfbss = filter_overlapping_tfbss($tfbss);

        if ($logger->is_debug()) {
            log_tfbss('Filtered TFBSs', $ftfbss);
        }

        $tfbs_hash->{$tf_id} = $ftfbss;
    }

    return $tfbs_hash;
}

#
# Filter a list of OPOSSUM::TFBS objects so that for overlapping sites, only
# the highest scoring site is stored.
#
sub filter_overlapping_tfbss
{
    my ($tfbss) = @_;

    return unless $tfbss && scalar @$tfbss > 0;

    my $ntfbss = scalar @$tfbss;

    #
    # Firt store all overlapping sites in a separate array. Store the
    # non-overlapping sites in our filtered sites.
    #
    my @ftfbss;
    my @ol_tfbss;
    foreach my $i (0..$ntfbss - 1) {
        my $tfbs = $tfbss->[$i];

        my $prev_tfbs;
        my $next_tfbs;
        $prev_tfbs = $tfbss->[$i - 1] if $i > 0;
        $next_tfbs = $tfbss->[$i + 1] if $i < $ntfbss - 1;

        my $overlap = 0;
        if ($prev_tfbs && $tfbs->start <= $prev_tfbs->end) {
            $overlap = 1;
        } elsif ($next_tfbs && $tfbs->end >= $next_tfbs->start) {
            $overlap = 1;
        }

        if ($overlap) {
            push @ol_tfbss, $tfbs;
        } else {
            push @ftfbss, $tfbs;
        }
    }

    while (my $tfbs = get_highest_scoring_tfbs(\@ol_tfbss)) {
        # Add the highest scoring site to the filtered sites
        push @ftfbss, $tfbs;
    }

    if (@ftfbss) {
        @ftfbss = sort {$a->start <=> $b->start} @ftfbss;
    }

    return @ftfbss ? \@ftfbss : undef;
}

#
# Given an array ref of TFBS::Sites, find the highest scoring site in the
# array, return (a copy of) it, removing it and all sites overlapping it
# from the array.
#
sub get_highest_scoring_tfbs
{
    my ($tfbss) = @_;

    return unless $tfbss;

    my $ntfbss = @$tfbss;

    my $hs_tfbs;
    my $hs_tfbs_idx;
    foreach my $i (0..$ntfbss - 1) {
        # Check site has not been previously deleted from array
        next unless exists $tfbss->[$i];

        my $tfbs = $tfbss->[$i];

        if ($hs_tfbs) {
            if ($tfbs->score > $hs_tfbs->score) {
                $hs_tfbs = $tfbs;
                $hs_tfbs_idx = $i;
            }
        } else {
            $hs_tfbs = $tfbs;
            $hs_tfbs_idx = $i;
        }
    }

    # Didn't retrieve a site (all elements of array previously deleted)
    return unless $hs_tfbs;

    # Remove all sites which overlap the highest scoring site on the left
    my $i = $hs_tfbs_idx;
    while ($i - 1 >= 0) {
        if (exists $tfbss->[$i - 1]) {
            last if $tfbss->[$i - 1]->end < $hs_tfbs->start;

            delete $tfbss->[$i - 1];
        }

        $i--;
    }

    # Remove all sites which overlap the highest scoring site on the right
    $i = $hs_tfbs_idx;
    while ($i + 1 < $ntfbss) {
        if (exists $tfbss->[$i + 1]) {
            last if $tfbss->[$i + 1]->start > $hs_tfbs->end;

            delete $tfbss->[$i + 1];
        }

        $i++;
    }

    # Copy site.
    my $hs_tfbs_cpy = OPOSSUM::TFBS->new(
        %$hs_tfbs
    );

    # Remove this site from the sites array
    delete $tfbss->[$hs_tfbs_idx];

    return $hs_tfbs_cpy;
}

#
# For debugging. Write out list of TFSS::Site objeects to log file
#
sub log_tfbss
{
    my ($which, $tfbss) = @_;

    my $msg = "$which";
    foreach my $tfbs (@$tfbss) {
        $msg .= sprintf "\n%d-%d\t%.3f",
            $tfbs->start, $tfbs->end, $tfbs->score;
    }
    $msg .= "\n";

    $logger->debug($msg);
}
