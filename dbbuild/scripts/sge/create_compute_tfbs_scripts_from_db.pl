#!/usr/bin/perl -w

=head1 NAME

  create_compute_tfbss_scripts_from_db.pl

=head1 SYNOPSIS

  create_compute_tfbss_sge_scripts.pl
        [-h f5op_db_host] -d f5op_db_name
        -n num_scripts -c cmd [-o opt]
        [-s subdir] [-j job_name] [-x extension]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

  -i sr_file     = Name of the input search regions file
  -h f5op_db_host   = Name of FANTOM5 oPOSSUM DB host
  -d f5op_db_name   = Name of FANTOM5 oPOSSUM DB
  -n num_scripts = Number of SGE scripts to generate. Search regions to
                   process per script will be approximately
                   total/num_scripts.
  -c cmd         = The perl script name (command minus options) that is run
                   in the SGE script. This should include the full path name
                   to the command.
  -o opt         = Options to use for the command minus any output and log
                   file names.
                   NOTE: The DB host, DB name, output and log file options
                   are ASSUMED to be designated by argument switches
                   -h, -d, -o and -l respectively and will be dynamically
                   generated and added to the command with the appropriate
                   computed values.
  -s subdir      = Optional subdirectory under the base oPOSSUM build
                   directory BASE_BUILD_DIR into which SGE scripts/log/error
                   etc. files are written. This subdir should in turn
                   contain the following subdirs:
                    /data /err /log /out /sh
  -j job_name    = Used as (abbreviated) base job name to call the job
                   passed to qsub command.
  -x extension   = Optional extra file name extension to add to
                   scripts/output/log/error files generated, before the
                   numeric extension.

=head1 DESCRIPTION

Generate multiple SGE scripts to queue/run the FANTOM5 oPOSSUM compute TFBSs
script on the cluster nodes. Each SGE script runs the oPOSSUM script on a
sub-file of the input search regions file depending on the user entered -n
argument.

=head1 AUTHOR

  David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia

  E-mail: dave@cmmt.ubc.ca

=cut

use lib '/devel/FANTOM5_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use POSIX qq{ceil};
use File::Basename;

use OPOSSUM::DBSQL::DBAdaptor;

use constant F5OP_DB_HOST    => "fantom.cmmt.ubc.ca";
use constant F5OP_DB_USER    => "opossum_r";

use constant BUILD_BASE_DIR     => '/lsata/FANTOM5_oPOSSUM/build';

my $f5op_db_host;
my $f5op_db_name;
my $num;
#my $total;
my $subdir;
my $base_job_name;
my $extension;
my $cmd;
my $opt;
GetOptions(
    'h=s'   => \$f5op_db_host,
    'd=s'   => \$f5op_db_name,
    'n=i'   => \$num,
    #'t=i'   => \$total,
    's=s'   => \$subdir,
    'j=s'   => \$base_job_name,
    'x=s'   => \$extension,
    'c=s'   => \$cmd,
    'o=s'   => \$opt
);

$f5op_db_host = F5OP_DB_HOST unless $f5op_db_host;

if (!$f5op_db_name) {
    pod2usage(
        -msg => "Please enter the name of the oPOSSUM DB\n",
        -verbose => 1
    );
}

if (!$num) {
    pod2usage(
        -msg => "Please enter number of SGE scripts to generate\n",
        -verbose => 1
    );
}

if (!$cmd) {
    pod2usage(
        -msg     => "Please enter the command to run in this SGE script\n",
        -verbose => 1
    );
}

unless ($f5op_db_name) {
    $f5op_db_name = F5OP_DB_NAME;
}

if (!$opt) {
    $opt = "";
#    pod2usage(
#        -msg     => "Please enter the command options\n",
#        -verbose => 1
#    );
}

my $dba = OPOSSUM::DBSQL::DBAdaptor->new(
    -host       => $f5op_db_host,
    -name       => $f5op_db_name,
    -user       => F5OP_DB_USER,
    -pass       => undef
);

unless ($dba) {
    die "Could not connect to FANTOM5 oPOSSUM DB\n";
}

my $sra = $dba->get_SearchRegionAdaptor;

unless ($sra) {
    die "Could not get SearchRegionAdaptor\n";
}

my $sr_ids = $sra->fetch_ids;

my $total_search_regions = scalar @$sr_ids;

#
# XXX
# NOTE: This is only valid if the total number of search regions is equal to
# the max. search region ID (i.e. search regions IDs range from 1 to total
# number of search regions)
# XXX
#
my $num_regions_per_file = ceil($total_search_regions / $num);

my $build_dir = BUILD_BASE_DIR;
$build_dir .= "/$subdir" if $subdir;

my $sh_script_dir   = $build_dir . "/sh";
my $qsub_out_dir    = $build_dir . "/out";
my $qsub_err_dir    = $build_dir . "/err";
my $out_dir         = $build_dir . "/data";
my $log_dir         = $build_dir . "/log";

my $base_cmd = $cmd;
$base_cmd =~ s/.*\///;
$base_cmd =~ s/\.pl$//;

my $base_out_file;
if ($base_cmd =~ /^compute_(\S+)/) {
    $base_out_file = "$out_dir/$1";
} else {
    die "Error determining base output data file name from base"
        . " command $base_cmd\n";
}

foreach my $i (0 .. $num - 1) {
    my $filenum = $i + 1;

    my $start_sr_id = $num_regions_per_file * $i + 1;
    last if $start_sr_id > $total_search_regions;

    my $end_sr_id = $num_regions_per_file * ($i + 1);
    $end_sr_id = $total_search_regions if $total_search_regions < $end_sr_id;

    my $enum_base_name = $base_cmd;
    $enum_base_name    .= ".$extension" if $extension;
    $enum_base_name    .= sprintf(".%03d", $filenum);

    my $sh_script_name  = $sh_script_dir . "/$enum_base_name.sh";
    my $qsub_out_name   = $qsub_out_dir . "/$enum_base_name.out";
    my $qsub_err_name   = $qsub_err_dir . "/$enum_base_name.err";

    my $enum_log_file   = $log_dir . "/$enum_base_name.log";

    my $enum_out_file   = $base_out_file;
    $enum_out_file      .= ".$extension" if $extension;
    $enum_out_file      .= sprintf(".%03d.txt", $filenum);

    my $enum_job_name;
    if ($base_job_name) {
        $enum_job_name = $base_job_name;
        #$enum_job_name .= ".$extension" if $extension;
        #$enum_job_name .= sprintf(".%04d", $i);
        $enum_job_name .= sprintf("%03d", $filenum);
    } else {
        $enum_job_name = sprintf("job%03d", $filenum);
    }

    open(OFH, ">$sh_script_name")
        || die "Error creating SGE script $sh_script_name\n";

    print(OFH "#!/bin/bash\n\n");

    print(OFH "### Name of the job\n");
    print(OFH "#\$ -N $enum_job_name\n");
    print(OFH "### Declare job is non-rerunable\n");
    print(OFH "#\$ -r n\n");
    print(OFH "### Export all environment variables to batch job\n");
    print(OFH "#\$ -V\n");
    #print(OFH "#$ -l walltime=99:00:00,nodes=1\n");
    print(OFH "#\$ -o $qsub_out_name\n");
    print(OFH "#\$ -e $qsub_err_name\n");
    print(OFH "### E-mail notification on job abort\n");
    print(OFH "#\$ -m a\n");
    print(OFH "#\$ -M dave\@cmmt.ubc.ca\n\n");

    # Keep track of which node job is run on for debugging purposes
    print(OFH "echo \$HOSTNAME\n\n");

    print(OFH "$cmd $opt -s $start_sr_id -e $end_sr_id -h $f5op_db_host"
            . " -d $f5op_db_name -o $enum_out_file -l $enum_log_file\n\n");
    print(OFH "exit 0\n");

    close(OFH);

    chmod(0755, $sh_script_name);
}
