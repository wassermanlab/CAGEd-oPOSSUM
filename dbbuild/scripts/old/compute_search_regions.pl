#!/usr/bin/env perl

=head1 NAME

compute_search_regions.pl

=head1 SYNOPSIS

  compute_search_regions.pl
        -d f5op_name [-h f5op_host] -o search_regs_file
        [-f flank_size] [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -d f5op_name         = Name of FANTOM5 oPOSSUM DB containing the tag
                          positions
   -h f5op_host         = Host name of the FANTOM5 oPOSSUM DB
   -o search_regs_file  = Ouput search regions file
   -f flank_size        = Amount of flanking sequence to add on either side
                          of the tag regions in bp.
   -l log_file          = Name of log file to which processing and error
                          messages are written.
                          (Default = compute_search_regions.log)

=head1 DESCRIPTION

This is the FANTOM5 oPOSSUM3 script for computing search regions around the
CAGE tags for the FANTOM5 project.

XXX
DJA 2014/11/14
This script is out of date! Plus we can just use BEDTools to compute these
regions.

=head1 ALGORITHM

Foreach tag in the FANTOM5 oPOSSUM database, read the positional information,
add flanking bp around it. Merge search regions together and output to file.

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

#
# Use most current (development) libs.
# Comment out to use installed libs.
#
# On cognac/loire/rioja 
#
use lib '/apps/CAGEd_oPOSSUM/lib';


use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(get_logger :levels);
use OPOSSUM::DBSQL::DBAdaptor;

use constant DEBUG          => 1;
use constant LOG_FILE       => 'compute_search_regions.log';
use constant FANTOM_DB_HOST => 'fantom.cmmt.ubc.ca';
use constant FANTOM_DB_USER => "opossum_r";
use constant MAX_FLANK_SIZE => 2000;

# XXX should really check for all chromosme lengths
#use constant CHROM_LENGTH   => {'M' => 16299};
#
# XXX
# 2014/11/14
# The chromosome M length was incorrect which meant that some CAGE tag cluster
# coordinates fell outside the single chrM search region and got a search
# region ID of 0 assigned which caused problems. I manually updated the chrM
# search region to extend the length. There is a slight discrepancy between
# UCSC and Ensembl in the length of chrM. This uses the Ensembl length as
# this is where we extract sequences from for TFBS searching. UCSC gives the
# length as 16571.
#
use constant CHROM_LENGTH   => {'M' => 16569};

my $f5op_name;
my $f5op_host;
my $out_regions_file;
my $flank_size;
my $log_file = LOG_FILE;
GetOptions(
    'd=s'  => \$f5op_name,
    'h=s'  => \$f5op_host,
    'o=s'  => \$out_regions_file,
    'f=i'  => \$flank_size,
    'l=s'  => \$log_file
);

unless ($f5op_name) {
    pod2usage(
        -msg     => "No FANTOM5 oPOSSUM DB name specified",
        -verbose => 1
    );
}

unless (!$out_regions_file) {
    pod2usage(
        -msg     => "No output conserved regions file specified",
        -verbose => 1
    );
}

unless ($f5op_host) {
    $f5op_host = FANTOM_DB_HOST;
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
    filename => $log_file,
    mode     => "write"
);
#my $layout = Log::Log4perl::Layout::PatternLayout->new("%d %M:%L %p: %m%n");
my $layout = Log::Log4perl::Layout::PatternLayout->new("%M:%L %p: %m%n");
$appender->layout($layout);
$logger->add_appender($appender);

my $start_time = time;
my $localtime  = localtime($start_time);

$logger->info("Compute search regions started on $localtime\n");

my $dba = OPOSSUM::DBSQL::DBAdaptor->new(
    -host     => $f5op_host,
    -dbname   => $f5op_name,
    -user     => FANTOM_DB_USER,
    -password => undef
);

if (!$dba) {
    $logger->logdie("Error connecting to FANTOM5 DB - " . $DBI::errstr);
}

$logger->info("Max. flanking sequence = " . MAX_FLANK_SIZE);

open(OFH, ">$out_regions_file")
    || $logger->logdie("Error opening output search regions file - $!");

#
# Script is a bit out of date with the DB. The table is now called 'tss', not
# 'tags'.
# DJA 2014/11/14
#
#my $sql = qq{select chrom, start, end from tags};
my $sql = qq{select chrom, start, end from tss};

my $sth = $dba->dbc->prepare($sql);
unless ($sth) {
    $logger->logdie("Error preparing SQL statement: $sql - " . $DBI::errstr);
}

unless ($sth->execute()) {
    $logger->logdie("Error executing SQL statement: $sql - " . $DBI::errstr);
}

$logger->info("Fetching FANTOM5 tag regions");

#
# Store tag regions on a per chromosome basis.
#
my $chrom_tag_regions;
while (my @data = $sth->fetchrow_array) {
    my $chrom = $data[0];
    my $start = $data[1] - $flank_size;
    my $end   = $data[2] + $flank_size;

    my $chrom_length = CHROM_LENGTH->{$chrom};
    if ($chrom_length && $chrom_length < $end) {
        $end = $chrom_length;
    }

    $start = 1 if $start < 1;

    push @{$chrom_tag_regions->{$chrom}}, {
        -start      => $start,
        -end        => $end
    }
}

$chrom_tag_regions = combine_chrom_tag_regions($chrom_tag_regions);

my $sr_id = 1;
foreach my $chrom (keys %$chrom_tag_regions) {
    foreach my $reg (@{$chrom_tag_regions->{$chrom}}) {
        printf OFH "%s\t%d\t%d\n",
            $sr_id,
            $chrom,
            $reg->{-start},
            $reg->{-end};

        $sr_id++;
    }
}
close(OFH);

$localtime = time();
$logger->info("Compute search regions finished on $localtime");

exit;

sub combine_chrom_tag_regions
{
    my ($chr_regions) = @_;

    my @chroms = keys %$chr_regions;

    foreach my $chrom (@chroms) {
        my $regions = $chr_regions->{$chrom};

        $regions = combine_regions($chrom, $regions);

        $chr_regions->{$chrom} = $regions;
    }

    return $chr_regions;
}

sub combine_regions
{
    my ($chrom, $regs) = @_;

    return if !$regs || !$regs->[0];

    @$regs = sort {$a->{-start} <=> $b->{-start}} @$regs;

    my $num_regs = scalar @$regs;
    for (my $i = 0; $i < $num_regs; $i++) {
        my $reg1 = $regs->[$i] if exists($regs->[$i]);
        if ($reg1) {
            for (my $j = $i+1; $j < $num_regs; $j++) {
                my $reg2 = $regs->[$j] if exists ($regs->[$j]);
                if ($reg2) {
                    if (_do_features_combine($reg1, $reg2)) {
                        $logger->debug(
                            sprintf("Combining chr$chrom regions %d - %d and %d - %d",
                                $reg1->{-start},
                                $reg1->{-end},
                                $reg2->{-start},
                                $reg2->{-end}
                            )
                        );

                        if ($reg2->{-start} < $reg1->{-start}) {
                            $reg1->{-start} = $reg2->{-start};
                        }

                        if ($reg2->{-end} > $reg1->{-end}) {
                            $reg1->{-end} = $reg2->{-end};
                        }
                        delete $regs->[$j];
                    } else {
                        last;
                    }
                }
            }
        }
    }

    my @unique_regs;
    foreach my $reg (@$regs) {
        if (defined $reg) {
            push @unique_regs, $reg;
        }
    }

    return @unique_regs ? \@unique_regs : undef;
}

#
# Check if features should be combined. They should if they overlap or are
# adjacent (no gap between them).
#
sub _do_features_combine
{
    my ($feat1, $feat2) = @_;

    my $combine = 1;
    $combine = 0 if $feat1->{-start} > $feat2->{-end} + 1
        || $feat1->{-end} < $feat2->{-start} - 1;

    return $combine;
}
