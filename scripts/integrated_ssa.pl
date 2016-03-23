#!/usr/bin/env perl5.14

=head1 NAME

experiment_ssa.pl

=head1 SYNOPSIS

  experiment_ssa.pl
      -species species
      -dir results_dir
      ([-ttssf FILE] | [-trf FILE] | (([-txids exp_ids] | [-txf FILE])
            (([-ttc tag_count] [-ttpm tpm]) | [-trex rel_expr])))
      [-tto]
      ([-tgids] | [-tgf FILE])
      [-tfrf FILE]
      ([-btssf FILE] | [-brf FILE] | (([-bxids exp_ids] | [-bxf FILE])
            (([-btc tag_count] [-btpm tpm]) | [-brex rel_expr])))
      [-bto]
      ([-bgids] | [-bgf FILE])
      [-bfrf FILE]
      [-brand]
      [-bfold fold]
      [-tfdb tf_database]
      [-tfmf FILE]
          | [-tff FILE]
          | [-tfids tf_ids]
          | ([-co collections] [-tax tax_groups] [-ic min_ic])
      [-hma]
      [-th threshold]
      [-up upstream_bp]
      [-dn downstream_bp]
      [-n num_results | -zcutoff cutoff -fcutoff cutoff]
      [-sr sort_by]
      [-details]
      [-plot]
      [-web]
      [-j job_id]
      [-m email]
      [-utxf FILE]
      [-ubxf FILE]
      [-utgf FILE]
      [-ubgf FILE]
      [-utfrf FILE]
      [-ubfrf FILE]
      [-uttssf FILE]
      [-ubtssf FILE]
      [-utrf FILE]
      [-ubrf FILE]

=head1 ARGUMENTS

Argument switches may be abbreviated where unique. Arguments enclosed by
brackets [] are optional.

Some switches can take multiple values. To specify multiple values either
use multiple instances of the switch or a single switch followed by a comma
separated string of values (or some combination thereof).
e.g: -tax vertebrates -tax "insects, nematodes"

    -species species
            The common species name for which the analysis is being
            performed, 'human' or 'mouse'.

    -dir directory
            Name of directory used for output results files. If the
            directory does not already exist it will be created.

    -txids exp_IDs
            List of target FANTOM5 experiment IDs.
            (e.g. FF:3560-170A1).

    -txf FILE
            Input file containing a list of target FANTOM5 experiment IDs
            with one ID per line.

    -ttc tag_count
            Minimum tag count of FANTOM5 CAGE peaks for given target
            experiments to use when searching for TFBSs.

    -ttpm tpm
            Minimum TPM (tags per million) of FANTOM5 CAGE peaks
            for given target experiments to use when searching for TFBSs.

    -trex rel_expr
            Minimum relative expression (Log10(Relative expression over
            median) of FANTOM5 CAGE peaks for given target
            experiments to use when searching for TFBSs.

    -ttssf FILE
            Input file containing a list of target FANTOM5 CAGE peak
            names.

    -trf FILE
            BED formatted file containing a list of target user defined
            CAGE tag regions.

    -tto
            Flag indicating that only FANTOM5 CAGE peaks which are
            flagged as TSSs should be included.

    -tgids gene_IDs
            List of target gene IDs on which to filter FANTOM5 CAGE tag
            clusters, i.e. only use FANTOM5 CAGE peaks  associated
            with the given genes. These should be specified with either
            EntrezGene or UniProt IDs.

    -tgf FILE
            File containing a list of gene IDs on which to filter target
            FANTOM5 CAGE peaks, i.e. only use CAGE peaks
            associated with the given genes. These should be specified as
            either EntrezGene or UniProt IDs.

    -tfrf FILE
            BED file containing list of regions on which to filter target
            FANTOM5 or user defined CAGE peaks, i.e. only the overlap
            between the CAGE peak regions and these filtering
            regions are searched for TFBSs.

    -bxids exp_IDs
            List of background FANTOM5 experiment IDs.
            (e.g. FF:3560-170A1).

    -bxf FILE
            Input file containing a list of background FANTOM5 experiment
            IDs with one ID per line. If this option is not provided,
            and no other option of specifying background CAGE peaks
            is provided either, ALL FANTOM5 experiments in the oPOSSUM
            database are used as background.

    -btc tag_count
            Minimum tag count of FANTOM5 CAGE peaks for given
            background experiments to use when searching for TFBSs.

    -btpm tpm
            Minimum TPM (tags per million) of FANTOM5 CAGE peaks for
            given background experiments to use when searching for TFBSs.

    -brex rel_expr
            Minimum relative expression (Log10(Relative expression over
            median) of FANTOM5 CAGE peaks for given background
            experiments to use when searching for TFBSs.

    -btssf FILE
            Input file containing a list of background FANTOM5 CAGE tag
            cluster names.

    -brf FILE
            BED formatted file containing a list of user defined background
            CAGE peak regions.

    -bto
            Flag indicating that only FANTOM5 CAGE peaks which are
            flagged as TSSs should be included.

    -bgids gene_IDs
            List of background gene IDs on which to filter background
            FANTOM5 CAGE peaks, i.e. only use CAGE peaks
            associated with the given genes. These should be specified
            as either EntrezGene or UniProt IDs.

    -bgf FILE
            File containing list of gene IDs on which to filter background
            FANTOM5 CAGE peaks, i.e. only use CAGE peaks
            associated with the given genes. These should be specified as
            either EntrezGene or UniProt IDs.

    -bfrf FILE
            BED file containing list of regions on which to filter
            background FANTOM5 or user defined CAGE peaks, i.e. only the
            overlap between the CAGE peaks regions and these
            filtering regions are searched for TFBSs.
    -brand
            Boolean indicating that the background should be randomly
            generated using HOMER. All FANTOM5 CAGE peak positions are
            stored in a BED file identified by the constant
            HOMER_HUMAN_CAGE_PEAK_FILE/HOMER_MOUSE_CAGE_PEAK_FILE.
            These CAGE peak regions are excluded from the randomly
            generated regions by HOMER.

    -bfold fold
            The fold size of random background CAGE peaks to use, i.e. the
            number of background CAGE peak sequences to use is the number
            of target CAGE peak sequences multiplied by fold.

    -tfdb db_name
            Specifies which TF database to use; default = JASPAR_2016.

    -tfmf FILE
            File containing one or more JASPAR TFBS profile matrices.
            If specified, it takes presedence over any of the
            -tff, -tfids, -co, -tax and -ic options below.

    -tff FILE
            File containing list of JASPAR TFBS profile matrix IDs with one
            ID per line. If specified, it takes presedence over any of the
            -tfids, -co, -tax and -ic options below.

    -tfids tf_IDs
            Specify one of more JASPAR TFBS profile matrix IDs to include
            use in the analysis. If this option is given it overrides any
            combination of the -co, -tax and -ic options below.

    -co collections
            Specify one or more JASPAR TFBS profile collections;
            default = CORE.

    -tax tax_groups
            Limit the analysis to use only JASPAR TFBS profile matrices
            which belong to one or more of these tax groups, e.g:
                -tax vertebrates -tax insects -tax nematodes
                -tax "vertebrates,insects,nematodes"

    -ic min_ic
            Specify minimum information content (specificity) of JASPAR
            TFBS profile matrices to use.

    -hma
            If specified, also run HOMER motif analysis. HOMER is used to
            find overrepresented TFBS using the default HOMER motif set.

    -th threshold
            Minimum relative TFBS position weight matrix (PWM) score to
            report in the analysis. The thresold may be spesified as a
            percentage string, e.g. '85%', or as a decimal number, e.g.
            0.85
            Default = '80%' (min. = '75%')

    -n num_results
            The number of results to output. Numeric or string 'All'.
            Default = 'All'

    -zcutoff score
            Z-score cutoff of results to display. Only output results with
            at least this Z-score.

    -fcutoff score
            Fisher score cutoff of results to display. Only output results
            with at least this Fisher score.

    -details
            If specified, in addition to the main results ranking of TFBS
            over-representation, files detailing the target region binding
            site positions are written for each of the input TFs (one file
            per TF).

    -plot
            If specified, create PNG plot files of Z/Fisher scores vs.
            TF matrix %GC content.

    -sr sort_by
            Sort results by this score ('zscore', 'fisher'), highest to
            lowest.
            Default = 'zscore'.

    -help, -h, -?
            Help. Print usage message and exit.

=head2 Web Server Specific Options

    The following options are passed to the script by web-based
    CAGEd-oPOSSUM. These are not required when running the scripts
    directly on the command line and can generally be ignored.

    -web
            Web server switch. Indicates that the script caller is the web
            server, and HTML results files should also be created.

    -j, -job_id job_ID
            The oPOSSUM job ID.

    -m email
            E-mail address of user. An e-mail is sent to the user to notify
            him/her when the analysis has completed with a URL to the
            HTML results page.

    -utxf FILE
            Original name of the user supplied target experiment file for
            informational display purposes only.

    -ubxf FILE
            Original name of the user supplied background experiment file
            for informational display purposes only.

    -utgf FILE
            Original name of the user supplied target gene IDs file for
            informational display purposes only.

    -ubgf FILE
            Original name of the user supplied background gene IDs file
            for informational display purposes only.

    -utfrf FILE
            Original name of the user supplied target filtering regions
            file for informational display purposes only.

    -ubfrf FILE
            Original name of the user supplied background filtering regions
            file for informational display purposes only.

    -uttssf FILE
            Original name of the user supplied target FANTOM5 CAGE tag
            cluster names file for informational display purposes only.

    -ubtssf FILE
            Original name of the user supplied background FANTOM5 CAGE tag
            cluster names file for informational display purposes only.

    -utrf FILE
            Original name of the user supplied user defined target CAGE tag
            cluster regions file for informational display purposes only.

    -ubrf FILE
            Original name of the user supplied user defined background CAGE
            peak regions file for informational display purposes only.

=head1 DESCRIPTION

Take one or more target experiment IDs, optional background experiment IDs
and optional subset of transcription factors (TFs) either specified in an
input file, or limited by external (JASPAR) database name and information
content or taxonomic supergroup or all TFs in the CAGEd-oPOSSUM database.
Also optionally specify PWM score threshold.

Count the number of TFBSs for each TF which was found at the given
PWM score threshold for both the test and background. Perform Fisher exact
test and z-score analysis and output these results to the output file.
Optionally write details of TFBSs found in test set to detailed TFBS hits
file.

=head1 AUTHOR

David Arenillas
Wasserman Lab
Centre for Molecular Medicine and Therapeutics
University of British Columbia

E-mail: dave@cmmt.ubc.ca

=cut

use strict;

use warnings;

use lib '/apps/CAGEd_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Carp;
use Array::Utils qw(:all);   # for debugging only
use File::Spec::Functions qw(abs2rel catdir catfile splitpath file_name_is_absolute);
use File::Path qw(remove_tree);
use POSIX qw/ floor /;

use Log::Log4perl qw(get_logger :levels);

#use Bio::SeqIO;

#use TFBS::DB::JASPAR5;

use OPOSSUM::Include::ExperimentInclude;
use OPOSSUM::DBSQL::DBAdaptor;
use OPOSSUM::SearchRegion;
use OPOSSUM::SearchRegionSet;
use OPOSSUM::TFSet;
use OPOSSUM::Analysis::Counts;
use OPOSSUM::Analysis::Zscore;
use OPOSSUM::Analysis::Fisher;
use OPOSSUM::Analysis::CombinedResultSet;
use OPOSSUM::Plot::ScoreVsGC;
use OPOSSUM::Tools::SearchRegionTool;
#use OPOSSUM::Tools::BiasAway;
use OPOSSUM::Tools::Homer;
#use Statistics::Distributions;

#
# Not used any more. We are fetching sequences using BEDTools now.
# DJA 2015/04/24
#
#use lib ENSEMBL_LIB_PATH;
#
#use Bio::EnsEMBL::DBSQL::DBAdaptor;
#

use constant BG_COLOR_CLASS => 'bgc_f5_exp';

my $path = $ENV{'PATH'};
$path .= ':' . HOMER_BIN_PATH;
$ENV{'PATH'} = $path;

my $help;
my $job_id;
my $results_dir;
my $web;
my $species;
my @t_exp_ids;
my $t_exp_ids_file;
my $t_tss_names_file;
my $t_tss_regions_file;
my @b_exp_ids;
my $b_exp_ids_file;
my $b_tss_names_file;
my $b_tss_regions_file;
my $t_tss_only;
my @t_gene_ids;
my $t_gene_ids_file;
my $t_filter_regions_file;
my $b_tss_only;
my @b_gene_ids;
my $b_gene_ids_file;
my $b_filter_regions_file;
my $t_tag_count;
my $t_tpm;
my $t_rel_expr;
my $b_tag_count;
my $b_tpm;
my $b_rel_expr;
my $b_is_rand;
my $b_fold;
my $tf_db;
my @tf_ids;
my $tf_matrix_file;
my $tf_ids_file;
my @collections;
my @tax_groups;
my $min_ic;
my $hma;
my $threshold;
my $upstream_bp;
my $downstream_bp;
my $num_results;
my $zscore_cutoff;
my $fisher_cutoff;
my $sort_by;
my $write_details;
my $plot;
my $email;
my $user_t_exp_ids_file;
my $user_b_exp_ids_file;
my $user_t_gene_ids_file;
my $user_b_gene_ids_file;
my $user_t_filter_regions_file;
my $user_b_filter_regions_file;
my $user_t_tss_names_file;
my $user_b_tss_names_file;
my $user_t_tss_regions_file;
my $user_b_tss_regions_file;
GetOptions(
    'species|s=s'   => \$species,
    'dir|d=s'       => \$results_dir,
    'txids=s'       => \@t_exp_ids,
    'txf=s'         => \$t_exp_ids_file,
    'ttssf=s'       => \$t_tss_names_file,
    'trf=s'         => \$t_tss_regions_file,
    'tto'           => \$t_tss_only,
    'bxids=s'       => \@b_exp_ids,
    'bxf|b=s'       => \$b_exp_ids_file,
    'btssf=s'       => \$b_tss_names_file,
    'brf=s'         => \$b_tss_regions_file,
    'bto'           => \$b_tss_only,
    'tgids=s'       => \@t_gene_ids,
    'tgf=s'         => \$t_gene_ids_file,
    'tfrf=s'        => \$t_filter_regions_file,
    'bgids=s'       => \@b_gene_ids,
    'bgf=s'         => \$b_gene_ids_file,
    'bfrf=s'        => \$b_filter_regions_file,
    'brand'         => \$b_is_rand,
    'bfold=i'       => \$b_fold,
    'ttc=i'         => \$t_tag_count,
    'ttpm=f'        => \$t_tpm,
    'trex=f'        => \$t_rel_expr,
    'btc=i'         => \$b_tag_count,
    'btpm=f'        => \$b_tpm,
    'brex=f'        => \$b_rel_expr,
    'tfdb|db=s'     => \$tf_db,
    'tfids|ids=s'   => \@tf_ids,
    'tfmf=s'        => \$tf_matrix_file,
    'tff=s'         => \$tf_ids_file,
    'co=s'          => \@collections,
    'tax=s'         => \@tax_groups,
    'ic=s'          => \$min_ic,
    'hma'           => \$hma,
    'th=s'          => \$threshold,
    'up=i'          => \$upstream_bp,
    'dn=i'          => \$downstream_bp,
    'n=s'           => \$num_results,   # integer or string 'All'
    'zcutoff=f'     => \$zscore_cutoff,
    'fcutoff=f'     => \$fisher_cutoff,
    'sr=s'          => \$sort_by,
    'details'       => \$write_details,
    'plot'          => \$plot,
    'web'           => \$web,
    'job_id|j=s'    => \$job_id,
    'm=s'           => \$email,
    'utxf=s'        => \$user_t_exp_ids_file,
    'ubxf=s'        => \$user_b_exp_ids_file,
    'utgf=s'        => \$user_t_gene_ids_file,
    'ubgf=s'        => \$user_b_gene_ids_file,
    'utfrf=s'       => \$user_t_filter_regions_file,
    'ubfrf=s'       => \$user_b_filter_regions_file,
    'uttssf=s'      => \$user_t_tss_names_file,
    'ubtssf=s'      => \$user_b_tss_names_file,
    'utrf=s'        => \$user_t_tss_regions_file,
    'ubrf=s'        => \$user_b_tss_regions_file,
    'help|h|?'      => \$help
);

if ($help) {
    pod2usage(-verbose => 1);
}

my %job_args = (
    -bg_color_class => BG_COLOR_CLASS
);

#
# Check/parse the rest of the program arguments
#
parse_args();

my $rel_results_dir = make_relative_results_path($results_dir);

unless ($web) {
    make_results_dir($results_dir);
}

$job_args{-results_dir}     = $results_dir;
$job_args{-rel_results_dir} = $rel_results_dir;

my $logger = init_logging();

$logger->info("Starting analysis");

#
# Connect to CAGEd-oPOSSUM DB and get the necessary adaptors
#
my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);

my $opdba = opossum_db_connect($species)
    || fatal("Could not connect to CAGEd-oPOSSUM database $db_name",
        \%job_args);

my $dbia = $opdba->get_DBInfoAdaptor
    || fatal("Could not get DBInfoAdaptor", \%job_args);

my $expa = $opdba->get_ExperimentAdaptor
    || fatal("Could not get ExperimentAdaptor", \%job_args);

my $tssa = $opdba->get_TSSAdaptor
    || fatal("Could not get TSSAdaptor", \%job_args);

my $expra = $opdba->get_ExpressionAdaptor
    || fatal("Could not get ExpressionAdaptor", \%job_args);

my $sra = $opdba->get_SearchRegionAdaptor
    || fatal("Could not get SearchRegionAdaptor", \%job_args);
    
my $tfbsa = $opdba->get_TFBSAdaptor
    || fatal("Could not get TFBSAdaptor", \%job_args);

my $db_info = $dbia->fetch_db_info();
unless ($db_info) {
    fatal("Could not fetch CAGEd-oPOSSUM DB info", \%job_args);
}

#
# Not used any more. We are fetching sequences using BEDTools now.
# DJA 2015/04/24
#
#my $ens_db_name = $db_info->ensembl_db;
#
# Connect to ENSEMBL database.
#
#my $ensdba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#    -host    => ENSEMBL_DB_HOST,
#    -user    => ENSEMBL_DB_USER,
#    -pass    => ENSEMBL_DB_PASS,
#    -dbname  => $ens_db_name,
#    -species => $species,
#    -driver  => 'mysql'
#);
#
#unless ($ensdba) {
#    fatal("Could not connect to Ensembl DB $ens_db_name", \%job_args);
#}
#
#my $slice_adaptor = $ensdba->get_SliceAdaptor();
#unless ($slice_adaptor) {
#    fatal("Could not get Ensembl SliceAdaptor", \%job_args);
#}

my $t_tss_type = $job_args{-t_tss_type};
if ($t_tss_type eq 'fantom5') {
    #
    # Get optional gene IDs on which to filter target CAGE peaks. We need these
    # BEFORE we retrieve CAGE peaks below.
    #
    if ($t_gene_ids_file && !@t_gene_ids) {
        #
        # Read gene IDs from file.
        #
        $logger->info("Reading target gene IDs from file $t_gene_ids_file");

        my $gene_ids = read_gene_ids_from_file($t_gene_ids_file, \%job_args);

        unless ($gene_ids) {
            fatal(
                "No target filtering gene IDs read from file $t_gene_ids_file",
                \%job_args
            );
        }

        $logger->info(
            sprintf(
                "Read %d target filtering gene IDs from file $t_gene_ids_file",
                scalar @$gene_ids
            )
        );

        @t_gene_ids = @$gene_ids;
    }
}

#
# Get target CAGE peaks specified directly by a file containing user defined
# CAGE peak regions, a file containing FANTOM5 CAGE peak IDs
# or indirectly by experiments with some threshold on the tag counts and/or TPM.
#
# Experiments are specified by their IDs which may be either internal oPOSSUM
# DB IDs or FANTOM5 (FF) IDs and may be provided directly on the command line
# or via an input file.
#
# The CAGE peaks may also be optionally filtered by whether they are
# indicated to be TSSs and/or whether they are associated to specific
# gene/proteins IDs.
#
$logger->info("Fetching target CAGE peaks");
my $t_tss;
my $t_experiments;
if ($t_tss_regions_file) {
    #
    # Read user defined target CAGE peak regions from the specified file
    #
    $logger->info(
        "Reading user defined target CAGE peaks from file"
        . " $t_tss_regions_file"
    );

    $t_tss = read_tss_regions_from_file($t_tss_regions_file, \%job_args);

    unless ($t_tss) {
        fatal("Error reading user defined target CAGE peaks."
            . " Please make sure that at least the first 6 columns"
            . " (chromosome, start, end, name, score and strand)"
            . " are defined. Note the score is not used and can be set to"
            . " some dummy value, e.g. 0.",
            \%job_args
        );
    }
} elsif ($t_tss_names_file) {
    #
    # Read FANTOM5 target CAGE peak names from the specified file
    #
    $logger->info(
        "Reading target CAGE peak names from file" . " $t_tss_names_file"
    );

    $t_tss = fetch_tss_by_names_file(
        $tssa, 'target', $t_tss_names_file, $t_tss_only, \@t_gene_ids,
        \%job_args
    );

    unless ($t_tss) {
        fatal(
            "Error reading target FANTOM5 CAGE peak names file.",
            \%job_args
        );
    }
} else {
    $logger->info(
        "Fetching target FANTOM5 CAGE peaks via experimental criteria"
    );

    $logger->info("Fetching target FANTOM5 experiments");
    $t_experiments = get_experiments(
        $expa, 'target', \@t_exp_ids, $t_exp_ids_file, \%job_args
    );

    $logger->info("Fetching target FANTOM5 CAGE peaks");
    $t_tss = fetch_tss_by_experimental_criteria(
        $tssa, 'target', $t_experiments, $t_tag_count, $t_tpm, $t_rel_expr,
        $t_tss_only, \@t_gene_ids, \%job_args
    );

    unless ($t_tss) {
        fatal(
            "Error fetching target FANTOM5 CAGE peaks based on"
            . " specified experimental criteria.", \%job_args
        );
    }
}

$job_args{-t_experiments} = $t_experiments if $t_experiments;
$job_args{-t_tss} = $t_tss if $t_tss;

my $num_t_tss = scalar @$t_tss;
$logger->info("Number of target CAGE peaks: $num_t_tss");

$logger->info("Computing target CAGE peak search regions");

my $t_srt = OPOSSUM::Tools::SearchRegionTool->new(
    -species    => $species,
    -t_or_b     => 'target',
    -dir        => $results_dir
);

unless ($t_srt) {
    fatal("Error initializing target search region tool", \%job_args);
}

my $t_search_regions_file = catfile($results_dir, 't_search_regions.bed');
my $ok = $t_srt->compute_tss_search_regions(
    -tss                        => $t_tss,
    -upstream_bp                => $upstream_bp,
    -downstream_bp              => $downstream_bp,
    -intersecting_regions_file  => $t_filter_regions_file,
    -out_regions_file           => $t_search_regions_file
);

unless ($ok) {
    fatal("Error computing target CAGE peak search regions", \%job_args);
}

# For debugging
#write_search_regions($t_search_regions, "$results_dir/t_search_regions.txt");

my $t_search_regions = $t_srt->read_bed(-filename => $t_search_regions_file);

$job_args{-t_search_regions} = $t_search_regions;

my $num_t_search_regions = scalar @$t_search_regions;
$logger->info("Number of target search regions: $num_t_search_regions");

# XXX only applicable to FANTOM5 data
#my @t_sr_ids = map {$_->id} @$t_search_regions;

$logger->info("Computing total target search region length");
my $t_seq_length = compute_search_region_length($t_search_regions);

unless ($t_seq_length) {
    fatal("Error computing total target search region length", \%job_args);
}

$logger->info("Total target search region length: $t_seq_length");

my $b_tss_type = $job_args{-b_tss_type};
if ($b_tss_type eq 'fantom5') {
    #
    # Get optional gene IDs on which to filter background TSSs. We need these
    # BEFORE we retrieve CAGE peaks below.
    #
    if ($b_gene_ids_file && !@b_gene_ids) {
        #
        # Read gene IDs from file.
        #
        $logger->info("Reading background gene IDs from file $b_gene_ids_file");

        my $gene_ids = read_gene_ids_from_file($b_gene_ids_file, \%job_args);

        unless ($gene_ids) {
            fatal(
                "No background filtering gene IDs read from file"
                . " $b_gene_ids_file", \%job_args
            );
        }

        $logger->info(
            sprintf(
                "Read %d background filtering gene IDs from file"
                . " $b_gene_ids_file", scalar @$gene_ids
            )
        );

        @b_gene_ids = @$gene_ids;
    }
}

#
# Get background CAGE peaks specified directly by a file containing
# user defined CAGE peak regions, a file containing FANTOM5 CAGE peak
# IDs or indirectly by experiments with some threshold on the tag counts and/or
# TPM.
#
# Experiments are specified by their IDs which may be either internal oPOSSUM
# DB IDs or FANTOM5 (FF) IDs and may be provided directly on the command line
# or via an input file.
#
# The CAGE peaks may also be optionally filtered by whether they are
# indicated to be TSSs and/or  whether they are associated to specific
# gene/proteins IDs.
#
my $b_tss;
my $b_experiments;
if ($b_tss_regions_file) {
    #
    # Read user defined background CAGE peak regions from the specified file
    #
    $logger->info(
        "Reading user defined background CAGE peaks from file"
        . " $b_tss_regions_file"
    );

    $b_tss = read_tss_regions_from_file($b_tss_regions_file, \%job_args);

    unless ($b_tss) {
        fatal("Error reading user defined background CAGE peaks."
            . " Please make sure that at least the first 6 columns"
            . " (chromosome, start, end, name, score and strand)"
            . " are defined. Note the score is not used and can be set to"
            . " some dummy value, e.g. 0.",
            \%job_args
        );
    }
} elsif ($b_tss_names_file) {
    #
    # Read FANTOM5 background CAGE peak names from the specified file
    #
    $logger->info(
        "Fetching background CAGE peaks specified by name in"
        . " $b_tss_names_file"
    );

    $b_tss = fetch_tss_by_names_file(
        $tssa, 'background', $b_tss_names_file, $b_tss_only, \@b_gene_ids,
        \%job_args
    );

    unless ($b_tss) {
        fatal(
            "Error reading background FANTOM5 CAGE peak names file.",
            \%job_args
        );
    }
} elsif ($b_is_rand) {
    #
    # Fetch FANTOM5 background CAGE peaks used to generate random background
    #
    #my @t_tss_ids = map($_->id, @$t_tss);

    #
    # If the target CAGE peaks are user defined then initially use ALL CAGE
    # peaks to seed construction of the random background. Otherwise use all
    # CAGE peaks EXCEPT those in the target set to seed construction of the
    # random background.
    #
    #if ($t_tss_type eq 'custom') {
    #    $logger->info("Fetching ALL background CAGE peaks");
    #    $b_tss = $tssa->fetch();
    #} else {
    #    $logger->info("Fetching all background CAGE peaks which are NOT part of"
    #        . " the target set");

    #    $b_tss = $tssa->fetch_random(
    #        -excluded_tss_ids   => \@t_tss_ids,
    #        #-num_tss            => $num_t_tss * RAND_BG_TSS_FOLD
    #    );
    #}
} else {
    $b_experiments = get_experiments(
        $expa, 'background', \@b_exp_ids, $b_exp_ids_file, \%job_args
    );

    $b_tss = fetch_tss_by_experimental_criteria(
        $tssa, 'background', $b_experiments, $b_tag_count, $b_tpm, $b_rel_expr,
        $b_tss_only, \@b_gene_ids, \%job_args
    );

    unless ($b_tss) {
        fatal(
            "Error fetching background FANTOM5 CAGE peaks based on"
            . " specified experimental criteria.", \%job_args
        );
    }
}

$job_args{-b_experiments} = $b_experiments if $b_experiments;

#
# Don't set this if we are just using the background CAGE peaks to seed
# the random set.
#
$job_args{-b_tss} = $b_tss if $b_tss && !$b_is_rand;

my $b_srt = OPOSSUM::Tools::SearchRegionTool->new(
    -species    => $species,
    -t_or_b     => 'background',
    -dir        => $results_dir
);

unless ($b_srt) {
    fatal("Error initializing background search region tool", \%job_args);
}

my $tf_set = get_tfbs_matrix_set(\%job_args);

my $tf_ids   = $tf_set->ids();
my $tf_names = $tf_set->names();

#
# We use HOMER both to generate random backgrounds and to perform motif
# overrepresentation analysis. So initilize it here if either of these
# options is set.
#
my $homer;
my $assembly;
if ($b_is_rand || $hma) {
    $logger->info("Initializing HOMER");

    $homer = OPOSSUM::Tools::Homer->new(
        -debug  => 1,
        -logger => $logger
    );

    unless ($homer) {
        fatal("Error initializing HOMER", %job_args);
    }

    if ($species eq 'human') {
        $assembly = HUMAN_ASSEMBLY;
    } elsif ($species eq 'mouse') {
        $assembly = MOUSE_ASSEMBLY;
    }
}

#
# We may need these in the future so declare here.
#
my $t_seq_file = catfile($results_dir, 't_search_sequences.fa');
my $homer_preparsed_dir = catdir($results_dir, HOMER_PREPARSED_SUBDIR);
my $homer_output_dir = catdir($results_dir, HOMER_OUTPUT_SUBDIR);
my $homer_results_dir = $homer_output_dir;

my $b_seq_file;
my $b_seq_length;
my $b_search_regions;
my $b_search_regions_file;
my $num_b_search_regions;
if ($b_is_rand) {
    $logger->info(
        "Computing random background with HOMER"
    );

    my $peak_file;
    if ($species eq 'human') {
        $peak_file = HOMER_HUMAN_CAGE_PEAK_FILE;
    } elsif ($species eq 'mouse') {
        $peak_file = HOMER_MOUSE_CAGE_PEAK_FILE;
    }

    my ($min_t_region_len,
        $max_t_region_len,
        $mean_t_region_len) = get_region_length_stats($t_search_regions);

    $logger->info("Running HOMER preparse genome");
    $homer->preparse_genome(
        -assembly               => $assembly,
        # XXX do we use min, max over mean here?
        -size                   => $mean_t_region_len,
        -reference_file         => $peak_file,
        -preparsed_dir          => $homer_preparsed_dir
    );
    $logger->info("Finished running HOMER preparse genome");

    #
    # We also want to use HOMER to find motifs
    #
    $logger->info("Running HOMER find motifs genome");

    if ($hma) {
        #
        # If doing HOMER motif analysis with the chosen set of JASPAR motifs.
        #
        #my $homer_matrices_file = catfile(
        #    $results_dir, 'homer_jaspar_matrices.txt'
        #);

        my $homer_results_text_file = catfile(
            $homer_results_dir, HOMER_KNOWN_MOTIF_RESULTS_TEXT_FILE
        );

        my $homer_results_html_file = catfile(
            $homer_results_dir, HOMER_KNOWN_MOTIF_RESULTS_HTML_FILE
        );

        $job_args{-homer_results_text_file} = $homer_results_text_file;
        $job_args{-homer_results_html_file} = $homer_results_html_file;

        #
        # If doing HOMER motif analysis with the chosen set of JASPAR motifs.
        #
        #$homer->print_matrix_set($homer_matrices_file, $tf_set, $threshold);

        #
        # Creating background AND doing motif analysis.
        #
        $homer->find_motifs_genome(
            -target_regions_file    => $t_search_regions_file,
            -assembly               => $assembly,
            -size                   => 'given',
            -nlen                   => 2,
            -N                      => $num_t_search_regions,
            -cpg                    => 1,
            -chopify                => 1,
            -dumpfasta              => 1,
            -nomotif                => 1,
            -preparsed_dir          => $homer_preparsed_dir,
            -output_dir             => $homer_output_dir,
            #
            # If doing HOMER motif analysis with the chosen set of JASPAR
            # motifs.
            #
            #-motif_file             => $homer_matrices_file
            -motif_file             => HOMER_VERTEBRATES_KNOWN_MOTIFS_FILE
        );

        post_process_homer_results_html($homer_results_html_file);

        $logger->info("Finished running HOMER random background generation"
            . " and motif finding");
    } else {
        #
        # Just creating background. Not doing motif analysis.
        #
        $homer->find_motifs_genome(
            -target_regions_file    => $t_search_regions_file,
            -assembly               => $assembly,
            -size                   => 'given',
            -nlen                   => 2,
            -N                      => $num_t_search_regions,
            -cpg                    => 1,
            -chopify                => 1,
            -dumpfasta              => 1,
            -nomotif                => 1,
            -preparsed_dir          => $homer_preparsed_dir,
            -output_dir             => $homer_output_dir
        );

        $logger->info("Finished running HOMER random background generation");
    }

    #
    # HOMER creates a background.fa file in the output directory
    #
    $b_seq_file = catfile($homer_output_dir, 'background.fa');

    my $b_seqs = read_sequences($b_seq_file);

    $num_b_search_regions = scalar @$b_seqs;

    $b_seq_length = compute_total_sequences_length($b_seqs);

    unless ($b_seq_length) {
        fatal("Error computing total background search region length",
              \%job_args);
    }

    #
    # XXX
    # Is there a way (as with the BiasAway version) to retrieve regions
    # corresponding to the background sequences so we can fetch TFBS from
    # the DB rather than scan the sequences?
    # XXX
    #
} else {
    $logger->info("Computing background CAGE peak search regions");

    $b_search_regions_file = catfile($results_dir, 'b_search_regions.bed');

    $ok = $b_srt->compute_tss_search_regions(
        -tss                        => $b_tss,
        -upstream_bp                => $upstream_bp,
        -downstream_bp              => $downstream_bp,
        -intersecting_regions_file  => $b_filter_regions_file,
        -out_regions_file           => $b_search_regions_file
    );

    unless ($ok) {
        fatal("Error computing background CAGE peak regions", \%job_args);
    }

    $b_search_regions = $b_srt->read_bed(
        -filename => $b_search_regions_file
    );

    unless ($b_search_regions) {
        fatal("Error computing background CAGE peak search regions",
            \%job_args);
    }

    #write_search_regions($b_search_regions,
    #   "$results_dir/b_search_regions.txt");

    $job_args{-b_search_regions} = $b_search_regions;

    $num_b_search_regions = scalar @$b_search_regions;

    # XXX only applicable to FANTOM5 data
    #my @b_sr_ids = map {$_->id} @$b_search_regions;

    $logger->info("Computing total background search region length");
    $b_seq_length = compute_search_region_length($b_search_regions);

    unless ($b_seq_length) {
        fatal("Error computing total background search region length",
              \%job_args);
    }
}

$logger->info("Number of background search regions: $num_b_search_regions");
$logger->info("Total background search region length: $b_seq_length");

#
# If we also want to use HOMER to find motifs and we haven't already done it
# (if b_is_rand is true, then we already did motif finding in the same step
# which generated random background sequences).
#
if ($hma && !$b_is_rand) {
    $logger->info("Running HOMER find motifs genome");

    #
    # If doing HOMER motif analysis with the chosen set of JASPAR motifs.
    #
    #my $homer_matrices_file = catfile(
    #    $results_dir, 'homer_jaspar_matrices.txt'
    #);

    my $homer_results_text_file = catfile(
        $homer_results_dir, HOMER_KNOWN_MOTIF_RESULTS_TEXT_FILE
    );

    my $homer_results_html_file = catfile(
        $homer_results_dir, HOMER_KNOWN_MOTIF_RESULTS_HTML_FILE
    );

    $job_args{-homer_results_text_file} = $homer_results_text_file;
    $job_args{-homer_results_html_file} = $homer_results_html_file;

    #$homer->print_matrix_set($homer_matrices_file, $tf_set, $threshold);

    #
    # Just doing motif analysis. Background was created earlier using
    # explicit background CAGE peak data.
    #
    $homer->find_motifs_genome(
        -target_regions_file        => $t_search_regions_file,
        -background_regions_file    => $b_search_regions_file,
        #-motif_file                 => $homer_matrices_file,
        -motif_file                 => HOMER_VERTEBRATES_KNOWN_MOTIFS_FILE,
        -assembly                   => $assembly,
        #-chopify                    => 1,
        -size                       => 'given',
        #-nlen                       => 2,
        #-N                          => $num_t_search_regions,
        #-preparsed_dir              => $homer_preparsed_dir,
        -nomotif                    => 1,
        -output_dir                 => $homer_results_dir
    );

    post_process_homer_results_html($homer_results_html_file);

    $logger->info("Finished running HOMER motif finding");
}

#
# Compute target and backround counts
#
my $tf_type = $job_args{-tf_type};
my $t_counts;
if ($t_tss_type eq 'custom' || $tf_type eq 'custom') {
    #
    # Fetch target search region sequences
    #
    $logger->info("Fetching target search region sequences");

    #
    # We may have already created the target sequences file for BiasAway.
    # In which case we do not need to create it again.
    #
    unless (-f $t_seq_file) {
        $ok = $t_srt->extract_search_region_sequences(
            -regions_file   => $t_search_regions_file,
            -out_seq_file   => $t_seq_file
        );

        unless ($ok) {
            fatal("Error extracting sequences from target search regions file",
                \%job_args);
        }
    }

    my $t_seqs = read_sequences($t_seq_file, \%job_args);

    unless ($t_seqs) {
        fatal("Error fetching target search region sequences", \%job_args);
    }

    #
    # Search target sequences with the matrix set.
    #
    $logger->info("Searching target sequences for TFBSs and computing counts");

    $t_counts = search_seqs_and_compute_tfbs_counts(
        $tf_set, $t_seqs, $threshold, $write_details, \%job_args
    );

    unless ($t_counts) {
        fatal(
            "Error scanning target CAGE peak regions for TFBSs",
            \%job_args
        );
    }
} else {
    #
    # To speed up fetching of TFBSs, get the search region IDs of the
    # pre-computed search regions which contain these TSSs. These search
    # regions were computed with the maximum possible flank and with all
    # possible TSSs. Since the actual flank size and / or TSSs used will be
    # less than those used for the pre-computed search regions, we still need
    # to compute the actual search regions for the combination of these TSSs
    # with this flank size and filter the TFBSs which fall into these actual
    # search regions.
    #
    #my %t_pc_sr_ids_hash = map {$_->parent_id => 1} @$t_search_regions;
    #my @t_pc_sr_ids = keys %t_pc_sr_ids_hash2;

    #$logger->info("Fetching target pre-computed search regions");
    #my $t_pc_search_regions = $sra->fetch(-ids => \@t_pc_sr_ids);
    #unless ($t_pc_search_regions) {
    #    fatal("Error fetching target pre-computed search regions", \%job_args);
    #}

    $logger->info(
        "Creating target search region to parent search region map"
    );

    my $t_search_region_map = create_search_region_map($t_search_regions);

    #
    # Debugging
    #
    #my @x = keys %$t_search_region_map;
    #my @diff = array_diff(@t_pc_sr_ids, @x);
    #if (@diff && $diff[0]) {
    #    $logger->info(sprintf(
    #        "t_search_region_map keys and t_pc_sr_ids differ\n%s\n",
    #        join(", ", @diff)
    #    ));
    #}

    if ($write_details) {
        $logger->info("Fetching target TFBS counts and detail data");

        $t_counts = $tfbsa->fetch_tfbs_counts(
            -tf_set             => $tf_set,
            -threshold          => $threshold,
            #-search_region_ids  => \@t_pc_sr_ids,
            -search_region_map  => $t_search_region_map,
            -results_dir        => $results_dir,
            #-logger             => $logger
        );
    } else {
        $logger->info("Fetching target TFBS counts");

        $t_counts = $tfbsa->fetch_tfbs_counts(
            -tf_set             => $tf_set,
            -threshold          => $threshold,
            #-search_region_ids  => \@t_pc_sr_ids,
            -search_region_map  => $t_search_region_map,
            #-logger             => $logger
        );
    }

    unless ($t_counts) {
        fatal("Error retrieving target CAGE peak region TFBSs", \%job_args);
    }
}

my $b_counts;
if ($b_tss_type eq 'custom' || $tf_type eq 'custom') {
    #
    # Fetch background search region sequences
    #
    $logger->info("Fetching background search region sequences");

    #my $b_seqs = fetch_search_region_sequences(
    #    $b_search_regions, $slice_adaptor, \%job_args
    #);

    #
    # We may have already created the background sequences file with HOMER.
    # In which case we do not need to create it again.
    #
    unless (-f $b_seq_file) {
        $ok = $b_srt->extract_search_region_sequences(
            -regions_file   => $b_search_regions_file,
            -out_seq_file   => $b_seq_file
        );

        unless ($ok) {
            fatal("Error extracting sequences from background search regions"
                . " file", \%job_args);
        }
    }

    my $b_seqs = read_sequences($b_seq_file, \%job_args);

    unless ($b_seqs) {
        fatal("Error fetching background search region sequences", \%job_args);
    }

    #
    # Search background sequences with the matrix set.
    #
    $logger->info(
        "Searching background sequences for TFBSs and computing counts
    ");

    $b_counts = search_seqs_and_compute_tfbs_counts(
        $tf_set, $b_seqs, $threshold, 0, \%job_args
    );

    unless ($b_counts) {
        fatal(
            "Error scanning background CAGE peak regions for TFBSs",
            \%job_args
        );
    }
} else {
    #my %b_pc_sr_ids_hash = map {$_->search_region_id => 1} @$b_tss;
    #my @b_pc_sr_ids = keys %b_pc_sr_ids_hash;

    #$logger->info("Fetching background pre-computed search regions");
    #my $b_pc_search_regions = $sra->fetch(-ids => \@b_pc_sr_ids);
    #unless ($b_pc_search_regions) {
    #    fatal(
    #        "Error fetching background pre-computed search regions",
    #        \%job_args
    #    );
    #}

    $logger->info(
        "Creating background search region to parent search region map"
    );

    my $b_search_region_map = create_search_region_map($b_search_regions);

    $logger->info("Fetching background TFBS counts");
    $b_counts = $tfbsa->fetch_tfbs_counts(
        -tf_set             => $tf_set,
        -threshold          => $threshold,
        #-search_region_ids  => \@b_pc_sr_ids,
        -search_region_map  => $b_search_region_map,
        #-logger             => $logger
    );

    unless ($b_counts) {
        fatal("Error retrieving background search region TFBSs", \%job_args);
    }
}

my $fisher = OPOSSUM::Analysis::Fisher->new();
fatal("Error initializing Fisher analysis", \%job_args)
    unless $fisher;

$logger->info("Computing Fisher scores");
my $fresult_set = $fisher->calculate_Fisher_probability(
    $b_counts,
    $t_counts
);

fatal("Error performing Fisher analysis", \%job_args) unless $fresult_set;

my $zscore = OPOSSUM::Analysis::Zscore->new();

fatal("Error initializing z-score analysis", \%job_args) unless $zscore;

$logger->info("Computing Z-scores");
my $zresult_set = $zscore->calculate_Zscore(
    $b_counts,
    $t_counts,
    $b_seq_length,
    $t_seq_length,
    $tf_set
);

fatal("Error computing z-score", \%job_args) unless $zresult_set;

#
# Use new OPOSSUM::Analysis::CombinedResultSet to combine Fisher and
# Z-score result sets.
#
$logger->info("Combining Fisher and Z-scores");
my $cresult_set = OPOSSUM::Analysis::CombinedResultSet->new(
    -fisher_result_set  => $fresult_set,
    -zscore_result_set  => $zresult_set
);

fatal("Error combining Fisher and z-score result_set", \%job_args)
    unless $cresult_set;

#
# Get results as a list
#
my %result_params;
$result_params{-num_results} = $num_results if defined $num_results;
$result_params{-zscore_cutoff} = $zscore_cutoff if defined $zscore_cutoff;
$result_params{-fisher_cutoff} = $fisher_cutoff if defined $fisher_cutoff;

if (defined $sort_by) {
    if ($sort_by =~ /^fisher/) {
        $sort_by = 'fisher_p_value';
    } elsif ($sort_by =~ /^z_score/ || $sort_by =~ /^z-score/) {
        $sort_by = 'zscore';
    }

    $result_params{-sort_by} = $sort_by;

    # Sort z-score from highest to lowest
    $result_params{-reverse} = 1;
}

$logger->info("Getting filtered/sorted result list");
my $cresults = $cresult_set->get_list(%result_params);

my $message = "";
$ok = 1;
unless ($cresults) {
    $message = "No TFBSs scored above the selected Z-score/Fisher"
        . " thresholds";
    $logger->info($message);
    $ok = 0;
    #
    # XXX
    # The ok/message stuff is not handled properly later, so just fatal it
    # for now.
    # DJA 2012/05/03
    #
    fatal($message, \%job_args);
}

$job_args{-num_results} = scalar @$cresults;

#
# Stringify any TF attributes which may be stored as array refs (e.g. class,
# family).
#
stringify_tf_set_attributes($tf_set, 'class', 'family');

if ($web) {
    $logger->info("Writing HTML results");
    write_results_html(\%job_args); 
}

$logger->info("Writing text results");
my $out_file = catfile($results_dir, RESULTS_TEXT_FILENAME);
write_results_text($out_file, $cresults, $tf_set, \%job_args);

if ($write_details) {
    $logger->info("Writing TFBS details");
    write_tfbs_details($cresults, $tf_set, \%job_args);
}

if ($plot) {
    $logger->info("Plotting scores vs. profile \%GC content");

    my $z_plot_file      = "$results_dir/" . ZSCORE_PLOT_FILENAME;
    my $fisher_plot_file = "$results_dir/" . FISHER_PLOT_FILENAME;

    my $plotter = OPOSSUM::Plot::ScoreVsGC->new(-logger => $logger);

    if ($plotter) {
        my @z_plot_errs;
        unless (
            $plotter->plot(
                $cresults, $tf_set, 'Z', ZSCORE_PLOT_SD_FOLD, $z_plot_file,
                \@z_plot_errs
            )
        ) {
            my $plot_err_str = '';
            if (@z_plot_errs) {
                $plot_err_str = join '\n', @z_plot_errs;
            }
            $logger->error(
                "Could not plot Z-scores vs. GC content - $plot_err_str"
            );
        }

        $logger->info(
            "Finished plotting Z-scores vs. GC content"
        );
    } else {
        $logger->error("Could not initialize Z-score vs. GC content plotting");
    }

    #
    # XXX
    # Create new plotter instance to avoid R "plot.new has not been called yet"
    # error. Still don't know why this seemed to work before and still works
    # in oPOSSUM3 but now doesn't work here.
    #
    #$plotter = OPOSSUM::Plot::ScoreVsGC->new(-logger => $logger);

    if ($plotter) {
        my @f_plot_errs;
        unless(
            $plotter->plot(
                $cresults, $tf_set, 'Fisher', FISHER_PLOT_SD_FOLD,
                $fisher_plot_file, \@f_plot_errs
            )
        ) {
            my $plot_err_str = '';
            if (@f_plot_errs) {
                $plot_err_str = join '\n', @f_plot_errs;
            }
            $logger->error(
                "Could not plot Fisher scores vs. GC content - $plot_err_str"
            );
        }

        $logger->info(
            "Finished plotting Fisher scores vs. GC content"
        );
    } else {
        $logger->error("Could not initialize Fisher vs. GC content plotting");
    }
}

if ($email) {
    $logger->info("Sending notification email to $email");
    send_email(\%job_args);
}

$logger->info("Performing temporary working file/directory cleanup");

cleanup();

$logger->info("Finished analysis");

exit;

##########################################

#
# Parse program arguments. Set any default values for required arguments that
# don't have values assigned. Set some secondary parameters based on passed
# arguments.
#
sub parse_args
{
    unless ($job_id) {
        $job_id = $$;
    }
    $job_args{-job_id} = $job_id,

    $job_args{-web}   = $web if $web;
    $job_args{-email} = $email if $email;

    unless ($species) {
        fatal("No species specified.", \%job_args);
    }
    $job_args{-species} = $species;

    my $heading = sprintf(
        "%s Analysis", ucfirst $species
    );
    $job_args{-heading} = $heading;

    #
    # Check that exactly one target experiment / CAGE peak argument
    # was provided.
    #
    unless ((@t_exp_ids ? 1 : 0) + ($t_exp_ids_file ? 1 : 0)
          + ($t_tss_names_file ? 1 : 0) + ($t_tss_regions_file ? 1 : 0) == 1)
    {
        fatal(
            "Please provide target FANTOM5 experiments, FANTOM5 CAGE peak"
            . " names (IDs) or user defined CAGE peaks using one and"
            . " only one of the following options:"
            . " -txids, -txf, -ttssf or -trf.",
            \%job_args
        );
    }

    #
    # If provided, parse background experiment IDs given on command line.
    #
    if (@t_exp_ids) {
        my $t_exp_ids_str = join(',', @t_exp_ids);
        @t_exp_ids = split(/\s*,\s*/, $t_exp_ids_str);

        unless (@t_exp_ids) {
            fatal("Error parsing target experiment IDs.", \%job_args);
        }

        $job_args{-t_exp_ids} = \@t_exp_ids;
    }

    $job_args{-t_exp_ids_file} = $t_exp_ids_file if $t_exp_ids_file;
    $job_args{-t_tss_names_file} = $t_tss_names_file if $t_tss_names_file;
    $job_args{-t_tss_regions_file} = $t_tss_regions_file if $t_tss_regions_file;

    #
    # Determine the target CAGE peak type (FANTOM5 or custom) based
    # on input parameters specified above.
    #
    my $t_tss_type;
    if (@t_exp_ids || $t_exp_ids_file || $t_tss_names_file) {
        $t_tss_type = 'fantom5';
    } elsif ($t_tss_regions_file) {
        $t_tss_type = 'custom';
    }

    #
    # Sanity check. This should never happen as input parameters are checked
    # above.
    #
    unless ($t_tss_type) {
        fatal("Could not determine target CAGE peak type (FANTOM5 or"
            . " user defined) from specified input parameters\n", \%job_args
        );
    }

    $job_args{-t_tss_type} = $t_tss_type;


    #
    # Check that exactly one background experiment / CAGE peak argument
    # was provided.
    #
    unless (($b_is_rand ? 1 : 0) + (@b_exp_ids ? 1 : 0)
          + ($b_exp_ids_file ? 1 : 0) + ($b_tss_names_file ? 1 : 0)
          + ($b_tss_regions_file ? 1 : 0) == 1)
    {
        fatal(
            "Please provide background FANTOM5 experiments, FANTOM5 CAGE peak"
            . " names (IDs), user defined CAGE peaks or a random background"
            . " using one and only one of the following options:"
            . " -bxids, -bxf, -btssf, -brf or -brand.",
            \%job_args
        );
    }

    #
    # If provided, parse background experiment IDs given on command line.
    #
    if (@b_exp_ids) {
        my $b_exp_ids_str = join(',', @b_exp_ids);
        @b_exp_ids = split(/\s*,\s*/, $b_exp_ids_str);

        unless (@b_exp_ids) {
            fatal("Error parsing background experiment IDs", \%job_args);
        }

        $job_args{-b_exp_ids} = \@b_exp_ids;
    }

    $job_args{-b_exp_ids_file} = $b_exp_ids_file if $b_exp_ids_file;
    $job_args{-b_tss_names_file} = $b_tss_names_file if $b_tss_names_file;
    $job_args{-b_is_rand} = $b_tss_names_file if $b_tss_names_file;

    #
    # Determine the background CAGE peak input type (FANTOM5 or custom)
    # based on input parameters specified.
    #
    # XXX
    # For the HOMER background sequence generation version we cannot (yet)
    # determine the corresponding regions from sequences generated so we
    # have to scan the sequences rather than fetch TFBS from the DB by
    # the region coordinates.
    # XXX
    #
    my $b_tss_type;
    if (@b_exp_ids || $b_exp_ids_file || $b_tss_names_file) {
        $b_tss_type = 'fantom5';
    } elsif ($b_is_rand || $b_tss_regions_file) {
        $b_tss_type = 'custom';
    }

    #
    # Sanity check. This should never happen as input parameters are
    # checked above.
    #
    unless ($b_tss_type) {
        fatal("Could not determine background CAGE peak type (FANTOM5 or"
            . " user defined) from specified input parameters\n", \%job_args
        );
    }

    $job_args{-b_tss_type} = $b_tss_type;


    #
    # Check if target gene filters were provided.
    #
    if (@t_gene_ids && $t_gene_ids_file) {
        fatal("Please specify only one of -tgids or -tgf.", \%job_args);
    }

    if (@t_gene_ids) {
        my $t_gene_ids_str = join(',', @t_gene_ids);
        @t_gene_ids = split(/\s*,\s*/, $t_gene_ids_str);

        unless (@t_gene_ids) {
            fatal("Error parsing target gene IDs.", \%job_args);
        }

        $job_args{-t_gene_ids} = \@t_gene_ids;
    } elsif ($t_gene_ids_file) {
        $job_args{-t_gene_ids_file} = $t_gene_ids_file if $t_gene_ids_file;
    }


    #
    # Check if target gene filters were provided.
    #
    if (@b_gene_ids && $b_gene_ids_file) {
        fatal("Please specify only one of -bgids or -bgf.", \%job_args);
    }

    if (@b_gene_ids) {
        my $b_gene_ids_str = join(',', @b_gene_ids);
        @b_gene_ids = split(/\s*,\s*/, $b_gene_ids_str);

        unless (@b_gene_ids) {
            fatal("Error parsing background gene IDs.", \%job_args);
        }

        $job_args{-b_gene_ids} = \@b_gene_ids;
    } elsif ($b_gene_ids_file) {
        $job_args{-b_gene_ids_file} = $b_gene_ids_file if $b_gene_ids_file;
    }

    #
    # JASPAR / TF parameter settings
    #
    unless (@collections || @tax_groups || @tf_ids || $tf_ids_file
            || $tf_matrix_file)
    {
        fatal("Please specify either at least one TFBS profile selection"
            . " option (-tff, -tfids, -co, -tax, -ic)", \%job_args);
    }

    if ((@collections || @tax_groups || @tf_ids || $tf_ids_file)
        && $tf_matrix_file)
    {
        fatal("Please specify EITHER a user defined TFBS matrix file (-tff)"
            . " OR one or more JASPAR TFBS selection parameters"
            . " (-co, -tax, -ic, -tfids.",
            \%job_args);
    }

    if ($tf_matrix_file) {
        $job_args{-tf_type} = 'custom';
        $job_args{-tf_matrix_file} = $tf_matrix_file;
    } else {
        $job_args{-tf_type} = 'jaspar';

        if ($tf_ids_file) {
            $job_args{-tf_select_criteria} = 'file';
            $job_args{-tf_ids_file} = $tf_ids_file;
        } elsif (@tf_ids) {
            $job_args{-tf_select_criteria} = 'ids';

            my $tf_ids_str = join(',', @tf_ids);
            @tf_ids = split(/\s*,\s*/, $tf_ids_str);

            unless (@tf_ids) {
                fatal("Error parsing JASPAR TF IDs", \%job_args);
            }

            $job_args{-tf_ids} = \@tf_ids;
        } else {
            $job_args{-tf_select_criteria} = 'collections';

            if (@collections) {
                my $collections_str = join(',', @collections);
                @collections = split(/\s*,\s*/, $collections_str);

                unless (@collections) {
                    fatal("Error parsing JASPAR collections", \%job_args);
                }
            } else {
                # if no collection specified, use the default
                push @collections, DFLT_JASPAR_COLLECTION;
            }

            $job_args{-collections} = \@collections;

            if (@tax_groups) {
                my $tax_groups_str = join(',', @tax_groups);
                @tax_groups = split(/\s*,\s*/, $tax_groups_str);

                unless (@tax_groups) {
                    fatal("Error parsing JASPAR tax groups", \%job_args);
                }

                $job_args{-tax_groups} = \@tax_groups;
            }

            $job_args{-min_ic} = $min_ic || DFLT_MIN_IC;
        }
    }

    if ($t_exp_ids_file) {
        $user_t_exp_ids_file = $t_exp_ids_file unless $user_t_exp_ids_file;

        $job_args{-t_exp_ids_file} = $t_exp_ids_file;
        $job_args{-user_t_exp_ids_file} = $user_t_exp_ids_file;
    }

    if ($b_exp_ids_file) {
        $user_b_exp_ids_file = $b_exp_ids_file unless $user_b_exp_ids_file;

        $job_args{-b_exp_ids_file} = $b_exp_ids_file;
        $job_args{-user_b_exp_ids_file} = $user_b_exp_ids_file;
    }

    if ($t_tss_names_file) {
        $user_t_tss_names_file = $t_tss_names_file
            unless $user_t_tss_names_file;

        $job_args{-t_tss_names_file} = $t_tss_names_file;
        $job_args{-user_t_tss_names_file} = $user_t_tss_names_file;
    }

    if ($b_tss_names_file) {
        $user_b_tss_names_file = $b_tss_names_file
            unless $user_b_tss_names_file;

        $job_args{-b_tss_names_file} = $b_tss_names_file;
        $job_args{-user_b_tss_names_file} = $user_b_tss_names_file;
    }

    if ($t_gene_ids_file) {
        $user_t_gene_ids_file = $t_gene_ids_file unless $user_t_gene_ids_file;

        $job_args{-t_gene_ids_file} = $t_gene_ids_file;
        $job_args{-user_t_gene_ids_file} = $user_t_gene_ids_file;
    }

    if ($b_gene_ids_file) {
        $user_b_gene_ids_file = $b_gene_ids_file unless $user_b_gene_ids_file;

        $job_args{-b_gene_ids_file} = $b_gene_ids_file;
        $job_args{-user_b_gene_ids_file} = $user_b_gene_ids_file;
    }

    if ($t_filter_regions_file) {
        $user_t_filter_regions_file = $t_filter_regions_file
            unless $user_t_filter_regions_file;

        $job_args{-t_filter_regions_file} = $t_filter_regions_file;
        $job_args{-user_t_filter_regions_file} = $user_t_filter_regions_file;
    }

    if ($b_filter_regions_file) {
        $user_b_filter_regions_file = $b_filter_regions_file
            unless $user_b_filter_regions_file;

        $job_args{-b_filter_regions_file} = $b_filter_regions_file;
        $job_args{-user_b_filter_regions_file} = $user_b_filter_regions_file;
    }

    #
    # Set optional parameters to default values if not provided by the user
    #
    $tf_db         = JASPAR_DB_NAME unless $tf_db;
    $threshold     = DFLT_TFBS_THRESHOLD unless defined $threshold;
    $upstream_bp   = DFLT_UPSTREAM_BP unless defined $upstream_bp;
    $downstream_bp = DFLT_DOWNSTREAM_BP unless defined $downstream_bp;
    $sort_by       = DFLT_RESULT_SORT_BY unless $sort_by;

    $job_args{-hma} = 1 if $hma;
    $job_args{-tf_db} = $tf_db;
    $job_args{-threshold} = $threshold;
    $job_args{-upstream_bp} = $upstream_bp;
    $job_args{-downstream_bp} = $downstream_bp;
    $job_args{-sort_by} = $sort_by;
}

#
# Construct the 'relative' results path from the absolute one. The path
# returned depends on whether we are in web context or not. If the path passed
# in is already a relative one or we are not in web context the relative
# path is the same as the path passed in.
#
sub make_relative_results_path
{
    my ($path) = @_;

    my $rel_path;
    if (file_name_is_absolute($path)) {
        if ($web) {
            $rel_path = $path;
            $rel_path =~ s/.*\///;
            $rel_path = REL_HTDOCS_RESULTS_PATH . "/$rel_path";
        } else {
            $rel_path = $path;
        }
    } else {
        $rel_path = $path;
    }

    return $rel_path;
}

#
# Make a 'relative' html path from an absolute systems (html) path.
# Only applies in web context.
#
sub make_relative_html_path
{
    my ($sys_path, $base_path) = @_;

    my $rel_html_path;
    if ($web) {
        $rel_html_path = abs2rel($sys_path, $base_path)
    } else {
        $rel_html_path = $sys_path;
    }

    return $rel_html_path;
}

#
# Not currently used.
#
sub abs_to_rel_results_path
{
    my $path = shift;

    my $rel_path;
    if ($web) {
        $rel_path = abs_to_rel_url_results_path($path);
    } else {
        $rel_path = abs_to_rel_sys_results_path($path);
    }

    return $rel_path;
}

#
# Not currently used.
#
sub abs_to_rel_url_results_path
{
    my $full_path = shift;

    my ($volume, $dir, $file) = abs2rel($full_path, $results_dir);
    
    my $rel_path = catfile(REL_HTDOCS_RESULTS_PATH, $file);

    return $rel_path;
}

sub make_results_dir
{
    my ($results_dir) = @_;

    unless (-d $results_dir) {
        mkdir $results_dir
            || fatal(
                "Error creating results directory $results_dir - $!",
                \%job_args
            );
    }

    return $results_dir;
}

sub init_logging
{
    #
    # Initialize logging
    #
    my $log_file = get_log_filename("caged_opossum", $results_dir);

    my $logger = get_logger();
    unless ($logger) {
        fatal("Error initializing log file $log_file.", \%job_args);
    }

    if (DEBUG) {
        $logger->level($DEBUG);
    } else {
        $logger->level($INFO);
    }

    #my $layout = Log::Log4perl::Layout::PatternLayout->new("%M:%L %p: %m%n");
    my $layout = Log::Log4perl::Layout::PatternLayout->new("[%d] %p\t%m%n");

    my $appender = Log::Log4perl::Appender->new(
        "Log::Dispatch::File",
        filename    => $log_file,
        mode        => "append"
    );

    $appender->layout($layout);
    $logger->add_appender($appender);

    $job_args{-logger} = $logger;

    return $logger;
}

sub get_tfbs_matrix_set
{
    my ($job_args) = @_;

    my $tf_set;
    my $tf_type = $job_args->{-tf_type};
    my $tf_select_criteria = $job_args->{-tf_select_criteria};

    if ($tf_type eq 'custom') {
        #
        # This takes precendence over all other TFBS profile selection criteria
        # (TF IDs file, TF IDs passed directly on the command line or
        # tax groups and min IC).
        #
        my $tf_matrix_file = $job_args->{-tf_matrix_file};

        my $matrix_set = read_matrices($tf_matrix_file, $job_args);

        unless ($matrix_set && $matrix_set->size > 0) {
            fatal("No user defined TFBS profile matrices read from"
                . " $tf_matrix_file", $job_args
            );
        }

        matrix_set_compute_gc_content($matrix_set, $job_args);

        $tf_set = OPOSSUM::TFSet->new(-matrix_set => $matrix_set);
    } elsif ($tf_type eq 'jaspar') {
        #
        # Retrieve JASPAR matrices
        #
        my %get_matrix_args = (
            -matrixtype => 'PFM'
        );

        if ($tf_select_criteria eq 'file') {
            #
            # This takes precendence over TF IDs passed directly on
            # the command line and other JASPAR selection criteria.
            #
            my $tf_ids_file = $job_args->{-tf_ids_file};

            my $tf_ids = read_tf_ids_from_file($tf_ids_file, $job_args);

            unless ($tf_ids && $tf_ids->[0]) {
                fatal("No JASPAR TF IDs read from $tf_ids_file", $job_args);
            }

            $get_matrix_args{-ID} = $tf_ids;
        } elsif ($tf_select_criteria eq 'ids') {
            #
            # This takes precendence over collections, tax groups and
            # min IC criteria.
            #
            my $tf_ids = $job_args->{-tf_ids};

            $get_matrix_args{-ID} = $tf_ids;
        } elsif ($tf_select_criteria eq 'collections') {
            $get_matrix_args{-collection} = $job_args->{-collections};
            $get_matrix_args{-tax_group} = $job_args->{-tax_groups};
            $get_matrix_args{-min_ic} = $job_args->{-min_ic};
        }

        #
        # Connect to JASPAR database.
        #
        my $tf_db = $job_args->{-tf_db};
        my $jdb = jaspar_db_connect($tf_db)
            || fatal("Could not connect to JASPAR database $tf_db", $job_args);

        $logger->info("Fetching TFBS profile matrices from JASPAR");
        my $matrix_set = $jdb->get_MatrixSet(%get_matrix_args);

        unless ($matrix_set && $matrix_set->size > 0) {
            fatal("Error fetching TFBS profile matrices from JASPAR",
                $job_args);
        }

        #
        # For JASPAR 2010 we have pre-computed the GC content and stored the
        # information as TAG/VAL pairs in MATRIX_ANNOTATION, but we haven't done
        # that (yet) for JASPAR 2014.
        # DJA 2014/11/25
        #
        matrix_set_compute_gc_content($matrix_set, $job_args);

        $tf_set = OPOSSUM::TFSet->new(-matrix_set => $matrix_set);
    } else {
        fatal("Error getting TF matrix set - could not determine TF"
            . " selection criteria", $job_args);
    }

    return $tf_set;
}

#
# Adjust the background regions so that their lengths fall within the length
# range of the target regions. This is any background region which is shorter
# than the minimum target region length is discarded and any background region
# which is longer than the longest target regions is split into smaller sized
# regions. This is to compensate for a perceived shortcoming in BiasAway
# when dealing with longer background sequences.
#
sub adjust_background_region_lengths
{
    my ($t_regions, $b_regions) = @_;

    #
    # XXX
    # This computation of average length was very flawed!!!
    # But it probably wouldn't make any difference anyway.
    # XXX
    #
    #my ($min_length, $max_length) = get_min_max_region_lengths($t_regions);
    #my $avg_length = floor(($min_length + $max_length) / 2);

    my ($min_length, $max_length, $avg_length)
            = get_region_length_stats($t_regions);

    my @new_b_regions;
    foreach my $reg (@$b_regions) {
        my $len = $reg->end - $reg->start + 1;
        my $parent_id = $reg->parent_id;
        my $chrom = $reg->chrom;

        if ($len >= $min_length) {
            if ($len <= $max_length) {
                # Region is between min and max so keep it
                push @new_b_regions, $reg;
            } else {
                # Region is too long so split it.
                my $max_end   = $reg->end;

                my $new_start = $reg->start;
                my $new_end   = $reg->start + $avg_length - 1;
                while ($new_end <= $max_end) {
                    push @new_b_regions, OPOSSUM::SearchRegion->new(
                        -chrom      => $chrom,
                        -start      => $new_start,
                        -end        => $new_end,
                        -parent_id  => $parent_id
                    );

                    $new_start = $new_end + 1;
                    $new_end = $new_start + $avg_length - 1;
                }

                #
                # If the length of final left over piece of region is at
                # least equal to the min. length, keep it.
                #
                if (($max_end - $new_start + 1) >= $min_length) {
                    push @new_b_regions, OPOSSUM::SearchRegion->new(
                        -chrom      => $chrom,
                        -start      => $new_start,
                        -end        => $max_end,
                        -parent_id  => $parent_id
                    );
                }
            }
        }
    }

    #
    # Renumber the new regions with unique IDs
    #
    my $id = 1;
    foreach my $reg (@new_b_regions) {
        $reg->id($id++);
    }

    return @new_b_regions ? \@new_b_regions : undef;
}

sub get_min_max_region_lengths
{
    my ($regions) = @_;

    my $min_length = 9999999;
    my $max_length = 0;
    foreach my $reg (@$regions) {
        my $length = $reg->end - $reg->start + 1;

        $min_length = $length if $length < $min_length;
        $max_length = $length if $length > $max_length;
    }

    return ($min_length, $max_length);
}

sub get_region_length_stats
{
    my ($regions) = @_;

    my $min_length = 9999999;
    my $max_length = 0;
    my $total_length = 0;
    foreach my $reg (@$regions) {
        my $length = $reg->end - $reg->start + 1;

        $total_length += $length;

        $min_length = $length if $length < $min_length;
        $max_length = $length if $length > $max_length;
    }

    my $num_regions = scalar @$regions;
    my $mean_length = floor($total_length / $num_regions);

    return ($min_length, $max_length, $mean_length);
}

#
# Ouput combined Z-score/Fisher results as plain text
#
sub write_results_text
{
    my ($filename, $results, $tf_set, $job_args) = @_;

    return unless $results && $results->[0];

    my $text = "TF\tJASPAR ID\tClass\tFamily\tTax Group\tIC\tGC Content\tTarget region hits\tTarget region non-hits\tBackground region hits\tBackground region non-hits\tTarget TFBS hits\tTarget TFBS nucleotide rate\tBackground TFBS hits\tBackground TFBS nucleotide rate\tZ-score\tFisher score\n";

    foreach my $result (@$results) {
        my $tf = $tf_set->get_tf($result->id());

        my $total_ic;
        if ($tf->isa("TFBS::Matrix::PFM")) {
            $total_ic = sprintf("%.3f", $tf->to_ICM->total_ic());
        } else {
            $total_ic = 'NA';
        }

        my $gc_content = sprintf("%.3f", $tf->tag('gc_content'));

        $text .= sprintf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\n",
            $tf->name,
            $tf->ID,
            $tf->class() || 'NA',
            $tf->tag('family') || 'NA',
            $tf->tag('tax_group') || 'NA',
            $total_ic,
            $gc_content,
            $result->t_seq_hits() || 0,
            $result->t_seq_no_hits() || 0,
            $result->bg_seq_hits() || 0,
            $result->bg_seq_no_hits() || 0,
            $result->t_tfbs_hits() || 0,
            defined $result->t_tfbs_rate()
                ? sprintf("%.3f", $result->t_tfbs_rate()) : 'NA',
            $result->bg_tfbs_hits() || 0,
            defined $result->bg_tfbs_rate()
                ? sprintf("%.3f", $result->bg_tfbs_rate()) : 'NA',
            defined $result->zscore()
                ? sprintf("%.3f", $result->zscore()) : 'NA',
            defined $result->fisher_p_value()
                ? sprintf("%.3f", $result->fisher_p_value()) : 'NA';
    }
    
    unless (open(FH, ">$filename")) {
        fatal("Unable to create results text file $filename", $job_args);
        return;
    }

    print FH $text;

    close(FH);
    
    return $filename;
}

#
# Ouput combined Z-score/Fisher results as HTML
#
sub write_results_html
{    
    my $job_args = shift;

    my $warn_zero_bg_hits = 0;
    foreach my $result (@$cresults) {
        if ($result->bg_seq_hits() == 0) {
            $warn_zero_bg_hits = 1;
            last;
        }
    }

    my $result_type;
    if (defined $zscore_cutoff || defined $fisher_cutoff) {
        $result_type = 'significant_hits';
    } else {
        $result_type = 'top_x_results';
    }

    my $heading             = $job_args->{-heading};
    my $bg_color_class      = $job_args->{-bg_color_class};
    my $tf_type             = $job_args->{-tf_type};
    my $tf_select_criteria  = $job_args->{-tf_select_criteria};

    my $homer_rel_results_text_file;
    my $homer_rel_results_html_file;
    my $hma = $job_args->{-hma};
    if ($hma) {
        $homer_rel_results_text_file = make_relative_html_path(
            $job_args->{-homer_results_text_file}, $results_dir
        );

        $homer_rel_results_html_file = make_relative_html_path(
            $job_args->{-homer_results_html_file}, $results_dir
        );
    }

    my $title = "CAGEd-oPOSSUM $heading";

    my $vars = {
        abs_htdocs_path     => ABS_HTDOCS_PATH,
        abs_cgi_bin_path    => ABS_CGI_BIN_PATH,
        rel_htdocs_path     => REL_HTDOCS_PATH,
        rel_cgi_bin_path    => REL_CGI_BIN_PATH,
        rel_htdocs_tmp_path => REL_HTDOCS_TMP_PATH,
        jaspar_url          => JASPAR_URL,
        title               => $title,
        heading             => $heading,
        section             => 'Analysis Results',
        bg_color_class      => $bg_color_class,
        version             => VERSION,
        devel_version       => DEVEL_VERSION,
        result_retain_days  => REMOVE_RESULTFILES_OLDER_THAN,
        low_matrix_ic       => LOW_MATRIX_IC,
        high_matrix_ic      => HIGH_MATRIX_IC,
        low_matrix_gc       => LOW_MATRIX_GC,
        high_matrix_gc      => HIGH_MATRIX_GC,
        #low_seq_gc          => LOW_SEQ_GC,
        #high_seq_gc         => HIGH_SEQ_GC,
        species             => $species,
        job_id              => $job_id,
        b_is_rand           => $b_is_rand,
        t_experiments       => $t_experiments,
        b_experiments       => $b_experiments,
        num_t_experiments   => $t_experiments ? scalar @$t_experiments : 0,
        num_b_experiments   => $b_experiments ? scalar @$b_experiments : 0,
        t_tss               => $t_tss,
        num_t_tss           => $t_tss ? scalar @$t_tss : 0,
        num_b_tss           => $b_tss ? scalar @$b_tss : 0,
        num_t_search_regions    => $num_t_search_regions,
        num_b_search_regions    => $num_b_search_regions,
        #t_seq_ids           => \@t_sr_ids,
        #num_t_seq_ids       => @t_sr_ids ? scalar @t_sr_ids : 0,
        #num_b_seq_ids       => @b_sr_ids ? scalar @b_sr_ids : 0,
        tf_db               => $tf_db,
        tf_set              => $tf_set,
        tf_select_criteria  => $tf_select_criteria,
        #t_cr_gc_content     => $t_cr_gc_content,
        #b_cr_gc_content     => $b_cr_gc_content,
        collections         => \@collections,
        tax_groups          => \@tax_groups,
        tf_ids              => \@tf_ids,
        min_ic              => $min_ic,
        threshold           => $threshold,
        upstream_bp         => $upstream_bp,
        downstream_bp       => $downstream_bp,
        results             => $cresults,
        rel_results_dir     => $rel_results_dir,
        result_type         => $result_type,
        num_display_results => $num_results,
        zscore_cutoff       => $zscore_cutoff,
        fisher_cutoff       => $fisher_cutoff,
        result_sort_by      => $sort_by,
        warn_zero_bg_hits   => $warn_zero_bg_hits,
        hma                 => $hma,
        results_file        => RESULTS_TEXT_FILENAME,
        zscore_plot_file    => ZSCORE_PLOT_FILENAME,
        fisher_plot_file    => FISHER_PLOT_FILENAME,
        homer_results_html_file  => $homer_rel_results_html_file,
        homer_results_text_file  => $homer_rel_results_text_file,
        message             => $message,
        user_t_exp_ids_file => $user_t_exp_ids_file,
        user_b_exp_ids_file => $user_b_exp_ids_file,
        user_t_gene_ids_file => $user_t_gene_ids_file,
        user_b_gene_ids_file => $user_b_gene_ids_file,
        user_t_filter_regions_file => $user_t_filter_regions_file,
        user_b_filter_regions_file => $user_b_filter_regions_file,
        user_t_tss_names_file => $user_t_tss_names_file,
        user_b_tss_names_file => $user_b_tss_names_file,
        write_tfbs_details  => $write_details,
        email               => $email,

        formatf             => sub {
                                    my $dec = shift;
                                    my $f = shift;
                                    return ($f || $f eq '0')
                                        ? sprintf("%.*f", $dec, $f)
                                        : 'NA'
                               },

        formatg             => sub {
                                    my $dec = shift;
                                    my $f = shift;
                                    return ($f || $f eq '0')
                                        ? sprintf("%.*g", $dec, $f)
                                        : 'NA'
                               },

        var_template        => "results_integrated_ssa.html"
    };

    my $output = process_template('master.html', $vars);

    my $html_filename = catfile($results_dir, RESULTS_HTDOCS_FILENAME);

    open(OUT, ">$html_filename")
        || fatal("Could not create HTML results file $html_filename",
                 $job_args);

    print OUT $output;

    close(OUT);

    $logger->info("Wrote HTML formatted results to $html_filename");

    return $html_filename;
}

#
# The HOMER motif results file automatically generates links for de novo motif
# finding results and gene ontology enrichment results regarldess of whether
# these were actually run, resulting in dead links. Here we post process the
# file to remove these lines from it.
#
sub post_process_homer_results_html
{
    my ($homer_results_html_file) = @_;

    unless (open(FH, $homer_results_html_file)) {
        warning(
            "Could not open HOMER HTML results file $homer_results_html_file"
            . " for post-process reading", \%job_args
        );
        return;
    }

    my @lines;
    while (my $line = <FH>) {
        chomp $line;

        unless ($line =~ /homerResults\.html/ || $line =~ /geneOntology\.html/)
        {
            push @lines, $line;
        }
    }
    close(FH);

    unless (open(FH, ">$homer_results_html_file")) {
        warning(
            "Could not open HOMER HTML results file $homer_results_html_file"
            . " for post-process writing", \%job_args
        );
        return;
    }

    foreach my $line (@lines) {
        print FH "$line\n";
    }
    close(FH);
}

######################## old / deprecated routines #############################

#
# For each TF, write the details of the putative TFBSs out to text and html
# files.
#
sub fetch_and_write_tfbs_details
{
    my $sr_set = OPOSSUM::SearchRegionSet->new(-sr_list => $t_search_regions);

    my $sr_ids = $sr_set->ids;

    # If only a subset of results was selected, get the relevant tf ids only
    my $tf_ids;
    foreach my $result (@$cresults) {
        push @$tf_ids, $result->id;
    }
    
    #my $results_dir .= "/tfbs_details";
    #mkdir $results_dir;
    
    foreach my $tf_id (@$tf_ids) {
        #
        # Get search regions corresponding to TFBSs specific to this TF.
        #
        my @tf_sr_ids;

        foreach my $sr_id (@$sr_ids) {
            if ($t_counts->seq_tfbs_count($sr_id, $tf_id)) {
                push @tf_sr_ids, $sr_id;
            }
        }

        #
        # Skip this TF if there were no sites in any search region.
        #
        next unless @tf_sr_ids;

        my $tf_sr_set = $sr_set->subset(-ids => \@tf_sr_ids);

        my $tf_search_regions = $tf_sr_set->get_search_region_list('position');

        #
        # Create a mapping of pre-computed search regions to actual search
        # regions containing sites for this TF.
        #
        my %tf_pc_sr_to_sr;
        foreach my $sr (@$tf_search_regions) {
            push @{$tf_pc_sr_to_sr{$sr->parent_id}}, $sr;
        }

        my @tf_pc_sr_ids = keys %tf_pc_sr_to_sr;

        # 
        # Fetch TFBSs for this TF and pass to routines below.
        #
        $logger->info("Fetching TFBSs for $tf_id");
        my $tfbss = $tfbsa->fetch_tfbss(
            -tf_ids            => $tf_id,
            -threshold         => $threshold,
            #-search_regions    => \@tf_search_regions,
            -search_region_ids => \@tf_pc_sr_ids
        );

        unless ($tfbss) {
            fatal(
                  "No TFBSs retrieved for TF $tf_id at threshold $threshold"
                . " for pre-computed search regions IDs: "
                . join(",", @tf_pc_sr_ids)
            );
        }

        $logger->info("Computing which TFBSs fall into which search regions");
        my $t_sr_tf_sites = compute_tf_search_region_tfbss(
            \%tf_pc_sr_to_sr, $tfbss
        );

        my $tf = $tf_set->get_tf($tf_id);
        
        my $tf_name = $tf->name();
        
        my $text_filename = "$results_dir/$tf_id.txt";
        my $html_filename = "$results_dir/$tf_id.html";

        write_tfbs_details_text(
            $text_filename, $tf, $tf_sr_set, $t_sr_tf_sites, \%job_args
        );
        
        if ($web) {
            write_tfbs_details_html(
                $html_filename, $rel_results_dir, $species, $tf, $tf_sr_set,
                $t_sr_tf_sites, $tf_db, \%job_args
            );
        }
    }
}

#
# Write the details of the putative TFBSs for the given TF for each sequence.
#
sub write_tfbs_details_text
{
    my ($filename, $tf, $seq_set, $seq_tfbss, $job_args) = @_;

    my $total_ic;
    if ($tf->isa("TFBS::Matrix::PFM")) {
        $total_ic = sprintf("%.3f", $tf->to_ICM->total_ic());
    } else {
        $total_ic = 'NA';
    }

    my $text = sprintf("%s\n\n", $tf->name());

    $text .= sprintf("JASPAR ID:\t%s\n", $tf->ID());
    $text .= sprintf("Class:\t%s\n", $tf->class() || 'NA');
    $text .= sprintf("Family:\t%s\n", $tf->tag('family') || 'NA');
    $text .= sprintf("Tax group:\t%s\n", $tf->tag('tax_group') || 'NA');
    $text .= sprintf("Information content:\t%s\n", $total_ic);

    $text .= sprintf("\n\n%s Binding Sites:\n\n", $tf->name());

    #$text .= "Tag cluster search region(s)";

    $text .= qq{Chr\tStart\tEnd\tTFBS Start\tTFBS End\tTFBS Strand\tAbs. Score\tRel. Score\tTFBS Sequence\n};

    foreach my $seq_id (sort keys %$seq_tfbss) {
        my $seq = $seq_set->get_search_region($seq_id);

        # fetch sequence positional information
        my $seq_text = sprintf("%s\t%s\t%s",
            $seq->chrom,
            $seq->start,
            $seq->end
        );
        
        $text .= $seq_text;

        my $sites = $seq_tfbss->{$seq_id};

        my $site_text = '';
        my $first_site = 1;
        foreach my $site (@$sites) {
            unless ($first_site) {
                $site_text .= "\t\t\t\t";
            }
            $first_site = 0;

            $site_text .= sprintf("\t%d\t%d\t%s\t%.3f\t%.1f%%\t%s\n",
                $site->start,
                $site->end,
                $site->strand,
                $site->score,
                $site->rel_score * 100,
                $site->seq);
        }
        
        $text .= $site_text;
    } # end foreach seq    
    
    unless (open(FH, ">$filename")) {
        fatal("Unable to create TFBS details file $filename", $job_args);
        return;
    }

    print FH $text;

    close(FH);
}

#
# Write the details of the putative TFBSs for the given TF for each sequence.
#
sub write_tfbs_details_html
{
    my ($filename, $rel_results_dir, $species, $tf, $seq_set, $seq_tfbss,
        $tf_db, $job_args) = @_;

    my $tf_name = $tf->name();
    my $tf_id   = $tf->ID();

    my $job_id          = $job_args->{-job_id};
    my $heading         = $job_args->{-heading};
    my $bg_color_class  = $job_args->{-bg_color_class};
    my $email           = $job_args->{-email};
    my $logger          = $job_args->{-logger};

    my @seq_ids = sort keys %$seq_tfbss;
    
    open(FH, ">$filename") || fatal(
        "Could not create TFBS details html file $filename", $job_args
    );

    $logger->info("Writing '$tf_name' TFBS details to $filename");

    my $title = "CAGEd-oPOSSUM $heading";
    my $section = sprintf("%s Conserved Binding Sites", $tf_name);

    my $vars = {
        abs_htdocs_path     => ABS_HTDOCS_PATH,
        abs_cgi_bin_path    => ABS_CGI_BIN_PATH,
        rel_htdocs_path     => REL_HTDOCS_PATH,
        rel_cgi_bin_path    => REL_CGI_BIN_PATH,
        rel_htdocs_tmp_path => REL_HTDOCS_TMP_PATH,
        bg_color_class      => $bg_color_class,
        title               => $title,
        heading             => $heading,
        section             => $section,
        version             => VERSION,
        devel_version       => DEVEL_VERSION,
        low_matrix_ic       => LOW_MATRIX_IC,
        high_matrix_ic      => HIGH_MATRIX_IC,
        low_matrix_gc       => LOW_MATRIX_GC,
        high_matrix_gc      => HIGH_MATRIX_GC,
        #low_seq_gc          => LOW_SEQ_GC,
        #high_seq_gc         => HIGH_SEQ_GC,
        jaspar_url          => JASPAR_URL,

        tf_db               => $tf_db,
        tf                  => $tf,
        seq_ids             => \@seq_ids,
        seq_set             => $seq_set,
        seq_tfbss           => $seq_tfbss,
        rel_results_dir     => $rel_results_dir,
        tfbs_details_file   => "$tf_id.txt",

        formatf             => sub {
                                    my $dec = shift;
                                    my $f = shift;
                                    return ($f || $f eq '0')
                                        ? sprintf("%.*f", $dec, $f)
                                        : 'NA'
                               },
                               
        var_template        => "tfbs_details.html"
    };

    my $output = process_template('master.html', $vars, $job_args);

    print FH $output;

    close(FH);
}

sub cleanup
{
    if ($b_is_rand) {
        remove_tree($homer_preparsed_dir, {safe => 1});
    }
}

#
# Use Log4perl to catch messages from warn() and die() in called modules.
# Also works with carp() / cluck()
#
$SIG{__WARN__} = sub {
    local $Log::Log4perl::caller_depth =
        $Log::Log4perl::caller_depth + 1;

    $logger->warn(@_);
    warn(@_);
};

$SIG{__DIE__} = sub {
    if ($^S) {
        # We're in an eval {} and don't want log
        # this message but catch it later
        return;
    }

    $Log::Log4perl::caller_depth++;

    $logger->fatal(@_);
    die @_;
};
