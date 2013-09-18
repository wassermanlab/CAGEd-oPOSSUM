#!/usr/bin/env perl

=head1 NAME

custom_cage_ssa.pl

=head1 SYNOPSIS

  custom_cage_ssa.pl
      -species species 
      -dir results_dir
      -trf FILE
      [-tfrf FILE]
      (([-bxf FILE] | [-bxids exp_ids]) [-btc tag_count] [-btpm tpm])
          | [-btssf FILE]
          | [-brf FILE]
      [-bto]
      ([-bgids] | [-bgf FILE])
      [-bfrf FILE]
      [-tfdb tf_database]
      [-tfmf FILE]
          | [-tff FILE]
          | [-tfids tf_ids]
          | ([-co collections] [-tax tax_groups] [-ic min_ic])
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
      [-utrf FILE]
      [-utfrf FILE]
      [-ubrf FILE]
      [-ubfrf FILE]
      [-ubxf FILE]
      [-ubtssf FILE]

=head1 ARGUMENTS

Argument switches may be abbreviated where unique. Arguments enclosed by
brackets [] are optional.

Some switches can take multiple values. To specify multiple values either
use multiple instances of the switch or a single switch followed by a comma
separated string of values (or some combination thereof).
e.g: -tax vertebrates -tax "insects, nematodes"

    -species species
            The common species name for which the analysis is being
            performed, e.g.: human.

    -dir directory
            Name of directory used for output results files. If the
            directory does not already exist it will be created.

    -trf FILE
            BED file containing list of target TSS regions to search
            for TFBSs.

    -tfrf FILE
            BED file containing list of regions on which to filter the
            target TSS search regions.

    -brf FILE
            BED file containing list of background TSS regions to search
            for TFBSs.

    -btssf FILE
            Input file containing a list of background TSS names.

    -bxids exp_IDs
            List of background experiment IDs. These should be FANTOM5 IDs
            (e.g. FF:3560-170A1).

    -bxf FILE
            Input file containing a list of background experiment IDs with
            one ID per line. If this option is not provided, ALL experiments
            in the oPOSSUM database are used as background.

    -btc tag_count
            Minimum tag count of TSSs for given background experiments to
            use when searching for TFBSs.

    -btpm tpm
            Minimum TPM (tags per million) of TSSs for given background
            experiments to use when searching for TFBSs.

    -bto
            Flag indicating that only CAGE tag clusters which are flagged
            as TSSs should be included.

    -bgids gene_IDs
            List of background gene IDs on which to filter TSSs, i.e. only
            use TSSs associated with the given gene IDs. These should be
            specified as either EntrezGene or UniProt IDs.

    -bgf FILE
            File containing list of gene IDs on which to filter background
            TSSs, i.e. only use TSSs associated with the given gene IDs.
            These should be specified as either EntrezGene or UniProt IDs.

    -bfrf FILE
            BED file containing list of regions on which to filter the
            background TSS search regions.

    -tfdb db_name
            Specifies which TF database to use; default = JASPAR_2010.

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

    -th threshold
            Minimum relative TFBS position weight matrix (PWM) score to
            report in the analysis. The thresold may be spesified as a
            percentage string, e.g. '85%', or as a decimal number, e.g.
            0.85
            Default = '80%' (min. = '75%')

    -fs size
            Amount of flanking region to use either side of TSSs.

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

    The following options are passed to the script by web-based FANTOM
    oPOSSUM. These are not required when running the scripts directly on the
    command line and can generally be ignored.

    -web
            Web server switch. Indicates that the script caller is the web
            server, and HTML results files should also be created.

    -j, -job_id job_ID
            The oPOSSUM job ID.

    -m email
            E-mail address of user. An e-mail is sent to the user to notify
            him/her when the analysis has completed with a URL to the
            HTML results page.

    -utrf FILE
            Original name of the user supplied target TSS regions file
            for informational display purposes only.

    -utfrf FILE
            Original name of the user supplied target filter regions file
            for informational display purposes only.

    -ubrf FILE
            Original name of the user supplied background TSS regions file
            for informational display purposes only.

    -ubfrf FILE
            Original name of the user supplied background filter regions
            file for informational display purposes only.

    -ubtssf FILE
            Original name of the user supplied background TSS names file
            for informational display purposes only.

    -ubxf FILE
            Original name of the user supplied background experiment file
            for informational display purposes only.

=head1 DESCRIPTION

Take one or more target experiment IDs, optional background experiment IDs
and optional subset of transcription factors (TFs) either specified in an
input file, or limited by external (JASPAR) database name and information
content or taxonomic supergroup or all TFs in the FANTOM5 oPOSSUM database.
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

use lib '/devel/FANTOM5_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Carp;

use Log::Log4perl qw(get_logger :levels);

use OPOSSUM::Include::ExperimentInclude;
use OPOSSUM::Include::CustomCAGEInclude;
use OPOSSUM::DBSQL::DBAdaptor;
use OPOSSUM::SearchRegion;
use OPOSSUM::SearchRegionSet;
use OPOSSUM::TFSet;
use OPOSSUM::Analysis::Counts;
use OPOSSUM::Analysis::Zscore;
use OPOSSUM::Analysis::Fisher;
use OPOSSUM::Analysis::CombinedResultSet;
use OPOSSUM::Plot::ScoreVsGC;
use OPOSSUM::Tools::SearchRegionFilter;

use lib ENSEMBL_LIB_PATH;

use Bio::EnsEMBL::DBSQL::DBAdaptor;

use constant BG_COLOR_CLASS => 'bgc_custom_cage';

my $help;
my $job_id;
my $results_dir;
my $web;
my $species;
my $t_regions_file;
my $t_filter_regions_file;
my $b_regions_file;
my @b_exp_ids;
my $b_exp_ids_file;
my $b_tss_names_file;
my $b_tag_count;
my $b_tpm;
my $b_tss_only;
my @b_gene_ids;
my $b_gene_ids_file;
my $b_filter_regions_file;
my $tf_db;
my @tf_ids;
my $tf_matrix_file;
my $tf_ids_file;
my @collections;
my @tax_groups;
my $min_ic;
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
my $user_t_regions_file;
my $user_b_regions_file;
my $user_b_gene_ids_file;
my $user_t_filter_regions_file;
my $user_b_filter_regions_file;
my $user_b_exp_ids_file;
my $user_b_tss_names_file;
GetOptions(
    'species|s=s'   => \$species,
    'dir|d=s'       => \$results_dir,
    'trf=s'         => \$t_regions_file,
    'tfrf=s'        => \$t_filter_regions_file,
    'bxids=s'       => \@b_exp_ids,
    'bxf|b=s'       => \$b_exp_ids_file,
    'btssf=s'       => \$b_tss_names_file,
    'brf=s'         => \$b_regions_file,
    'btc=i'         => \$b_tag_count,
    'btpm=f'        => \$b_tpm,
    'bto'           => \$b_tss_only,
    'bgids=s'       => \@b_gene_ids,
    'bgf=s'         => \$b_gene_ids_file,
    'bfrf=s'        => \$b_filter_regions_file,
    'tfdb|db=s'     => \$tf_db,
    'tfmf=s'        => \$tf_matrix_file,
    'tff=s'         => \$tf_ids_file,
    'tfids|ids=s'   => \@tf_ids,
    'co=s'          => \@collections,
    'tax=s'         => \@tax_groups,
    'ic=s'          => \$min_ic,
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
    'utrf=s'        => \$user_t_regions_file,
    'utfrf=s'       => \$user_t_filter_regions_file,
    'ubgf=s'        => \$user_b_gene_ids_file,
    'ubrf=s'        => \$user_b_regions_file,
    'ubfrf=s'       => \$user_b_filter_regions_file,
    'ubxf=s'        => \$user_b_exp_ids_file,
    'ubtssf=s'      => \$user_b_tss_names_file,
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

my $rel_results_dir = parse_results_dir($results_dir);

$job_args{-results_dir}     = $results_dir;
$job_args{-rel_results_dir} = $rel_results_dir;

my $logger = init_logging();

$logger->info("Starting analysis");

#
# Connect to FANTOM5_oPOSSUM DB and get the necessary adaptors
#
my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);

my $opdba = opossum_db_connect($species)
    || fatal("Could not connect to FANTOM5 oPOSSUM database $db_name",
        \%job_args);

my $dbia = $opdba->get_DBInfoAdaptor
    || fatal("Could not get DBInfoAdaptor;", \%job_args);

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

#
# Connect to JASPAR database.
#
my $jdb = jaspar_db_connect($tf_db)
    || fatal("Could not connect to JASPAR database $tf_db", \%job_args);

my $db_info = $dbia->fetch_db_info();
unless ($db_info) {
    fatal("Could not fetch FANTOM5-oPOSSUM DB info", \%job_args);
}

my $ens_db_name = $db_info->ensembl_db;

#
# Connect to ENSEMBL database.
#
my $ensdba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -host    => ENSEMBL_DB_HOST,
    -user    => ENSEMBL_DB_USER,
    -pass    => ENSEMBL_DB_PASS,
    -dbname  => $ens_db_name,
    -species => $species,
    -driver  => 'mysql'
);

unless ($ensdba) {
    fatal("Could not connect to Ensembl DB $ens_db_name", \%job_args);
}

my $slice_adaptor = $ensdba->get_SliceAdaptor();
unless ($slice_adaptor) {
    fatal("Could not get Ensembl SliceAdaptor", \%job_args);
}

#
# Read target TSS regions from the specified file
#
$logger->info("Reading target TSS search regions from file $t_regions_file");

my $t_tss = read_tss_regions_from_file($t_regions_file, \%job_args);

unless ($t_tss) {
    fatal(
          "Error reading target TSS regions. Please make sure that at least"
        . " the first 6 columns are provided (chromosome, start, end, name,"
        . " score and strand).", \%job_args
    );
}

#
# Read filtering regions if provided
#
my $t_filter_regions;
if ($t_filter_regions_file) {
    $logger->info(
        "Reading target filtering regions from file $t_filter_regions_file"
    );

    $t_filter_regions = read_regions_from_file(
        $t_filter_regions_file, \%job_args
    );

    unless ($t_filter_regions) {
        fatal(
            "No target filtering regions read from file $t_filter_regions_file",
            \%job_args
        );
    }

    $logger->info(sprintf(
        "Read %d target filterning regions from file $t_filter_regions_file",
        scalar @$t_filter_regions
    ));
}

#
# Compute target search regions by applying flanking regions to the TSS,
# merging any overlapping regions and filtering by any provided filtering
# regions.
#
my $t_search_regions = compute_tss_search_regions(
    $t_tss, $upstream_bp, $downstream_bp,
    $t_filter_regions, \%job_args
);

unless ($t_search_regions) {
    fatal("Error computing target TSS search regions", \%job_args);
}

#write_search_regions($t_search_regions, "$results_dir/t_search_regions.txt");

$job_args{-t_search_regions} = $t_search_regions;

$logger->info(
    sprintf "Number of target search regions: %d", scalar @$t_search_regions
);

$logger->info("Computing total target search region length");
my $t_seq_length = compute_search_region_length($t_search_regions);

unless ($t_seq_length) {
    fatal("Error computing total target search region length", \%job_args);
}

$logger->info("Total target search region length: $t_seq_length");

#
# Fetch target search region sequences
#
$logger->info("Fetching target search region sequences");

my $t_seqs = fetch_search_region_sequences(
    $t_search_regions, $slice_adaptor, \%job_args
);

unless ($t_seqs) {
    fatal("Error fetching target search region sequences", \%job_args);
}

#
# Get optional gene IDs on which to filter background TSSs
#
if ($b_gene_ids_file && !@b_gene_ids) {
    #
    # Read gene IDs from file.
    #
    $logger->info("Reading background gene IDs from file $b_gene_ids_file");

    my $gene_ids = read_gene_ids_from_file($b_gene_ids_file, \%job_args);

    unless ($gene_ids) {
        fatal(
            "No background gene IDs read from file $b_gene_ids_file",
            \%job_args
        );
    }

    $logger->info(
        sprintf(
            "Read %d background gene IDs from file $b_gene_ids_file",
            scalar @$gene_ids
        )
    );

    @b_gene_ids = @$gene_ids;
}

my $b_tss;
my $b_experiments;
if ($b_regions_file) {
    $logger->info(
        "Reading background TSS regions from BED file $b_regions_file"
    );

    $b_tss = read_tss_regions_from_file($b_regions_file, \%job_args);

    unless ($b_tss) {
        fatal(
                "Error reading background TSS regions. Please make sure that"
              . " at least the first 6 columns are provided (chromosome,"
              . " start, end, name, score and strand).", \%job_args
        );
    }
} elsif ($b_tss_names_file) {
    $logger->info(
        "Fetching background TSS names from file $b_tss_names_file"
    );

    $b_tss = fetch_tss_by_names_file(
        $tssa, 'background', $b_tss_names_file, $b_tss_only, \@b_gene_ids,
        \%job_args
    );

    unless ($b_tss) {
        fatal("Error reading background TSS names", \%job_args);
    }
} else {
    $logger->info(
        "Fetching background TSSs from FANTOM5 experiments"
    );

    $b_experiments = get_experiments(
        $expa, 'background', \@b_exp_ids, $b_exp_ids_file, \%job_args
    );

    $b_tss = fetch_tss_by_experimental_criteria(
        $tssa, 'background', $b_experiments, $b_tag_count, $b_tpm, $b_tss_only,
        \@b_gene_ids, \%job_args
    );

    unless ($b_tss) {
        fatal(
            "Error reading background TSSs from FANTOM5 experiments",
            \%job_args
        );
    }
}

$job_args{-b_tss} = $b_tss if $b_tss;
$job_args{-b_experiments} = $b_experiments if $b_experiments;

#
# Read filtering regions if provided
#
my $b_filter_regions;
if ($b_filter_regions_file) {
    $logger->info(
        "Reading target filtering regions from file $b_filter_regions_file"
    );

    $b_filter_regions = read_regions_from_file(
        $b_filter_regions_file, \%job_args
    );

    unless ($b_filter_regions) {
        fatal(
            "No target filtering regions read from file $b_filter_regions_file",
            \%job_args
        );
    }

    $logger->info(sprintf(
        "Read %d target filterning regions from file $b_filter_regions_file",
        scalar @$b_filter_regions
    ));
}

#
# Compute background search regions by applying flanking regions to the TSS,
# merging any overlapping regions and filtering by any provided filtering
# regions.
#
$logger->info("Computing background TSS search regions");

my $b_search_regions = compute_tss_search_regions(
    $b_tss, $upstream_bp, $downstream_bp, $b_filter_regions, \%job_args
);

unless ($b_search_regions) {
    fatal("Error computing background TSS search regions", \%job_args);
}

$job_args{-b_search_regions} = $b_search_regions if $b_search_regions;

#write_search_regions(
#   $b_search_regions, "$results_dir/b_search_regions.txt"
#);

my $b_sr_num = scalar @$b_search_regions;

$job_args{-b_sr_num} = $b_sr_num;

$logger->info(
    sprintf "Number of background search regions: %d", scalar $b_sr_num
);

$logger->info("Computing total background search region length");
my $b_seq_length = compute_search_region_length($b_search_regions);

unless ($b_seq_length) {
    fatal(
        "Error computing total background search region length",
        \%job_args
    );
}

$logger->info("Total background search region length: $b_seq_length");

#
# Retrieve JASPAR matrices
#
my %get_matrix_args = (
    -matrixtype => 'PFM'
);

my $tf_set;
my $tf_select_criteria;
if ($tf_matrix_file) {
    #
    # This takes precendence over TF IDs file, TF IDs passed directly on the
    # command line or tax groups and min IC
    #
    $tf_select_criteria = 'custom';

    my $matrix_set = read_matrices($tf_matrix_file, \%job_args);

    unless ($matrix_set && $matrix_set->size > 0) {
        fatal(
            "No TFBS profile matrices fread from $tf_matrix_file", \%job_args
        );
    }


    matrix_set_compute_gc_content($matrix_set, \%job_args);

    $tf_set = OPOSSUM::TFSet->new(-matrix_set => $matrix_set);
} else {
    if ($tf_ids_file) {
        #
        # This takes precendence over TF IDs passed directly on the command line
        # or tax groups and min IC
        #
        $tf_select_criteria = 'specific';

        @tf_ids = @{read_tf_ids_from_file($tf_ids_file, \%job_args)};

        unless (@tf_ids && $tf_ids[0]) {
            fatal("No TF IDs read from $tf_ids_file", \%job_args);
        }

        $get_matrix_args{-ID} = \@tf_ids;
    } elsif (@tf_ids) {
        # This takes precendence over tax groups and min IC
        $tf_select_criteria = 'specific';
        $get_matrix_args{-ID} = \@tf_ids;
    } else {
        $tf_select_criteria = 'min_ic';
        $get_matrix_args{-collection} = \@collections if @collections;
        $get_matrix_args{-tax_group} = \@tax_groups if @tax_groups;
        $get_matrix_args{-min_ic} = $min_ic || DFLT_CORE_MIN_IC;
    }

    $logger->info("Fetching TFBS profile matrices from JASPAR");
    my $matrix_set = $jdb->get_MatrixSet(%get_matrix_args);

    unless ($matrix_set && $matrix_set->size > 0) {
        fatal("Error fetching TFBS profile matrices from JASPAR", \%job_args);
    }

    $tf_set = OPOSSUM::TFSet->new(-matrix_set => $matrix_set);
}

my $tf_ids   = $tf_set->ids();
my $tf_names = $tf_set->names();

my $b_seqs;
my @b_pc_sr_ids;
my $b_search_region_map;
if ($tf_select_criteria eq 'custom' || $b_regions_file) {
    #
    # If TFBS profile matrices or TSS regions were provided directly by user,
    # then fetch the corresponding sequences.
    #
    $logger->info("Fetching background search region sequences");

    $b_seqs = fetch_search_region_sequences(
        $b_search_regions, $slice_adaptor, \%job_args
    );

    unless ($b_seqs) {
        fatal("Error fetching background search region sequences", \%job_args);
    }
} else {
    #
    # If TSSs were fetched from the DB, then create a mapping of the
    # pre-computed search region ID to the TSSs associated to that search
    # region ID (TSSs which fall within those pre-computed search regions).
    #
    my %b_pc_sr_ids_hash = map {$_->search_region_id => 1} @$b_tss;

    @b_pc_sr_ids = keys %b_pc_sr_ids_hash;

    #$logger->info("Fetching background pre-computed search regions");
    #
    #my $b_pc_search_regions = $sra->fetch(-ids => \@b_pc_sr_ids);
    #
    #unless ($b_pc_search_regions) {
    #    fatal(
    #        "Error fetching background pre-computed search regions",
    #        \%job_args
    #    );
    #}

    $logger->info(
        "Creating background pre-computed search region to TSS search region"
        . " map"
    );

    $b_search_region_map = create_search_region_map($b_search_regions);
}


################################################################################
# Compute target and backround counts
################################################################################

#
# Search target sequences with the matrix set.
#
$logger->info("Searching target sequences for TFBSs and computing counts");

my $t_counts = search_seqs_and_compute_tfbs_counts(
    $tf_set, $t_seqs, $threshold, $write_details, \%job_args
);

fatal("No TFBSs found in target sequences", %job_args)
    if !$t_counts;


my $b_counts;
if ($b_seqs) {
    $logger->info(
        "Searching background sequences for TFBSs and computing counts"
    );

    $write_details = 0;
    $b_counts = search_seqs_and_compute_tfbs_counts(
        $tf_set, $b_seqs, $threshold, $write_details, \%job_args
    );

    unless ($b_counts) {
        fatal(
            "No TFBSs found in background search region sequences",
            %job_args
        );
    }
} else {
    $logger->info("Fetching background TFBS counts");

    $b_counts = $tfbsa->fetch_tfbs_counts(
        -tf_set             => $tf_set,
        -threshold          => $threshold,
        -search_region_ids  => \@b_pc_sr_ids,
        -search_region_map  => $b_search_region_map
    );

    unless ($b_counts) {
        fatal(
            "Error computing background search region TFBS counts",
            \%job_args
        );
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
my $ok = 1;
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

if ($web) {
    $logger->info("Writing HTML results");
    write_results_html(\%job_args); 
}

$logger->info("Writing text results");
my $out_file = "$results_dir/" . RESULTS_TEXT_FILENAME;
write_results_text($out_file, $cresults, $tf_set, \%job_args);

if ($write_details) {
    $logger->info("Writing TFBS details");
    write_tfbs_details($cresults, $tf_set, \%job_args);
}

if ($plot) {
    $logger->info("Plotting scores vs. profile \%GC content");

    my $z_plot_file      = "$results_dir/" . ZSCORE_PLOT_FILENAME;
    my $fisher_plot_file = "$results_dir/" . FISHER_PLOT_FILENAME;

    my $plotter = OPOSSUM::Plot::ScoreVsGC->new();

    if ($plotter) {
        my $plot_err;
        unless (
            $plotter->plot(
                $cresults, $tf_set, 'Z', ZSCORE_PLOT_SD_FOLD, $z_plot_file,
                \$plot_err
            )
        ) {
            $logger->error(
                "Could not plot Z-scores vs. GC content - $plot_err"
            );
        }
    } else {
        $logger->error("Could not initialize Z-score vs. GC content plotting");
    }

    #
    # XXX
    # Create new plotter instance to avoid R "plot.new has not been called yet"
    # error. Still don't know why this seemed to work before and still works
    # in oPOSSUM3 but now doesn't work here.
    #
    $plotter = OPOSSUM::Plot::ScoreVsGC->new();

    if ($plotter) {
        my $plot_err;
        unless(
            $plotter->plot(
                $cresults, $tf_set, 'Fisher', FISHER_PLOT_SD_FOLD,
                $fisher_plot_file, \$plot_err
            )
        ) {
            $logger->error(
                "Could not plot Fisher scores vs. GC content - $plot_err"
            );
        }
    } else {
        $logger->error("Could not initialize Fisher vs. GC content plotting");
    }
}

if ($email) {
    $logger->info("Sending notification email to $email");
    send_email(\%job_args);
}

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
        "%s Custom CAGE Single Site Analysis", ucfirst $species
    );
    $job_args{-heading} = $heading;

    unless ($t_regions_file) {
        fatal("No target TSS regions specified.", \%job_args);
    }

    unless (   $b_regions_file || @b_exp_ids || $b_exp_ids_file
            || $b_tss_names_file)
    {
        fatal("No background FANTOM5 experiment IDs, FANTOM5 TSS names"
            . " or custom TSS regions specified.", \%job_args);
    }

    if (   ($b_regions_file
                && (@b_exp_ids || $b_exp_ids_file || $b_tss_names_file))
        || (@b_exp_ids && ($b_exp_ids_file || $b_tss_names_file))
        || ($b_exp_ids_file && $b_tss_names_file)
    ) {
        fatal(
            "Please specify only one of -brf, -bxids, -bxf or -btf.",
            \%job_args
        );
    }

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
    }

    if (@b_exp_ids) {
        #
        # Parse background experiment IDs provided on command line.
        #
        my $b_exp_ids_str = join(',', @b_exp_ids);
        @b_exp_ids = split(/\s*,\s*/, $b_exp_ids_str);

        unless (@b_exp_ids) {
            fatal("Error parsing background experiment IDs", \%job_args);
        }

        $job_args{-b_exp_ids} = \@b_exp_ids;
    }

    #
    # JASPAR / TF parameter settings
    #
    if (@collections) {
        my $collections_str = join(',', @collections);
        @collections = split(/\s*,\s*/, $collections_str);

        unless (@collections) {
            fatal("Error parsing JASPAR collections", \%job_args);
        }
        $job_args{-collections_str} = $collections_str;
    } else {
        # if no collection specified, use the default CORE
        push @collections, 'CORE';
        $job_args{-collections_str} = 'CORE';
    }
    $job_args{-collections} = \@collections;

    if (@tax_groups) {
        my $tax_groups_str = join(',', @tax_groups);
        @tax_groups = split(/\s*,\s*/, $tax_groups_str);

        unless (@tax_groups) {
            fatal("Error parsing JASPAR tax groups", \%job_args);
        }

        $job_args{-tax_groups} = \@tax_groups;
        $job_args{-tax_groups_str} = $tax_groups_str;
    }

    my $tf_ids_str;
    if (@tf_ids) {
        my $tf_ids_str = join(',', @tf_ids);
        @tf_ids = split(/\s*,\s*/, $tf_ids_str);

        unless (@tf_ids) {
            fatal("Error parsing JASPAR TF IDs", \%job_args);
        }

        $job_args{-tf_ids} = \@tf_ids;
    }

    if ($t_regions_file) {
        $user_t_regions_file = $t_regions_file unless $user_t_regions_file;

        $job_args{-t_regions_file} = $t_regions_file;
        $job_args{-user_t_regions_file} = $user_t_regions_file;
    }

    if ($b_regions_file) {
        $user_b_regions_file = $b_regions_file unless $user_b_regions_file;

        $job_args{-b_regions_file} = $b_regions_file;
        $job_args{-user_b_regions_file} = $user_b_regions_file;
    }

    if ($b_exp_ids_file) {
        $user_b_exp_ids_file = $b_exp_ids_file unless $user_b_exp_ids_file;

        $job_args{-b_exp_ids_file} = $b_exp_ids_file;
        $job_args{-user_b_exp_ids_file} = $user_b_exp_ids_file;
    }

    if ($b_tss_names_file) {
        $user_b_tss_names_file
            = $b_tss_names_file unless $user_b_tss_names_file;

        $job_args{-b_tss_names_file} = $b_tss_names_file;
        $job_args{-user_b_tss_names_file} = $user_b_tss_names_file;
    }

    if ($t_filter_regions_file) {
        $user_t_filter_regions_file = $t_filter_regions_file
            unless $user_t_filter_regions_file;

        $job_args{-t_filter_regions_file} = $t_filter_regions_file;
        $job_args{-user_t_filter_regions_file} = $user_t_filter_regions_file;
    }

    if ($b_gene_ids_file) {
        $user_b_gene_ids_file = $b_gene_ids_file unless $user_b_gene_ids_file;

        $job_args{-b_gene_ids_file} = $b_gene_ids_file;
        $job_args{-user_b_gene_ids_file} = $user_b_gene_ids_file;
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
    $upstream_bp   = DFLT_UPSTREAM_BP unless $upstream_bp;
    $downstream_bp = DFLT_DOWNSTREAM_BP unless $downstream_bp;
    $sort_by       = DFLT_RESULT_SORT_BY unless $sort_by;

    $job_args{-tf_db} = $tf_db;
    $job_args{-threshold} = $threshold;
    $job_args{-upstream_bp} = $upstream_bp;
    $job_args{-downstream_bp} = $downstream_bp;
    $job_args{-sort_by} = $sort_by;
}

sub parse_results_dir
{
    my $rel_results_dir = $results_dir;

    if ($web) {
        # Remove absolute path
        $rel_results_dir =~ s/.*\///;
        
        # Add relative path
        $rel_results_dir = REL_HTDOCS_RESULTS_PATH . "/$rel_results_dir";
    } else {
        unless (-d $results_dir) {
            mkdir $results_dir
                || fatal(
                    "Error creating results directory $results_dir - $!",
                    \%job_args
                );
        }
    }

    unless (-d $results_dir) {
        die "Results directory $results_dir does not exist\n";
    }

    return $rel_results_dir;
}

sub init_logging
{
    #
    # Initialize logging
    #
    my $log_file = get_log_filename("fantom5_opossum", $results_dir);

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

    my $heading         = $job_args->{-heading};
    my $bg_color_class  = $job_args->{-bg_color_class};

    my $title = "FANTOM5-oPOSSUM $heading";

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
        num_t_search_regions=> $t_search_regions
                                    ? scalar @$t_search_regions : 0,
        user_t_regions_file => $user_t_regions_file,
        b_experiments       => $b_experiments,
        num_b_experiments   => $b_experiments ? scalar @$b_experiments : 0,
        num_b_tss           => $b_tss ? scalar @$b_tss : 0,
        num_b_search_regions=> $b_search_regions
                                    ? scalar @$b_search_regions : 0,
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
        results_file        => RESULTS_TEXT_FILENAME,
        zscore_plot_file    => ZSCORE_PLOT_FILENAME,
        fisher_plot_file    => FISHER_PLOT_FILENAME,
        message             => $message,
        write_tfbs_details  => $write_details,
        user_b_regions_file => $user_b_regions_file,
        user_b_exp_ids_file => $user_b_exp_ids_file,
        user_b_tss_names_file   => $user_b_tss_names_file,
        user_b_gene_ids_file => $user_b_gene_ids_file,
        user_t_filter_regions_file => $user_t_filter_regions_file,
        user_b_filter_regions_file => $user_b_filter_regions_file,
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

        var_template        => "results_custom_cage_ssa.html"
    };

    my $output = process_template('master.html', $vars);

    my $html_filename = "$results_dir/" . RESULTS_HTDOCS_FILENAME;

    open(OUT, ">$html_filename")
        || fatal("Could not create HTML results file $html_filename",
                 $job_args);

    print OUT $output;

    close(OUT);

    $logger->info("Wrote HTML formatted results to $html_filename");

    return $html_filename;
}
