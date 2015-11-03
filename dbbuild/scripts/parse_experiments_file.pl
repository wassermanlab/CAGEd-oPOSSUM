#!/usr/bin/env perl

=head1 NAME

parse_experiments_file.pl

=head1 SYNOPSIS

  parse_experiments_file.pl
        -i experiments_file
        -o out_file
        [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -i experiments_file  = Name of input FANTOM5 experiments file. We want
                          the file which contains the actual list of BED
                          files names rather than the exepriments file, e.g.
                          for human we use the tc_quantify.oe file rather
                          than the hg19_experiments_from_tpm.txt file as
                          there is more information encoded in the BED file
                          names than in the lines in the experiments file.
                          This file is one experiment file name per line.
                          These lines contain a full file path and are URL
                          encoded.

   -o out_file          = Name of the output file to be loaded into the 
                          FANTOM5 oPOSSUM DB experiments table via
                          mysqlimport.

   -l log_file          = Optional name of log file. If not specified then
                          the log file will be named
                          parse_experiments_file.log.

=head1 DESCRIPTION

Script to parse a FANTOM5 experiments file and create an output text file for
loading into the FANTOM5 database's 'experiments' table. This file is in tab
delimeted format with each column corresponding to the columns of the
experiments table in the DB. The file can then be loaded into the DB via the
mysqlimport facility.

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

use lib '/devel/FANTOM5_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(get_logger :levels);
#use URI::Encode;   # Does not work properly on lowercase e.g. %2a
use URI::Escape;

use OPOSSUM::Experiment;

use constant DEBUG      => 0;

my $in_file;
my $out_file;
my $log_file;
GetOptions(
    'i=s'   => \$in_file,
    'o=s'   => \$out_file,
    'l=s'   => \$log_file
);

unless ($in_file) {
    pod2usage(
        -msg        => "No input experiments file specified",
        -verbose    => 1
    );
}

unless ($out_file) {
    pod2usage(
        -msg        => "No output file specified",
        -verbose    => 1
    );
}

unless (-f $in_file) {
    die "Input experiments file $in_file does not exist!\n";
}

unless ($log_file) {
    $log_file = "parse_experiments_file.log";
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

$logger->info("Parsing experiments file $in_file started on $localtime\n");

my $experiments = parse_experiments_file($in_file);

unless ($experiments) {
    $logger->logdie("Error reading experiments from file $in_file\n");
}

write_experiments($out_file, $experiments);

$localtime = localtime();

$logger->info("Parsing experiments file $in_file finished on $localtime\n");

exit;

sub parse_experiments_file
{
    my ($file) = @_;

    #
    # XXX
    # Misses codes with lowercase chars, e.g. %2c???
    # XXX
    #
    #my $uri = URI::Encode->new();

    open(INFH, "$file")
        || $logger->logdie("Error opening input experiments file $file - $!");

    my @experiments;

    my $exp_id = 1;
    while (my $line = <INFH>) {
        chomp($line);

        #$line = $uri->decode($line);

        $line = uri_unescape($line);

        if ($line =~ /\/(\w+)\.(\w+)\.(\w+)\/(.+)\.CNhs(\d+)\.(\d+-??\w*?)\./) {
            my $species = $1;
            unless ($species eq 'human' || $species eq 'mouse') {
                $logger->error("Unrecognized species: $species\n");
                next;
            }

            push @experiments, OPOSSUM::Experiment->new(
                -id         => $exp_id++,
                -type       => $2,
                -method     => $3,
                -name       => $4,
                -CNhs_id    => $5,
                -FF_id      => $6
            );
        } else {
            $logger->error("Unrecognized experiment line:\n$line\n");
        }
    }

    close(INFH);

    return @experiments ? \@experiments : undef;
}

sub write_experiments
{
    my ($file, $experiments) = @_;

    open(OFH, ">$file")
        || $logger->logdie("Error opening output experiments file $file - $!");

    foreach my $exp (@$experiments) {
        printf OFH
            "%d\t%s\t%d\t%s\t%s\t%s\n",
            $exp->id,
            $exp->FF_id,
            $exp->CNhs_id,
            $exp->type,
            $exp->method,
            $exp->name
    }

    close(OFH);
}
