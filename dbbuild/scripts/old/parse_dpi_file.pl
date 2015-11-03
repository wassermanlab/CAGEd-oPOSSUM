#!/usr/bin/env perl

=head1 NAME

parse_dpi_file.pl

=head1 SYNOPSIS

  parse_dpi_file.pl -i dpi_file [-o out_prefix] [-l log_file]

=head1 ARGUMENTS

Arguments switches may be abbreviated where unique.

   -i dpi_file      = Name of input FANTOM5 TPM file.
   -o out_prefix    = Optional prefix for output files. Actually not a
                      prefix. If prefix is provided, ouput files will be
                      named <type>.<prefix>.txt, otherwise they will be
                      named <type>.txt where type corresponds to the table
                      name in the FANTOM5 database that the file is loaded
                      into, e.g.: 'experiment', 'tag' and 'tpm'.
   -l log_file      = Optional name of log file. If not specified then if
                      prefix is provided the log file will be named
                      parse_dpi_file.<prefix>.log, otherwise parse_dpi_file.log.

=head1 DESCRIPTION

Script to parse a FANTOM5 TPM file and create output text files for loading
into the FANTOM5 database. Several output files are created, one for each of
the experiment, tag and tpm tables of the FANTOM5 database. These files are
in tab delimeted format with each column corresponding to the columns of the
associated table in the DB. These files can then be loaded into the DB via the
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

use Getopt::Long;
use Pod::Usage;
use Log::Log4perl qw(get_logger :levels);

use constant DEBUG      => 0;

my $in_dpi_file;
my $log_file;
my $prefix;
my $out_experiment_file;
my $out_tag_file;
my $out_file;
GetOptions(
    'i=s'   => \$in_dpi_file,
    'o=s'   => \$prefix,
    'l=s'   => \$log_file
);

unless ($in_dpi_file) {
    pod2usage(
        -msg        => "No input TPM file specified",
        -verbose    => 1
    );
}

unless (-f $in_dpi_file) {
    die "Input TPM file $in_dpi_file does not exist!\n";
}

unless ($log_file) {
    $log_file = "parse_dpi_file";
}

$out_experiment_file = 'experiment';
$out_tag_file        = 'tag';
$out_file            = 'experiment_tag_scores';
if ($prefix) {
    $log_file            .= ".$prefix";
    $out_experiment_file .= ".$prefix";
    $out_tag_file        .= ".$prefix";
    $out_file            .= ".$prefix";
}

$log_file            .= '.log';
$out_experiment_file .= '.txt';
$out_tag_file        .= '.txt';
$out_file            .= '.txt';


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

$logger->info("Parsing TPM file $in_dpi_file started on $localtime\n");

parse_dpi_file();

$localtime = localtime();

$logger->info("Parsing TPM file $in_dpi_file finished on $localtime\n");

exit;

sub parse_dpi_file
{
    my $experiment_id = 1;
    my $tag_id = 1;
    my $num_experiments = 0;
    my %col_var;

    open(INFH, "$in_dpi_file")
        || $logger->logdie("Error opening input TPM file $in_dpi_file - $!");

    open(OEXP, ">$out_experiment_file")
        || $logger->logdie(
              "Error opening output experiment file $out_experiment_file - $!"
    );

    open(OTAG, ">$out_tag_file")
        || $logger->logdie("Error opening output tag file $out_tag_file - $!");

    open(OTPM, ">$out_file")
        || $logger->logdie("Error opening output TPM file $out_file - $!");

    while (my $line = <INFH>) {
        chomp($line);

        if ($line =~ /^##ColumnVariables\[(.*)\]=(.*)/) {
            my $exp_name = $2;

            #
            # XXX
            # Add code to strip other prefix strings related to tag count
            # files etc.
            #
            $exp_name =~ s/^TPM \(tags per million\) of //;

            $col_var{$1} = $exp_name;

            print OEXP "$experiment_id\t$exp_name\n";
            $experiment_id++;
            $num_experiments++;
        } elsif ($line =~ /^chr\w+:\d+\.\.\d+,./) {
            #
            # Done with experiment section here
            #
            close(OEXP);

            my @cols = split "\t", $line;

            my $pos_info = $cols[0];
            my $short_desc = $cols[1];
            my $long_desc = $cols[2];
            my $trans_assoc = $cols[3];
            my $entrez_info = $cols[4];
            my $uniprot_info = $cols[5];

            my $chrom;
            my $start;
            my $end;
            my $strand;
            if ($pos_info =~ /^chr(\w+):(\d+)\.\.(\d+),(.)/) {
                $chrom = $1;
                $start = $2;
                $end = $3;
                $strand = $4;
            } else {
                $logger->logdie("Error parsing position information");
            }

            my $trans_assoc_str = '';
            if (!$trans_assoc || $trans_assoc eq 'NA') {
                $trans_assoc = undef;
                $entrez_info = undef;
                $uniprot_info = undef;
            } else {
                $trans_assoc_str = $trans_assoc;

                #
                # Not sure, but I suppose even if there is transcript
                # association, one of the EntrezGene or UniProt ID
                # could still be missing for this transcript.
                #
                if (!$entrez_info || $entrez_info eq 'NA') {
                    $entrez_info = undef;
                }

                if (!$uniprot_info || $uniprot_info eq 'NA') {
                    $uniprot_info = undef;
                }
            }

            my $entrez_str = '';
            if ($entrez_info) {
                if ($entrez_info =~ /,/) {
                    my @entrezlist = split ',', $entrez_info;
                    my $first = 1;
                    foreach my $ent (@entrezlist) {
                        unless ($first) {
                            $entrez_str .= ',';
                        }
                        $first = 0;

                        if ($ent =~ /entrezgene:(\d+)/) {
                            $entrez_str .= $1;
                        }
                    }
                } else {
                    if ($entrez_info =~ /entrezgene:(\d+)/) {
                        $entrez_str = $1;
                    }
                }
            }

            my $uniprot_str = '';
            if ($uniprot_info) {
                if ($uniprot_info =~ /,/) {
                    my @uniprotlist = split ',', $uniprot_info;
                    my $first = 1;
                    foreach my $uni (@uniprotlist) {
                        unless ($first) {
                            $uniprot_str .= ',';
                        }
                        $first = 0;

                        if ($uni =~ /uniprot:(\w+)/) {
                            $uniprot_str .= $1;
                        }
                    }
                } else {
                    if ($uniprot_info =~ /uniprot:(\w+)/) {
                        $uniprot_str = $1;
                    }
                }
            }

            printf OTAG "%d\t%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n",
                $tag_id,
                $chrom,
                $start,
                $end,
                $strand,
                $entrez_str,
                $uniprot_str,
                $short_desc,
                $long_desc,
                $trans_assoc_str;

            #
            # Remaining columns are the TPM values for each experiment for
            # this tag.
            #
            foreach my $i (6..$#cols) {
                my $tpm = $cols[$i];

                if ($tpm) {
                    printf OTPM "%d\t%d\t%s\n", $tag_id, $i - 5, $tpm;
                }
            }

            $tag_id++;
        }
    }

    close(INFH);
    close(OTAG);
    close(OTPM);
}
