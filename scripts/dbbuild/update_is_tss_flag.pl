#!/usr/bin/env perl

=head1 NAME

update_is_tss_flag.pl

=head1 SYNOPSIS

  update_is_tss_flag.pl -i tss_file -d f5op_db_name -u f5op_db_user
    -p f5op_db_pass [-h f5op_db_host] [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -i tss_file          = Name of input TSS BED file containing the TSS
                          definitions including the TSS assessment score.
   -d f5op_db_name      = Name of FANTOM5 oPOSSUM db we are working on.
   -u f5op_db_user      = User name of FANTOM5 oPOSSUM DB with update
                          privileges.
   -p f5op_db_pass      = Password of FANTOM5 oPOSSUM DB write user.
   -h f5op_db_host      = Host name of the FANTOM5 oPOSSUM db.
   -l log_file          = Name of log file to which processing and error
                          messages are written.
                          (Default = update_is_tss.log)

=head1 DESCRIPTION

This is the FANTOM5 oPOSSUM script for updating the 'is_tss' field of the
tss table based on the values of the TSS assessment scores from the input
BED file.

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
use OPOSSUM::TSS;

use constant DEBUG => 0;

use constant LOG_FILE 		            => 'update_is_tss.log';

use constant FANTOM5_OPOSSUM_DB_HOST    => 'fantom.cmmt.ubc.ca';

#
# Don't use these thresholds as they are hard to parse (column which contains
# these values has a variable number of comma separated values. Instead use the
# the last column (column 9). If the RGB value string is '60,179,113', then
# this is a TSS.
#
#use constant TSS_THRESHOLD_HUMAN        => 0.228;
#use constant TSS_THRESHOLD_MOUSE        => 0.220;
use constant TSS_RGB_VALUE              => '60,179,113';

my $log_file = LOG_FILE;
my $tss_file;
my $fantom_opossum_db_name;
my $fantom_opossum_db_user;
my $fantom_opossum_db_pass;
my $fantom_opossum_db_host;
#my $tss_threshold;
GetOptions(
    'i=s'   => \$tss_file,
    'd=s'   => \$fantom_opossum_db_name,
    'u=s'   => \$fantom_opossum_db_user,
    'p=s'   => \$fantom_opossum_db_pass,
    'h=s'   => \$fantom_opossum_db_host,
#    't=f'   => \$tss_threshold,
    'l=s'	=> \$log_file
);

if (!$fantom_opossum_db_name) {
    pod2usage(
        -msg        => "No FANTOM5 oPOSSUM DB name specified",
        -verbose    => 1
    );
}

if (!$fantom_opossum_db_user) {
    pod2usage(
        -msg        => "No FANTOM5 oPOSSUM DB user specified",
        -verbose    => 1
    );
}

if (!$fantom_opossum_db_pass) {
    pod2usage(
        -msg        => "No FANTOM5 oPOSSUM DB password specified",
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

$logger->info("Update TSSs started on $localtime\n");

my $opdba = OPOSSUM::DBSQL::DBAdaptor->new(
    -host       => $fantom_opossum_db_host,
    -dbname     => $fantom_opossum_db_name,
    -user       => $fantom_opossum_db_user,
    -password   => $fantom_opossum_db_pass
);

unless ($opdba) {
    $logger->logdie(
        "Error connecting to FANTOM5 oPOSSUM database - $DBI::errstr"
    );
}

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

#unless (defined $tss_threshold) {
#    if ($species eq 'human') {
#        $tss_threshold = TSS_THRESHOLD_HUMAN;
#    } elsif ($species eq 'mouse') {
#        $tss_threshold = TSS_THRESHOLD_MOUSE;
#    } else {
#        $logger->logdie("Invalid species '$species'");
#    }
#}

#$logger->info("TSS threshold: $tss_threshold");

open(IFH, $tss_file)
    || $logger->logdie("Could not open input TSS file $tss_file - $!");

my @short_descs;
while (my $line = <IFH>) {
    chomp $line;

    my @data = split /\t/, $line;

    my $name_col = $data[3];
    my $rgb_value = $data[8];

    #my ($short_desc) = split ',', $name_col;
    my $short_desc = $name_col;
    $short_desc =~ s/,\d+.*$//;

    #if ($short_desc =~ /^p\d*\@\w+$/) {
        if ($rgb_value eq TSS_RGB_VALUE) {
            push @short_descs, $short_desc;
        }
    #} else {
    #    $logger->warn("Invalid short description $short_desc");
    #}
}

close(IFH);

$logger->info(
    sprintf("Number of tag clusters to update = %d", scalar @short_descs)
);

my $where_clause = "where t.id = x.tss_id and x.short_description in ('"
                   . join("','", @short_descs)
                   . "')";

my $sql = "update tss t, tss_extra x set t.is_tss = 1 $where_clause";

my $sql_result = $opdba->dbc->db_handle->do($sql) || $logger->logdie(
    "Error executing SQL statement:\n" . $opdba->dbc->db_handle->errstr . "\n\n"
);

$logger->info("SQL update returned: $sql_result\n");

my $end_time = time;
$localtime = localtime($end_time);
my $elapsed_secs = $end_time - $start_time;

$logger->info("Update is_tss flag completed on $localtime");
$logger->info("Elapsed time (s): $elapsed_secs");
