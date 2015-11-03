#!/usr/bin/env perl

=head1 NAME

update_relative_expression.pl

=head1 SYNOPSIS

  update_relative_expression.pl
        -d db_name
        -i rel_expr_file
        -o out_file
        [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -d db_name           = Name of the FANTOM5 oPOSSUM DB to use.
   -i rel_expr_file     = Name of input FANTOM5 relative expression file.
   -o out_file          = Name of output file to which SQL update commands
                          will be written.
   -l log_file          = Optional name of log file. If not specified, the
                          log file will be named
                          update_relative_expression.log.

=head1 DESCRIPTION

Script to parse the FANTOM5 relative expression file and update the
relative_expression field of the expression table. Unlike the
parse_expression_files.pl script which outputs a data file to be loaded into
the DB with mysqlimport, this creates a file with update commands to update
the existing expression records. The relative expression file should be
integrated into the parse_expression_files.pl process for future loads but
NOTE that the relative expression file has a slightly difference format than
the tag counts and tpm files.

XXX Two experiments are out of order in the file (from the order in the
previous expression files processed and the order in the DB). The experiments
with IDs 576 (FF:10071-101I8, 'duodenum, fetal, donor1, tech_rep2') and 853 
(FF:10063-101H9, 'temporal lobe, fetal, donor1, tech_rep2'). Verified that it
is not just the column headers that were swapped the data colums too. So
exp. 576 has it's header/data in column 854 and exp. 853 had it's data in
column 577 (note the apparent off-by-1 as the cluster_id is in the
first column).

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
use URI::Encode qw(uri_encode uri_decode);

use OPOSSUM::DBSQL::DBAdaptor;
#use OPOSSUM::Expression;

#
# For debugging memory usage!
#
use Devel::Size qw(size total_size);

use constant DEBUG      => 1;

#
# The column number in 0-based coordiantes of the first column which contains
# an actual relative expression value. The first column contains the CAGE
# tag cluster ID, e.g. chr10:100013403..100013414,-
# The first line is the header. The first value is the header 'cluster_id'
# the rest of the tab separated values are the actual FANTOM5 experiment
# names.
#
use constant VAL_COL_START  => 1;

use constant F5OP_DB_HOST   => 'fantom.cmmt.ubc.ca';
use constant F5OP_DB_USER   => 'opossum_r';

my $in_file;
my $out_file;
my $log_file;
my $db_name;
GetOptions(
    'i=s'   => \$in_file,
    'o=s'   => \$out_file,
    'l=s'   => \$log_file,
    'd=s'   => \$db_name
);

unless ($db_name) {
    pod2usage(
        -msg        => "No FANTOM5 oPOSSUM DB name specified",
        -verbose    => 1
    );
}

unless ($in_file) {
    pod2usage(
        -msg        => "No input relative expression file specified",
        -verbose    => 1
    );
}

unless ($out_file) {
    pod2usage(
        -msg        => "No output SQL update statements file specified",
        -verbose    => 1
    );
}

unless (-f $in_file) {
    die "Input relative expression file $in_file does not exist!\n";
}

unless ($log_file) {
    $log_file = "update_relative_expression.log";
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

$logger->info(
    "Parsing relative expression $in_file started on $localtime\n"
);

my $opdba = OPOSSUM::DBSQL::DBAdaptor->new(
    -host       => F5OP_DB_HOST,
    -dbname     => $db_name,
    -user       => F5OP_DB_USER,
    -password   => undef
);

if (!$opdba) {
    $logger->logdie(
        "Error connecting to FANTOM5 oPOSSUM database - $DBI::errstr"
    );
}

my $expa = $opdba->get_ExperimentAdaptor;
unless ($expa) {
    $logger->logdie("Error getting ExperimentAdaptor");
}

my $tssa = $opdba->get_TSSAdaptor;
unless ($tssa) {
    $logger->logdie("Error getting TSSAdaptor");
}

my $exp_name_id_map = fetch_experiment_name_id_map($expa);

parse_relative_expression_file($in_file, $out_file);

$localtime = localtime();

$logger->info("Parsing expression files finished on $localtime\n");

exit;

sub parse_relative_expression_file
{
    my ($expr_file, $out_file) = @_;

    open(FH, "$expr_file") || $logger->logdie(
        "Error opening input relative expression file $expr_file - $!"
    );

    open(OFH, ">$out_file") || $logger->logdie(
        "Error opening output file $out_file - $!"
    );

    my $sample_line = <FH>;
    chomp $sample_line;
    my @samp_data = split "\t", $sample_line;

    unless ($samp_data[0] eq 'cluster_id') {
        die "Parse error processing first line of relative expression file\n";
    }

    my $num_samples = scalar @samp_data - 1;

    my $samp_exp_names = parse_samp_data(\@samp_data);

    # for debugging
    my $max_expr_lines_to_process = 3;
    my $exp_line_count = 0;
    while (my $expr_line = <FH>) {
        chomp($expr_line);
        my @expr_data = split "\t", $expr_line;
        my $tss_name = $expr_data[0];

        my $num_expr_data = scalar @expr_data - 1;

        unless ($num_expr_data == $num_samples) {
            die "$tss_name - number of expression data points $num_expr_data"
                . " does not match number of samples (experiments)"
                . " $num_samples\n";
        }

        my $tss_id = @{$tssa->fetch_ids_where("name = '$tss_name'")}[0];

        my $exp_idx = 1;
        while ($exp_idx <= $num_samples) {
            my $rel_expr = $expr_data[$exp_idx];
            my $exp_name = $samp_exp_names->[$exp_idx - 1];
            my $exp_id = $exp_name_id_map->{$exp_name};

            unless ($rel_expr == 0) {
                printf OFH "update expression set relative_expression = '%.16f'"
                    . " where tss_id = $tss_id and experiment_id = $exp_id;\n",
                    $rel_expr;
            }

            $exp_idx++;
        }

        $exp_line_count++;
        #last if $exp_line_count >= $max_expr_lines_to_process;
    }

    close(FH);
    close(OFH);
}

sub parse_samp_data
{
    my ($samp_data) = @_;

    my @exp_names;

    foreach my $samp_name (@$samp_data) {
        next if $samp_name eq 'cluster_id';
        $samp_name =~ s/^tpm\.//;
        $samp_name =~ s/\.CNhs.*//;

        my $exp_name = uri_decode($samp_name);
        push @exp_names, $exp_name;
    }

    return @exp_names ? \@exp_names : undef;
}

#
# Fetch a map of experiment names to IDs.
#
sub fetch_experiment_name_id_map
{
    my ($expa) = @_;

    my $sql = "select id, name from experiments";

    my $sth = $expa->prepare($sql);

    unless ($sth) {
        $logger->logdie("Error preparing fetch experiment name/IDs");
    }

    unless ($sth->execute) {
        $logger->logdie("Error excuting fetch experiment name/IDs");
    }

    my %name_id;
    while (my @row = $sth->fetchrow_array) {
        $name_id{$row[1]} = $row[0];
    }

    return %name_id ? \%name_id : undef;
}
