#!/usr/bin/perl -w

=head1 NAME

  create_compute_tfbss_sge_scripts.pl

=head1 SYNOPSIS

  create_compute_tfbss_sge_scripts.pl
        [-i sr_file] [-h opossum_db_host] -d opossum_db_name
        -n num_scripts -c cmd [-o opt]
        [-s subdir] [-j job_name] [-x extension]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

  -i sr_file     = Name of the input search regions file
  -h opossum_db_host    = Name of oPOSSUM DB host
  -d opossum_db_name    = Name of oPOSSUM DB
  -n num_scripts = Number of SGE scripts to generate. Search regions to
                   process per script will this be approximately
                   total search regions/num_scripts.
  -c cmd         = The perl script name (command minus options) that is run
                   in the SGE script. This should include the full path name
                   to the command.
  -o opt         = Options to use for the command minus any output and log
                   file names.
                   NOTE: The oPOSSUM DB host, oPOSSUM DB name, output and
                   log file options are ASSUMED to be designated by argument
                   switches -h, -d, -o and -l respectively and will be
                   dynamically generated and added to the command with the
                   appropriate computed values.
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

Generate multiple SGE scripts to queue/run the CAGEd-oPOSSUM compute TFBSs
script on the cluster nodes. If an input search regions file is given, each
SGE script runs the oPOSSUM script on a sub-file of search regions otherwise
the SGE scripts are generated to run on a subset of search region IDs from the
database depending on the user entered -n argument.

=head1 AUTHOR

  David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia

  E-mail: dave@cmmt.ubc.ca

=cut

use lib '/apps/CAGEd_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use POSIX qq{ceil};
use File::Basename;

use OPOSSUM::DBSQL::DBAdaptor;

use constant OPOSSUM_DB_HOST    => "fantom.cmmt.ubc.ca";
use constant OPOSSUM_DB_USER    => "opossum_r";

use constant BUILD_BASE_DIR     => '/lsata/CAGEd_oPOSSUM/build';

my $sr_file;
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
    'i=s'   => \$sr_file,
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

if ($sr_file) {
    my $sr_files = split_file($sr_file, $num);

    my $num_sr_files = scalar @$sr_files;

    my $count = 1;
    while ($count <= $num_sr_files) {
        my $in_sr_file = $sr_files->[$count - 1];

        my $enum_base_name = $base_cmd;
        $enum_base_name    .= ".$extension" if $extension;
        $enum_base_name    .= sprintf(".%03d", $count);

        my $sh_script_name  = $sh_script_dir . "/$enum_base_name.sh";
        my $qsub_out_name   = $qsub_out_dir . "/$enum_base_name.out";
        my $qsub_err_name   = $qsub_err_dir . "/$enum_base_name.err";

        my $enum_log_file   = $log_dir . "/$enum_base_name.log";

        my $enum_out_file   = $base_out_file;
        $enum_out_file      .= ".$extension" if $extension;
        $enum_out_file      .= sprintf(".%03d.txt", $count);

        my $enum_job_name;
        if ($base_job_name) {
            $enum_job_name = $base_job_name;
            #$enum_job_name .= ".$extension" if $extension;
            #$enum_job_name .= sprintf(".%03d", $count);
            $enum_job_name .= sprintf("%03d", $count);
        } else {
            $enum_job_name = sprintf("job%03d", $count);
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
        print(OFH "#\$ -o $qsub_out_name\n");
        print(OFH "#\$ -e $qsub_err_name\n");
        print(OFH "### E-mail notification on job abort\n");
        print(OFH "#\$ -m a\n");
        print(OFH "#\$ -M dave\@cmmt.ubc.ca\n");
        print(OFH "#\$ -l mem_free=500M,h_vmem=2G,h_rt=24:0:0\n\n");

        # Keep track of which node job is run on for debugging purposes
        print(OFH "echo \$HOSTNAME\n\n");

        print(OFH "$cmd $opt -i $in_sr_file -h $opossum_db_host"
                . " -d $opossum_db_name -o $enum_out_file -l $enum_log_file\n");

        close(OFH);

        chmod(0755, $sh_script_name);

        $count++;
    }
} else {
    my $opdba = OPOSSUM::DBSQL::DBAdaptor->new(
        -host            => $opossum_db_host,
        -dbname          => $opossum_db_name,
        -user            => OPOSSUM_DB_USER,
        -password        => undef
    );

    unless ($opdba) {
        $logger->logdie("Error connecting to CAGEd-oPOSSUM DB - "
            . $opdba->dbc->errstr);
    }

    my $sra = $opdba->get_SearchRegionAdaptor;
    if (!$sra) {
        $logger->logdie("getting SearchRegionAdaptor");
    }

    my $sr_ids = $sra->fetch_ids();

    @$sr_ids = sort {$a <=> $b} @$sr_ids;

    my $sr_count = scalar @$sr_ids;

    my $max_sr_id = $sr_ids->[$sr_count - 1];

    my $ids_per_file = ceil($max_sr_id / $num);

    my $sr_idx = 0;
    my $count = 1;
    while ($sr_idx < $sr_count) {
        my $start_id = $sr_ids->[$sr_idx];
        my $end_id   = $sr_ids->[$sr_idx + $ids_per_file - 1];

        # We went past the end
        unless ($end_id) {
            $end_id = $max_sr_id;
        }

        my $enum_base_name = $base_cmd;
        $enum_base_name    .= ".$extension" if $extension;
        $enum_base_name    .= sprintf(".%03d", $count);

        my $sh_script_name  = $sh_script_dir . "/$enum_base_name.sh";
        my $qsub_out_name   = $qsub_out_dir . "/$enum_base_name.out";
        my $qsub_err_name   = $qsub_err_dir . "/$enum_base_name.err";

        my $enum_log_file   = $log_dir . "/$enum_base_name.log";

        my $enum_out_file   = $base_out_file;
        $enum_out_file      .= ".$extension" if $extension;
        $enum_out_file      .= sprintf(".%03d.txt", $count);

        my $enum_job_name;
        if ($base_job_name) {
            $enum_job_name = $base_job_name;
            #$enum_job_name .= ".$extension" if $extension;
            #$enum_job_name .= sprintf(".%03d", $count);
            $enum_job_name .= sprintf("%03d", $count);
        } else {
            $enum_job_name = sprintf("job%03d", $count);
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
        print(OFH "#\$ -o $qsub_out_name\n");
        print(OFH "#\$ -e $qsub_err_name\n");
        print(OFH "### E-mail notification on job abort\n");
        print(OFH "#\$ -m a\n");
        print(OFH "#\$ -M dave\@cmmt.ubc.ca\n");
        print(OFH "#\$ -l mem_free=500M,h_vmem=2G,h_rt=24:0:0\n\n");

        # Keep track of which node job is run on for debugging purposes
        print(OFH "echo \$HOSTNAME\n\n");

        print(OFH "$cmd $opt -h $opossum_db_host -d $opossum_db_name"
                . " -s $start_id -e $end_id -o $enum_out_file"
                . " -l $enum_log_file\n");

        close(OFH);

        chmod(0755, $sh_script_name);

        $sr_idx += $ids_per_file;
        $count++;
    }
}

sub split_file
{
    my ($file, $num_files) = @_;

    my @out_files;

    my $out = `exec 2>&1; wc $file`;

    my $total_lines;
    if ($out =~ /\s*(\d+)/) {
        $total_lines = $1;
    }

    my $num_lines = ceil($total_lines / $num_files);

    unless (open(IFH, $file)) {
        die("Error opening input file $file - $!");
    }

    #logger("Splitting input file $file");

    my ($base_file, $dir, $suffix) = fileparse($file, qr/\.[^.]*/);

    my $file_num = 1;

    my $out_file = sprintf "$out_dir/$base_file.%03d$suffix", $file_num;

    unless (open(OFH, ">$out_file")) {
        die("Error opening output search regions file $out_file - $!");
    }

    push @out_files, $out_file;

    my $line_count = 0;
    while (my $line = <IFH>) {
        if ($line_count > 0 && $line_count % ($num_lines) == 0) {
            close(OFH);

            $file_num++;
            $out_file = sprintf "$out_dir/$base_file.%03d$suffix", $file_num;

            unless (open(OFH, ">$out_file")) {
                die(
                    "Error opening output search regions file $out_file - $!"
                );
            }

            push @out_files, $out_file;

            $line_count = 0;
        }

        print OFH $line;

        $line_count++;
    }

    close(OFH);

    return @out_files ? \@out_files : undef;
}
