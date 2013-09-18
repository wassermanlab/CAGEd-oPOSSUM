#!/usr/bin/env perl

=head1 NAME

parse_expression_files.pl

=head1 SYNOPSIS

  parse_expression_files.pl
        -d db_name
        -c tag_count_file
        -t tpm_file
        -o out_file
        [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -d db_name           = Name of the FANTOM5 oPOSSUM DB to use.
   -c tag_count_file    = Name of input FANTOM5 tag counts expression file.
   -t tag_count_file    = Name of input FANTOM5 TPM values expression file.
   -o out_file          = Output file which will contain the tag count and
                          TPM values for each TSS/experiment pair to be
                          loaded into the FANTOM5 oPOSSUM 'expression' table
                          via mysqlimport.
   -l log_file          = Optional name of log file. If not specified, the
                          log file will be named parse_expression_files.log.

=head1 DESCRIPTION

Script to parse FANTOM5 tag count and TPM expression files and create an output
text file for loading into the FANTOM5 database. This file is in tab delimeted
format with each column corresponding to the columns of the expression table in
the DB. The file can then be loaded into the DB via the mysqlimport facility.

CAUTION: This script ASSUMES that the order of the data values in each of the
input expression files is the same order as the experiments in the experiments
DB table!

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

use OPOSSUM::DBSQL::DBAdaptor;
#use OPOSSUM::Expression;

#
# For debugging memory usage!
#
use Devel::Size qw(size total_size);

use constant DEBUG      => 1;

#
# The column number in 0-based coordiantes of the first column which contains
# a TPM or tag count values (the first few columns contain the tag cluster
# information).
#
use constant VAL_COL_START  => 6;

use constant F5OP_DB_HOST   => 'fantom.cmmt.ubc.ca';
use constant F5OP_DB_USER   => 'opossum_r';

my $in_tag_count_file;
my $in_tpm_file;
my $out_file;
my $log_file;
my $db_name;
GetOptions(
    'c=s'   => \$in_tag_count_file,
    't=s'   => \$in_tpm_file,
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

unless ($in_tag_count_file) {
    pod2usage(
        -msg        => "No input tag counts file specified",
        -verbose    => 1
    );
}

unless ($in_tpm_file) {
    pod2usage(
        -msg        => "No input TPM values file specified",
        -verbose    => 1
    );
}

unless ($out_file) {
    pod2usage(
        -msg        => "No output file specified",
        -verbose    => 1
    );
}

unless (-f $in_tag_count_file) {
    die "Input tag counts file $in_tag_count_file does not exist!\n";
}

unless (-f $in_tpm_file) {
    die "Input TPM values file $in_tpm_file does not exist!\n";
}

unless ($log_file) {
    $log_file = "parse_expression_files.log";
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
    "Parsing expression files $in_tag_count_file and $in_tpm_file started on"
    . " $localtime\n"
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

#my $expa = $opdba->get_ExperimentAdaptor;
#unless ($expa) {
#    $logger->logdie("Error getting ExperimentAdaptor");
#}

my $tssa = $opdba->get_TSSAdaptor;
unless ($tssa) {
    $logger->logdie("Error getting TSSAdaptor");
}

#my $experiments = $expa->fetch_where;
#unless ($experiments) {
#    $logger->logdie("Error fetching experiments");
#}

#my $tss = $tssa->fetch_where;
#unless ($tss) {
#    $logger->logdie("Error fetching TSSs");
#}

my $tss_name_id = fetch_tss_name_id_map($tssa);

$logger->debug(
    sprintf("\$tss_name_id:\tsize = %d\ttotal_size = %d\n",
        size($tss_name_id),
        total_size($tss_name_id)
    )
);

#my @exp_ids = map {$_->id} @$experiments;

#$logger->info("Retrieving tag counts from file $in_tag_count_file");
#my $tss_counts = parse_tag_counts_file($in_tag_count_file, $tss_name_id);
#
#unless ($tss_counts) {
#    $logger->logdie("Error retrieving tag counts from file $in_tag_count_file");
#}
#
#$logger->debug(
#    sprintf("\$tss_counts:\tsize = %d\ttotal_size = %d\n",
#        size($tss_counts),
#        total_size($tss_counts)
#    )
#);
#
#$logger->info("Retrieving TPM values from file $in_tpm_file");
#my $tss_tpm = parse_tpm_file($in_tpm_file, $tss_name_id);
#
#unless ($tss_tpm) {
#    $logger->logdie("Error retrieving TPM values from file $in_tpm_file");
#}
#
#$logger->debug(
#    sprintf("\$tss_counts:\tsize = %d\ttotal_size = %d\n",
#        size($tss_tpm),
#        total_size($tss_tpm)
#    )
#);
#
#write_expression($out_file, $tss_counts, $tss_tpm);

parse_count_and_tpm_files(
    $in_tag_count_file, $in_tpm_file, $tss_name_id, $out_file
);

$localtime = localtime();

$logger->info("Parsing expression files finished on $localtime\n");

exit;

sub parse_count_and_tpm_files
{
    my ($count_file, $tpm_file, $tss_name_id, $out_file) = @_;

    open(CFH, "$count_file") || $logger->logdie(
        "Error opening input tag count file $count_file - $!"
    );

    open(TFH, "$tpm_file") || $logger->logdie(
        "Error opening input TPM values file $tpm_file - $!"
    );

    open(OFH, ">$out_file") || $logger->logdie(
        "Error opening output expression file $out_file - $!"
    );

    my $count_line = <CFH>;
    my $tpm_line = <TFH>;
    while ($count_line && $tpm_line) {
        chomp($count_line);
        chomp($tpm_line);

        my @count_cols = split /\t/, $count_line;
        my @tpm_cols = split /\t/, $tpm_line;

        my $tss_name = $count_cols[3];
        unless ($tss_name eq $tpm_cols[3]) {
            $logger->logdie("Count and TPM file are not in the same order!");
        }

        my $tss_id = $tss_name_id->{$tss_name};

        unless ($tss_id) {
            $logger->logdie("No TSS ID matching $tss_name!");
        }

        #
        # Columns VAL_COL_START..n are are the count/TPM values for each
        # experiment for this TSS.
        #
        # XXX
        # This assumes the values in the columns are in the same order
        # as the experiments file loaded into the DB! This assumption
        # should be correct but beware!
        # XXX
        #
        my $maxi = (scalar @count_cols) - 1;

        foreach my $i (VAL_COL_START .. $maxi) {
            #
            # Skip if both tag count and TPM value is 0
            #
            next unless $count_cols[$i] || $tpm_cols[$i];

            printf OFH "%d\t%d\t%d\t%s\n",
                $tss_id,
                #
                # Experiment number corresponds to the column number of the
                # TPM/tag count value.
                #
                $i - VAL_COL_START + 1,
                $count_cols[$i],
                $tpm_cols[$i]
        }

        $count_line = <CFH>;
        $tpm_line = <TFH>;
    }

    close(OFH);
    close(CFH);
    close(TFH);
}

sub parse_tag_counts_file
{
    my ($file, $tss_name_id) = @_;

    my %tss_counts;

    open(INFH, "$file")
        || $logger->logdie("Error opening input tag counts file $file - $!");

    while (my $line = <INFH>) {
        chomp($line);

        my @cols = split /\t/, $line;

        my $tss_name = $cols[3];

        my $tss_id = $tss_name_id->{$tss_name};

        unless ($tss_id) {
            $logger->logdie("No TSS ID matching $tss_name!");
        }

        #
        # Columns 6..n are are the tag counts for each experiment for
        # this TSS.
        #
        # XXX
        # This assumes the values in the columns are in the same order
        # as the experiments file loaded into the DB!
        # XXX
        #
        #foreach my $i (6..$#cols) {
        #    push @expression, OPOSSUM::Expression->new(
        #        -tss_id         => $tss_id,
        #        -experiment_id  => $i - 5,
        #        -tag_count      => $cols[$i]
        #    );
        #}
        $tss_counts{$tss_id} = [@cols[6..$#cols]];
    }

    close(INFH);

    return %tss_counts ? \%tss_counts : undef;
}

sub parse_tpm_file
{
    my ($file, $tss_name_id) = @_;

    my %tss_tpm;

    open(INFH, "$file")
        || $logger->logdie("Error opening input TPM values file $file - $!");

    while (my $line = <INFH>) {
        chomp($line);

        my @cols = split /\t/, $line;

        my $tss_name = $cols[3];

        my $tss_id = $tss_name_id->{$tss_name};

        unless ($tss_id) {
            $logger->logdie("No TSS ID matching $tss_name!");
        }

        #
        # Columns 6..n are are the TPM values for each experiment for
        # this TSS.
        #
        # XXX
        # This assumes the values in the columns are in the same order
        # as the experiments file loaded into the DB!
        # XXX
        #
        #foreach my $i (6..$#cols) {
        #    $expression->{$tss_id}->{$i - 5}->{-t} = $cols[$i];
        #}
        $tss_tpm{$tss_id} = [@cols[6..$#cols]];
    }

    close(INFH);

    return %tss_tpm ? \%tss_tpm : undef;
}

sub write_expression
{
    my ($file, $tss_counts, $tss_tpm) = @_;

    open(OFH, ">$file")
        || $logger->logdie("Error opening output expression file $file - $!");

    foreach my $tss_id (sort keys %$tss_counts) {
        my $counts = $tss_counts->{$tss_id};
        my $tpm    = $tss_tpm->{$tss_id};

        my $maxi = (scalar @$counts) - 1;
        foreach my $i (0..$maxi) {
            printf "%d\t%d\t%d\t%s\n",
                $tss_id,
                $i + 1,
                $counts->[$i],
                $tpm->[$i]
        }
    }

    close(OFH);
}

#
# To save memory, don't fetch all the TSSs. Just fetch names and IDs and
# create at name->ID map.
#
sub fetch_tss_name_id_map
{
    my ($tssa) = @_;

    my $sql = "select id, name from tss";

    my $sth = $tssa->prepare($sql);

    unless ($sth) {
        $logger->logdie("Error preparing fetch TSS name/IDs");
    }

    unless ($sth->execute) {
        $logger->logdie("Error excuting fetch TSS name/IDs");
    }

    my %name_id;
    while (my @row = $sth->fetchrow_array) {
        $name_id{$row[1]} = $row[0];
    }

    return %name_id ? \%name_id : undef;
}
