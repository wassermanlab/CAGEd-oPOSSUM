#!/usr/bin/env perl

=head1 NAME

parse_tag_cluster_files.pl

=head1 SYNOPSIS

  parse_tag_cluster_files.pl
        -species species
        -clf tag_clusters_file
        -mtcf max_tag_counts_file
        -mtpmf max_tpm_values_file
        -otssf out_tss_file
        -oxf out_tss_extra_file
        -ogf out_gene_file
        -osrf out_search_regions_file
        [-f flank_size]
        [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -species species = Name of the species with which the files are
                      associated. Human or mouse. NOTE: the number of
                      columns in the main tag clusters file varies depending
                      on species. Human has an extra column which contains
                      the HGNC ID(s).

   -clf FILE        = Name of main input FANTOM5 tag clusters file.
                      Format of the file is some comment lines starting
                      with ##, followed by a header line and then data
                      lines with the following columns:
                          annotation
                          short_description
                          description
                          association_with_transcript
                          entrezgene_id
                          hgnc_id (NOTE: human only!!!)
                          uniprot_id
                      e.g:
chr10:101144239..101144255,+    p12@Mgat4c      CAGE_peak_12_at_Mgat4c_5end     -19bp_to_ENSMUST00000127504,ENSMUST00000134930_5end     entrezgene:67569        uniprot:D3Z5V6

   -mtcf FILE       = Name of the input file containing the maximum tag
                      counts for each of the tag clusters.

   -mtpmf FILE      = Name of the input file containing the maximum TPM
                      values for each of the tag clusters.

   -otssf FILE      = Name of the output TSS file to be loaded into the 
                      FANTOM5 oPOSSUM DB 'tss' table via mysqlimport.

   -oxf FILE        = Name of the output TSS extra information file to be
                      loaded into the FANTOM5 oPOSSUM DB 'tss_extra' table
                      via mysqlimport.

   -ogf FILE        = Name of the output TSS genes file to be loaded into
                      the FANTOM5 oPOSSUM DB 'tss_genes' table via
                      mysqlimport.

   -osrf FILE       = Name of the output search regions file to be loaded
                      into the FANTOM5 oPOSSUM DB 'search_regions' table
                      via mysqlimport.

   -f INT           = Size of flanking region to apply either side of tag
                      clusters for computing the TFBS search regions.

   -l FILE          = Optional name of log file. If not specified then the
                      log file will be named parse_tag_cluster_files.log.

=head1 DESCRIPTION

Script to parse various FANTOM5 files containing information about tag clusters
including their positions, their relationship to known genes, the maximum tag
count and maximum TPM value etc. Create an output text file for loading into
the FANTOM5 oPOSSUM database's 'tss' table. This file is in tab delimeted
format with each column corresponding to the columns of the tss table in the
DB. The file can then be loaded into the DB via the mysqlimport facility. A
search regions file is also computed and output.

=head1 AUTHOR

  David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  Child & Family Research Institute
  University of British Columbia

  E-mail: dave@cmmt.ubc.ca

=cut

use strict;
use warnings;

use lib '/apps/CAGEd_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(get_logger :levels);

use OPOSSUM::Opt::BaseOpt;
use OPOSSUM::TSS;
use OPOSSUM::SearchRegion;

use constant DEBUG          => 0;
use constant MAX_FLANK_SIZE => 2000;

# XXX should really check for all chromosme lengths
use constant CHROM_LENGTH   => {'M' => 16299};

my $species;
my $in_tag_clusters_file;
my $in_max_tag_count_file;
my $in_max_tpm_file;
my $out_tss_file;
my $out_tss_extra_file;
my $out_genes_file;
my $out_sr_file;
my $flank_size;
my $log_file;
GetOptions(
    'species=s' => \$species,
    'clf=s'     => \$in_tag_clusters_file,
    'mtcf=s'    => \$in_max_tag_count_file,
    'mtpmf=s'   => \$in_max_tpm_file,
    'otssf=s'   => \$out_tss_file,
    'oxf=s'     => \$out_tss_extra_file,
    'ogf=s'     => \$out_genes_file,
    'osrf=s'    => \$out_sr_file,
    'f=i'       => \$flank_size,
    'l=s'       => \$log_file
);

unless ($species) {
    pod2usage(
        -msg        => "No species specified - required to determine columns"
                        . " of main tag clusters file",
        -verbose    => 1
    );
}

$species = lc $species;
unless ($species eq 'human' || $species eq 'mouse') {
    pod2usage(
        -msg        => "Unrecognized species specified - must be 'human'"
                        . " or 'mouse'",
        -verbose    => 1
    );
}

unless ($in_tag_clusters_file) {
    pod2usage(
        -msg        => "No input tag clusters file specified",
        -verbose    => 1
    );
}

unless ($in_max_tag_count_file) {
    pod2usage(
        -msg        => "No input max. tag counts file specified",
        -verbose    => 1
    );
}

unless ($in_max_tpm_file) {
    pod2usage(
        -msg        => "No input max. TPM file specified",
        -verbose    => 1
    );
}

unless ($out_tss_file) {
    pod2usage(
        -msg        => "No output TSS file specified",
        -verbose    => 1
    );
}

unless ($out_tss_extra_file) {
    pod2usage(
        -msg        => "No output TSS extra information file specified",
        -verbose    => 1
    );
}

unless ($out_genes_file) {
    pod2usage(
        -msg        => "No output TSS genes file specified",
        -verbose    => 1
    );
}

unless ($out_sr_file) {
    pod2usage(
        -msg        => "No output search regions file specified",
        -verbose    => 1
    );
}

unless (-f $in_tag_clusters_file) {
    die "Input tag clusters file $in_tag_clusters_file does not exist!\n";
}

unless (-f $in_max_tag_count_file) {
    die "Input max. tag counts file $in_max_tag_count_file does not exist!\n";
}

unless (-f $in_max_tpm_file) {
    die "Input max. TPM values file $in_max_tpm_file does not exist!\n";
}

unless ($log_file) {
    $log_file = "parse_tag_cluster_files.log";
}

unless ($flank_size) {
    $flank_size = MAX_FLANK_SIZE;
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

my $appender = Log::Log4perl::Appender->new(
    "Log::Dispatch::File",
    filename    => $log_file,
    mode        => "write"
);

#my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %M:%L %p: %m%n");
my $layout = Log::Log4perl::Layout::PatternLayout->new("%M:%L %p: %m%n");
$appender->layout($layout);
$logger->add_appender($appender);

my $start_time = time;
my $localtime = localtime($start_time);

$logger->info("Parsing tag cluster files started on $localtime\n");

my $tss = read_tag_cluster_files(
    $in_tag_clusters_file, $in_max_tag_count_file, $in_max_tpm_file
);

unless ($tss) {
    $logger->logdie(
        "Error reading tag cluster information from input files\n"
    );
}

$logger->info("Computing TSS search regions");
my $search_regions = compute_search_regions($tss);

$logger->info("Writing TSSs to $out_tss_file");
write_tss($out_tss_file, $tss);

$logger->info("Writing TSS extra information to $out_tss_extra_file");
write_tss_extra($out_tss_extra_file, $tss);

$logger->info("Writing TSS genes to $out_genes_file");
write_tss_genes($out_genes_file, $tss);

$logger->info("Writing search regions $out_sr_file");
write_search_regions($out_sr_file, $search_regions);

$localtime = localtime();

$logger->info("Parsing tag cluster files finished on $localtime\n");

exit;

sub read_tag_cluster_files
{
    my ($tc_file, $max_tag_count_file, $max_tpm_file) = @_;

    $logger->info("Reading tag clusters file $tc_file");
    my $tss = read_tag_clusters_file($tc_file);

    unless ($tss) {
        $logger->logdie(
              "Error reading tag cluster information from main input"
            . " tag clusters file $tc_file\n"
        );
    }

    my %tss_hash = map {$_->name => $_} @$tss;

    $logger->info("Reading maximum tag count file $max_tag_count_file");
    read_max_tag_counts_file($max_tag_count_file, \%tss_hash);

    $logger->info("Reading maximum tpm value file $max_tpm_file");
    read_max_tpm_file($max_tpm_file, \%tss_hash);

    return $tss;
}

sub read_tag_clusters_file
{
    my ($file) = @_;

    open(INFH, "$file")
        || $logger->logdie(
            "Error opening input tag clusters file $file - $!"
    );

    my @tss;

    my $tss_id = 1;
    while (my $line = <INFH>) {
        chomp($line);

        next if $line =~ /^##/;
        next if $line =~ /^00/;

        if ($line =~ /^chr\w+:\d+\.\.\d+,./) {
            my $col_num = 0;

            my @cols = split "\t", $line;

            my $name            = $cols[$col_num++];
            my $short_desc      = $cols[$col_num++];
            my $desc            = $cols[$col_num++];
            my $trans_assoc     = $cols[$col_num++];
            my $entrez_info     = $cols[$col_num++];

            my $hgnc_info;
            if ($species eq 'human') {
                $hgnc_info       = $cols[$col_num++];
            }

            my $uniprot_info    = $cols[$col_num];

            my $chrom;
            my $start;
            my $end;
            my $strand;

            if ($name =~ /^chr(\w+):(\d+)\.\.(\d+),(.)/) {
                $chrom = $1;
                $start = $2;
                $end = $3;
                $strand = $4;
            } else {
                $logger->logdie(
                    "Error parsing CAGE peak name (position information)"
                );
            }

            if ($trans_assoc eq 'NA') {
                $trans_assoc = undef;
            }

            if ($entrez_info && $entrez_info eq 'NA') {
                $entrez_info = undef;
            }

            if ($hgnc_info && $hgnc_info eq 'NA') {
                $hgnc_info = undef;
            }

            if ($uniprot_info && $uniprot_info eq 'NA') {
                $uniprot_info = undef;
            }

            my @entrez_gene_ids;
            if ($entrez_info) {
                $entrez_info =~ s/entrezgene://g;
                if ($entrez_info =~ /,/) {
                    @entrez_gene_ids = split ',', $entrez_info;
                } else {
                    push @entrez_gene_ids, $entrez_info;
                }
            }

            my @hgnc_gene_ids;
            if ($hgnc_info) {
                $hgnc_info =~ s/HGNC://g;
                if ($hgnc_info =~ /,/) {
                    @hgnc_gene_ids = split ',', $hgnc_info;
                } else {
                    push @hgnc_gene_ids, $hgnc_info;
                }
            }

            my @uniprot_ids;
            if ($uniprot_info) {
                $uniprot_info =~ s/uniprot://g;
                if ($uniprot_info =~ /,/) {
                    @uniprot_ids = split ',', $uniprot_info;
                } else {
                    push @uniprot_ids, $uniprot_info;
                }
            }

            push @tss, OPOSSUM::TSS->new(
                -id                 => $tss_id,
                -chrom              => $chrom,
                -start              => $start,
                -end                => $end,
                -strand             => $strand,
                -is_tss             => 0,
                -name               => $name,
                -short_description  => $short_desc,
                -description        => $desc,
                -association_with_transcript    => $trans_assoc,
                -entrez_gene_ids    => \@entrez_gene_ids,
                -hgnc_gene_ids      => \@hgnc_gene_ids,
                -uniprot_ids        => \@uniprot_ids
            );

            $tss_id++;
        }
    }

    close(INFH);

    return @tss ? \@tss : undef;
}

sub read_max_tag_counts_file
{
    my ($file, $tss) = @_;

    open(INFH, "$file")
        || $logger->logdie("Error opening max. tag counts file $file - $!");

    while (my $line = <INFH>) {
        chomp($line);

        my @cols = split "\t", $line;

        my $name        = $cols[3];
        my $tag_count   = $cols[6];

        if ($tss->{$name}) {
            $tss->{$name}->max_tag_count($tag_count);
        } else {
            $logger->error(
                "TSS $name not found when setting max. tag count!\n"
            );
        }
    }

    close(INFH);
}

sub read_max_tpm_file
{
    my ($file, $tss) = @_;

    open(INFH, "$file")
        || $logger->logdie("Error opening max. TPM values file $file - $!");

    while (my $line = <INFH>) {
        chomp($line);

        my @cols = split "\t", $line;

        my $name        = $cols[3];
        my $tpm         = $cols[6];

        if ($tss->{$name}) {
            $tss->{$name}->max_tpm($tpm);
        } else {
            $logger->error(
                "TSS $name not found when setting max. TPM value!\n"
            );
        }
    }

    close(INFH);
}

sub write_tss
{
    my ($file, $tss) = @_;

    open(OFH, ">$file")
        || $logger->logdie("Error opening output TSS file $file - $!");

    foreach my $t (@$tss) {
        printf OFH "%d\t%d\t%s\t%s\t%d\t%d\t%s\t%d\t%d\t%s\n",
            $t->id || 0,
            $t->search_region_id || 0,
            $t->name,
            $t->chrom,
            $t->start,
            $t->end,
            $t->strand,
            $t->is_tss || 0,
            $t->max_tag_count || 0,
            $t->max_tpm || 0
    }

    close(OFH);
}

sub write_tss_extra
{
    my ($file, $tss) = @_;

    open(OFH, ">$file")
        || $logger->logdie("Error opening output TSS extra file $file - $!");

    foreach my $t (@$tss) {
        printf OFH "%d\t%s\t%s\t%s\n",
            $t->id || 0,
            $t->short_description,
            $t->description,
            $t->association_with_transcript || '';
    }

    close(OFH);
}

sub write_tss_genes
{
    my ($file, $tss) = @_;

    open(OFH, ">$file")
        || $logger->logdie("Error opening output TSS genes file $file - $!");

    foreach my $t (@$tss) {
        my $tss_id = $t->id;
        my $entrez_gene_ids = $t->entrez_gene_ids;
        my $uniprot_ids = $t->uniprot_ids;
        my $hgnc_gene_ids = $t->hgnc_gene_ids;

        if ($entrez_gene_ids) {
            foreach my $gene_id (@$entrez_gene_ids) {
                printf OFH "$tss_id\t%d\t$gene_id\n", ENTREZ_GENE_ID_TYPE;
            }
        }

        if ($uniprot_ids) {
            foreach my $gene_id (@$uniprot_ids) {
                printf OFH "$tss_id\t%d\t$gene_id\n", UNIPROT_GENE_ID_TYPE;
            }
        }

        if ($hgnc_gene_ids) {
            foreach my $gene_id (@$hgnc_gene_ids) {
                printf OFH "$tss_id\t%d\t$gene_id\n", HGNC_GENE_ID_TYPE;
            }
        }
    }

    close(OFH);
}

sub write_search_regions
{
    my ($file, $search_regions) = @_;

    open(OFH, ">$file") || $logger->logdie(
        "Error opening output search regions file $file - $!"
    );

    foreach my $sr (@$search_regions) {
        printf OFH "%d\t%s\t%d\t%d\n",
            $sr->id,
            $sr->chrom,
            $sr->start,
            $sr->end;
    }

    close(OFH);
}

sub compute_search_regions
{
    my ($tss) = @_;

    #
    # Store search regions on a per chromosome basis.
    #
    my $chrom_search_regions;
    foreach my $t (@$tss) {
        my $chrom = $t->chrom;
        my $start = $t->start - $flank_size;
        my $end   = $t->end + $flank_size;

        my $chrom_length = CHROM_LENGTH->{$chrom};
        if ($chrom_length && $chrom_length < $end) {
            $end = $chrom_length;
        }

        $start = 1 if $start < 1;

        push @{$chrom_search_regions->{$chrom}},
            OPOSSUM::SearchRegion->new(
                -chrom      => $chrom,
                -start      => $start,
                -end        => $end
            );
    }

    $chrom_search_regions = combine_chrom_search_regions($chrom_search_regions);

    set_search_region_ids($chrom_search_regions);

    set_tss_search_region_ids($tss, $chrom_search_regions);

    my @search_regions;

    my @chroms = keys %$chrom_search_regions;
    foreach my $chrom (@chroms) {
        push @search_regions, @{$chrom_search_regions->{$chrom}};
    }

    return @search_regions ? \@search_regions : undef;
}

sub combine_chrom_search_regions
{
    my ($chrom_search_regions) = @_;

    my @chroms = keys %$chrom_search_regions;

    foreach my $chrom (@chroms) {
        my $regions = $chrom_search_regions->{$chrom};

        $regions = combine_regions($chrom, $regions);

        $chrom_search_regions->{$chrom} = $regions;
    }

    return $chrom_search_regions;
}

sub combine_regions
{
    my ($chrom, $regs) = @_;

    return if !$regs || !$regs->[0];

    my $num_regs = scalar @$regs;

    unless ($num_regs > 1) {
        return $regs
    }

    @$regs = sort {$a->start <=> $b->start} @$regs;

    my @combined_regs;

    my $reg1 = $regs->[0];

    push @combined_regs, $reg1;

    my $i = 1;
    while ($i < $num_regs) {
        my $reg2 = $regs->[$i];

        #if (do_features_combine($reg1, $reg2)) {
        if ($reg2->start <= $reg1->end + 1) {
            if ($reg2->end > $reg1->end) {
                $reg1->end($reg2->end);
                #$logger->debug(
                #    sprintf("Combining chr$chrom regions %d - %d and"
                #        . " %d - %d",
                #        $reg1->start,
                #        $reg1->end,
                #        $reg2->start,
                #        $reg2->end
                #    )
                #);
            }
        } else {
            $reg1 = $reg2;
            push @combined_regs, $reg1;
        }

        $i++;
    }

    return @combined_regs ? \@combined_regs : undef;
}

#
# Check if features should be combined. They should if they overlap or are
# adjacent (no gap between them).
#
sub do_features_combine
{
    my ($feat1, $feat2) = @_;

    my $combine = 1;

    $combine = 0 if    $feat1->end < $feat2->start - 1
                    || $feat1->start > $feat2->end + 1;

    return $combine;
}

sub set_search_region_ids
{
    my ($chrom_search_regions) = @_;

    my @chroms = keys %$chrom_search_regions;

    my $sr_id = 1;
    foreach my $chrom (@chroms) {
        my $search_regions = $chrom_search_regions->{$chrom};

        foreach my $sr (@$search_regions) {
            $sr->id($sr_id++);
        }
    }
}

sub set_tss_search_region_ids
{
    my ($tss, $chrom_search_regions) = @_;

    foreach my $t (@$tss) {
        my $chrom = $t->chrom;

        my $search_regions = $chrom_search_regions->{$chrom};

        foreach my $sr (@$search_regions) {
            if (   $t->start >= $sr->start
                && $t->end <= $sr->end)
            {
                $t->search_region_id($sr->id);
                last;
            }
        }
    }
}
