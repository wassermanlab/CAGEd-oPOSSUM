#!/usr/bin/perl -w

=head1 NAME

  create_sge_scripts.pl

=head1 SYNOPSIS

  create_sge_scripts.pl
        [-h opossum_db_host] -d opossum_db_name
        -n num_scripts -c cmd [-o opt]
        [-s subdir] [-j job_name] [-x extension]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

  -h opossum_db_host    = Name of oPOSSUM DB host
  -d opossum_db_name    = Name of oPOSSUM DB
  -n num_scripts = Number of PBS scripts to generate. Genes to process
                   per script will this be approximately
                   total/num_scripts.
  -c cmd         = The perl script name (command minus options) that is run
                   in the PBS script. This should include the full path name
                   to the command.
  -o opt         = Options to use for the command minus any start/end gene
                   options, output and log file names.
                   NOTE: The oPOSSUM DB host, oPOSSUM DB name, start gene,
                   end gene, output and log file options are ASSUMED to be
                   designated by argument switches -h, -d, -s, -e, -o and
                   -l respectively and will be dynamically generated and
                   added to the command with the appropriate computed
                   values.
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

Generate multiple PBS scripts to queue/run the oPOSSUM build scripts on the
cluster nodes. Each PBS script runs the oPOSSUM script on a range of gene IDs
depending on the user entered -m and -n arguments.

=head1 AUTHOR

  David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia

  E-mail: dave@cmmt.ubc.ca

=cut

use lib '/home/dave/devel/oPOSSUM3/lib';

use Getopt::Long;
use Pod::Usage;
use POSIX qq{ceil};
use OPOSSUM::DBSQL::DBAdaptor;

use constant OPOSSUM_DB_HOST    => "opossum.cmmt.ubc.ca";
use constant OPOSSUM_DB_USER    => "opossum_r";

use constant BUILD_BASE_DIR     => '/lsata/oPOSSUM3/build';

my $opossum_db_host;
my $opossum_db_name;
my $num;
#my $total;
my $subdir;
my $base_job_name;
my $extension;
my $cmd;
my $opt;
GetOptions(
    'h=s'   => \$opossum_db_host,
    'd=s'   => \$opossum_db_name,
    'n=i'   => \$num,
    #'t=i'   => \$total,
    's=s'   => \$subdir,
    'j=s'   => \$base_job_name,
    'x=s'   => \$extension,
    'c=s'   => \$cmd,
    'o=s'   => \$opt
);

$opossum_db_host = OPOSSUM_DB_HOST unless $opossum_db_host;

if (!$opossum_db_name) {
    pod2usage(
        -msg => "Please enter the name of the oPOSSUM DB\n",
        -verbose => 1
    );
}

if (!$num) {
    pod2usage(
        -msg => "Please enter number of PBS scripts to generate\n",
        -verbose => 1
    );
}

if (!$cmd) {
    pod2usage(
        -msg     => "Please enter the command to run in this PBS script\n",
        -verbose => 1
    );
}

if (!$opt) {
    $opt = "";
#    pod2usage(
#        -msg     => "Please enter the command options\n",
#        -verbose => 1
#    );
}

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

my $opdba = OPOSSUM::DBSQL::DBAdaptor->new(
    -host            => $opossum_db_host,
    -dbname          => $opossum_db_name,
    -user            => OPOSSUM_DB_USER,
    -password        => undef
);

if (!$opdba) {
    $logger->logdie($DBI::errstr);
}

my $ga = $opdba->get_GeneAdaptor;
if (!$ga) {
    $logger->logdie("getting GeneAdaptor");
}

my $gene_ids = $ga->fetch_gene_ids();

@$gene_ids = sort {$a <=> $b} @$gene_ids;

my $gene_count = scalar @$gene_ids;

my $max_gene_id = $gene_ids->[$gene_count - 1];

my $gids_per_file = ceil($max_gene_id / $num);

my $gene_idx = 0;
my $count = 1;
while ($gene_idx < $gene_count) {
    my $start_gid = $gene_ids->[$gene_idx];
    my $end_gid   = $gene_ids->[$gene_idx + $gids_per_file - 1];

    # We went past the end
    unless ($end_gid) {
        $end_gid = $max_gene_id;
    }

    my $enum_base_name = $base_cmd;
    $enum_base_name    .= ".$extension" if $extension;
    $enum_base_name    .= sprintf(".%04d", $count);

    my $sh_script_name  = $sh_script_dir . "/$enum_base_name.sh";
    my $qsub_out_name   = $qsub_out_dir . "/$enum_base_name.out";
    my $qsub_err_name   = $qsub_err_dir . "/$enum_base_name.err";

    my $enum_log_file   = $log_dir . "/$enum_base_name.log";

    my $enum_out_file   = $base_out_file;
    $enum_out_file      .= ".$extension" if $extension;
    $enum_out_file      .= sprintf(".%04d.txt", $count);

    my $enum_job_name;
    if ($base_job_name) {
        $enum_job_name = $base_job_name;
        #$enum_job_name .= ".$extension" if $extension;
        #$enum_job_name .= sprintf(".%04d", $count);
        $enum_job_name .= sprintf("%04d", $count);
    } else {
        $enum_job_name = sprintf("job%04d", $count);
    }

    open(OFH, ">$sh_script_name")
        || die "Error creating PBS script $sh_script_name\n";

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

    print(OFH "$cmd $opt -h $opossum_db_host -d $opossum_db_name -s $start_gid"
            . " -e $end_gid -o $enum_out_file -l $enum_log_file\n\n");
    print(OFH "exit 0\n");

    close(OFH);

    chmod(0755, $sh_script_name);

    $gene_idx += $gids_per_file;
    $count++;
}

#
# The old way of doing it...
#
#my $count = 1;
#my $start_gid = 1;
#while ($count <= $num && $start_gid <= $total) {
#    my $end_gid = $start_gid + $gids_per_file - 1;
#    $end_gid = $total if $end_gid > $total;
#
#    my $enum_base_name = $base_cmd;
#    $enum_base_name    .= ".$extension" if $extension;
#    $enum_base_name    .= sprintf(".%03d", $count);
#
#    my $sh_script_name  = $sh_script_dir . "/$enum_base_name.sh";
#    my $qsub_out_name   = $qsub_out_dir . "/$enum_base_name.out";
#    my $qsub_err_name   = $qsub_err_dir . "/$enum_base_name.err";
#
#    my $enum_log_file   = $log_dir . "/$enum_base_name.log";
#
#    my $enum_out_file   = $base_out_file;
#    $enum_out_file      .= ".$extension" if $extension;
#    $enum_out_file      .= sprintf(".%03d.txt", $count);
#
#    my $enum_job_name;
#    if ($base_job_name) {
#        $enum_job_name = $base_job_name;
#        #$enum_job_name .= ".$extension" if $extension;
#        #$enum_job_name .= sprintf(".%03d", $count);
#        $enum_job_name .= sprintf("%03d", $count);
#    } else {
#        $enum_job_name = sprintf("job%03d", $count);
#    }
#
#    open(OFH, ">$sh_script_name")
#        || die "Error creating PBS script $sh_script_name\n";
#
#    print(OFH "#!/bin/bash\n\n");
#
#    print(OFH "### Name of the job\n");
#    print(OFH "#\$ -N $enum_job_name\n");
#    print(OFH "### Declare job is non-rerunable\n");
#    print(OFH "#\$ -r n\n");
#    print(OFH "### Export all environment variables to batch job\n");
#    print(OFH "#\$ -V\n");
#    #print(OFH "#$ -l walltime=99:00:00,nodes=1\n");
#    print(OFH "#\$ -o $qsub_out_name\n");
#    print(OFH "#\$ -e $qsub_err_name\n");
#    print(OFH "### E-mail notification on job abort\n");
#    print(OFH "#\$ -m a\n");
#    print(OFH "#\$ -M dave\@cmmt.ubc.ca\n\n");
#
#    # Keep track of which node job is run on for debugging purposes
#    print(OFH "echo \$HOSTNAME\n\n");
#
#    print(OFH "$cmd $opt"
#        . " -s $start_gid -e $end_gid -o $enum_out_file -l $enum_log_file\n\n");
#    print(OFH "exit 0\n");
#
#    close(OFH);
#    chmod(0755, $sh_script_name);
#
#    $count++;
#    $start_gid = $end_gid + 1;
#}
