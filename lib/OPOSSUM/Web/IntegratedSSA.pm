package IntegratedSSA;

use base 'CGI::Application';

use OPOSSUM::Web::Include::BaseInclude;
use OPOSSUM::Web::Include::ExperimentInclude;

use Data::Dumper;    # for debugging only
use Template;
use CGI::Carp qw(carpout);    # fatalsToBrowser;
use File::Temp qw/ tempdir /;

use OPOSSUM::Web::State;

use OPOSSUM::Analysis::Fisher;
use OPOSSUM::Analysis::Zscore;
use OPOSSUM::Analysis::CombinedResultSet;


use constant DEBUG          => 0;
use constant BG_COLOR_CLASS => 'bgc_f5_exp';

use strict;

my $USER = $ENV{'USER'};

my $log_dir;
if (DEVEL_VERSION || ($USER && $USER ne 'nobody' && $USER ne 'apache')) {
    $log_dir = "/tmp";
} else {
    $log_dir = OPOSSUM_LOG_PATH;
}

my $log_file = "$log_dir/F5OP_integrated_ssa";
$log_file .= "_devel" if DEVEL_VERSION;
$log_file .= "_$USER" if $USER;
$log_file .= ".log";

open(LOG, ">>$log_file") || die "Error opening log file $log_file - $!\n";

carpout(\*LOG);

sub setup
{
    my $self = shift;

    #printf STDERR "%s: setup called\n", scalar localtime;
    
    $self->start_mode('select_t_data');
    $self->error_mode('error');
    $self->mode_param('rm');
    $self->run_modes(
        'select_t_data'     => 'select_target_cage_data',
        'select_t_filters'  => 'select_target_filters',
        'select_b_data'     => 'select_background_cage_data',
        'select_b_filters'  => 'select_background_filters',
        'select_tfbs'       => 'select_tfbs_parameters',
        'results'           => 'results',
        'error'             => 'error'
    );

    #
    # Even handler defines post-processing routines for certain pages
    #
    my %event_handler = (
        t_data_selected             => \&target_cage_data_selected,
        t_filters_selected          => \&target_filters_selected,
        b_data_selected             => \&background_cage_data_selected,
        b_filters_selected          => \&background_filters_selected,
        tfbs_parameters_selected    => \&tfbs_parameters_selected,
    );

    my $q = $self->query();
    
    #printf STDERR "%s: run mode = %s\n", scalar localtime, $q->param('rm');
    
    my $state;
    my $sid = $q->param('sid');
    if ($sid) {
        printf STDERR "sid = $sid\n";
        #
        # Existing session. Load state from file.
        #
        $state = $self->load_existing_state($sid);
    } else {
        #
        # New session. Create new state object.
        #
        $state = $self->create_new_state();
    }

    # XXX
    # If state is not created or loaded properly, handle this somehow!
    # XXX

    #
    # The events called below may set the run mode by saving it in state.
    # Initialize it to undef.
    # If if an event saves the desired run mode in state, the cgiapp_run
    # routine checks the setting and explicitly sets the run mode.
    #
    #$state->rm(undef);

    #printf STDERR "state:\n%s\n", Data::Dumper::Dumper($state);

    $self->state($state);

    #printf STDERR sprintf("\n\noPOSSUM State:\n%s\n\n",
    #    Data::Dumper::Dumper($self->state())
    #);

    my $event = $q->param("event");
    if ($event && exists($event_handler{$event}))  {
        $event_handler{$event}->($self);
    }
}

sub teardown
{
    my $self = shift;

    #printf STDERR "%s: teardown called\n", scalar localtime;

    #
    # Probably don't really need these as DB will be disconnected on exit
    # anyway by the corresponding object's DESTROY routines
    #
    $self->opossum_db_disconnect();
    #$self->jaspar_db_disconnect();

    my $state = $self->state();
    if ($state) {
        #printf STDERR "%s: saving state\n", scalar localtime;
        #printf STDERR "state:\n%s\n", Data::Dumper::Dumper($state);
        $state->dumper->Purity(1);
        $state->dumper->Deepcopy(1);
        $state->commit();
    }

    #
    # This caused big slow downs in the web application. This functionality
    # has now been moved to the cleanup_old_results.pl script which will
    # be called as a cron job.
    # DJA 2016/4/14
    #
    #$self->_clean_tempfiles;
    #$self->_clean_resultfiles;
}

#
# This is executed automatically before the selected run mode method.
#
sub cgiapp_prerun
{
    my $self = shift;

    if ($self->errors()) {
        #
        # If errors have been set, e.g. in event handling routines, set
        # the error run mode
        #
        printf STDERR "%s: error detected; setting run mode to 'error'\n",
            scalar localtime;

        $self->prerun_mode('error');
    } else {
        if (defined $self->state) {
            #
            # If we have set the run mode in state, then execute this run mode
            # rather than the once coming from the cgi query string.
            #
            my $rm = $self->state->rm();
            $self->state->rm(undef);
            if ($rm) {
                printf STDERR "%s: specific run mode set in state: '$rm'\n",
                    scalar localtime;
                $self->prerun_mode($rm);
            }
        }
    }
}

sub select_target_cage_data
{
    my $self = shift;

    printf STDERR "%s: select_target_cage_data called\n", scalar localtime;
    
    my $q = $self->query;
    my $state = $self->state();

    #printf STDERR "state:\n%s\n", Data::Dumper::Dumper($state);

    #
    # If experiment IDs passed in via the query string from an external
    # application, these take precedent. These are always assumed
    # to be Ensembl IDs (gene ID type = 0).
    #
    #foreach my $id ($q->param("id")) {
    #    push @in_t_exp_ids, $id;
    #}

    my $vars = {
        abs_htdocs_path         => ABS_HTDOCS_PATH,
        rel_htdocs_path         => REL_HTDOCS_PATH,
        abs_cgi_bin_path        => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path        => REL_CGI_BIN_PATH,
        bg_color_class          => BG_COLOR_CLASS,
        version                 => VERSION,
        devel_version           => DEVEL_VERSION,
        progress_step           => 1,
        #section                 => 'STEP 1: Select Target CAGE Peaks',
        section                 => 'Select Target CAGE Peaks',
        t_or_b                  => 'target',
        rm                      => 'select_t_filters',
        event                   => 't_data_selected',
        sid                     => $state->sid(),
        title                   => $state->title(),
        heading                 => $state->heading(),
        species                 => $state->species(),
        experiment_ids          => $state->t_exp_ids(),
        tag_count               => $state->t_tag_count()
                                    || DFLT_TARGET_TAG_COUNT,
        tpm                     => $state->t_tpm() || DFLT_TARGET_TPM,
        relative_expression     => $state->t_relative_expression()
                                    || DFLT_TARGET_RELATIVE_EXPRESSION,
        tss_names_file          => $state->t_tss_names_file(),
        var_template            => "select_integrated_ssa_cage_data.html"
    };

    my $output = $self->process_template('master.html', $vars);

    return $output;
}

sub select_background_cage_data
{
    my $self = shift;

    printf STDERR "%s: select_background_cage_data called\n", scalar localtime;
    
    my $q = $self->query;
    my $state = $self->state();

    #printf STDERR "state:\n%s\n", Data::Dumper::Dumper($state);

    my $vars = {
        abs_htdocs_path         => ABS_HTDOCS_PATH,
        rel_htdocs_path         => REL_HTDOCS_PATH,
        abs_cgi_bin_path        => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path        => REL_CGI_BIN_PATH,
        bg_color_class          => BG_COLOR_CLASS,
        version                 => VERSION,
        devel_version           => DEVEL_VERSION,
        progress_step           => 3,
        #section                 => 'STEP 3: Select Background CAGE Peaks',
        section                 => 'Select Background CAGE Peaks',
        t_or_b                  => 'background',
        rm                      => 'select_b_filters',
        event                   => 'b_data_selected',
        homer_url               => HOMER_URL,
        sid                     => $state->sid(),
        title                   => $state->title(),
        heading                 => $state->heading(),
        species                 => $state->species(),
        experiment_ids          => $state->b_exp_ids(),
        tag_count               => $state->b_tag_count()
                                    || DFLT_BACKGROUND_TAG_COUNT,
        relative_expression     => $state->b_relative_expression()
                                    || DFLT_BACKGROUND_RELATIVE_EXPRESSION,
        tpm                     => $state->b_tpm() || DFLT_BACKGROUND_TPM,
        tss_names_file          => $state->b_tss_names_file(),
        var_template            => "select_integrated_ssa_cage_data.html"
    };

    my $output = $self->process_template('master.html', $vars);

    return $output;
}

sub select_target_filters
{
    my $self = shift;

    printf STDERR "%s: select_target_filters called\n", scalar localtime;

    my $q = $self->query;
    my $state = $self->state();
    
    my $vars = {
        abs_htdocs_path         => ABS_HTDOCS_PATH,
        rel_htdocs_path         => REL_HTDOCS_PATH,
        abs_cgi_bin_path        => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path        => REL_CGI_BIN_PATH,
        bg_color_class          => BG_COLOR_CLASS,
        version                 => VERSION,
        devel_version           => DEVEL_VERSION,
        progress_step           => 2,
        #section                 => 'STEP 2: Select Target CAGE Peak Filters',
        section                 => 'Select Target CAGE Peak Filters',
        t_or_b                  => 'target',
        rm                      => 'select_b_data',
        event                   => 't_filters_selected',
        sid                     => $state->sid(),
        title                   => $state->title(),
        heading                 => $state->heading(),
        species                 => $state->species(),
        tss_input_method        => $state->t_tss_input_method(),
        tss_type                => $state->t_tss_type(),
        use_tss_only            => $state->t_use_tss_only(),
        filter_gene_ids_text    => $state->t_filter_gene_ids_text(),
        filter_gene_ids_file    => $state->t_filter_gene_ids_file(),
        filter_regions_text     => $state->t_filter_regions_text(),
        filter_regions_file     => $state->t_filter_regions_file(),
        var_template            => "select_integrated_ssa_filters.html"
    };

    my $output = $self->process_template('master.html', $vars);

    return $output;
}

sub select_background_filters
{
    my $self = shift;

    printf STDERR "%s: select_background_filters called\n", scalar localtime;

    my $q = $self->query;
    my $state = $self->state();
    
    my $vars = {
        abs_htdocs_path         => ABS_HTDOCS_PATH,
        rel_htdocs_path         => REL_HTDOCS_PATH,
        abs_cgi_bin_path        => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path        => REL_CGI_BIN_PATH,
        bg_color_class          => BG_COLOR_CLASS,
        version                 => VERSION,
        devel_version           => DEVEL_VERSION,
        progress_step           => 4,
        #section                 => 'STEP 4: Select Background CAGE Peak Filters',
        section                 => 'Select Background CAGE Peak Filters',
        t_or_b                  => 'background',
        rm                      => 'select_tfbs',
        event                   => 'b_filters_selected',
        sid                     => $state->sid(),
        title                   => $state->title(),
        heading                 => $state->heading(),
        species                 => $state->species(),
        tss_input_method        => $state->b_tss_input_method(),
        tss_type                => $state->b_tss_type(),
        use_tss_only            => $state->b_use_tss_only(),
        filter_gene_ids_text    => $state->b_filter_gene_ids_text(),
        filter_gene_ids_file    => $state->b_filter_gene_ids_file(),
        filter_regions_text     => $state->b_filter_regions_text(),
        filter_regions_file     => $state->b_filter_regions_file(),
        var_template            => "select_integrated_ssa_filters.html"
    };

    my $output = $self->process_template('master.html', $vars);

    return $output;
}

sub select_tfbs_parameters
{
    my $self = shift;

    my $q = $self->query;
    my $state = $self->state();

    my $species = $state->species();

    #
    # Connect to FANTOM5-oPOSSUM DB and retrieve DB info defaults
    #
    unless ($self->opossum_db_connect($species)) {
        return $self->error("Could not connect to CAGEd-oPOSSUM DB");
    }
    my $db_info = $self->fetch_db_info();

    $self->opossum_db_disconnect();

    my $tax_group_str     = $db_info->tax_group();
    my $min_ic            = $db_info->min_ic();
    my $max_flank_size    = $db_info->max_flank_size();
    my $max_upstream_bp   = $max_flank_size;
    my $max_downstream_bp = $max_flank_size;

    my @tax_groups = split /\s*,\s*/, $tax_group_str;
    my $num_tax_groups = scalar @tax_groups;

    #
    # Connect to JASPAR DB and Retrieve TF info
    #
    unless ($self->jaspar_db_connect()) {
        return $self->error("Could not connect to JASPAR DB");
    }

    #my $tf_set = OPOSSUM::TFSet->new();
    my %core_tf_sets;
    #my %pending_tf_sets;
    #my %pbm_tf_sets;
    foreach my $tax_group (@tax_groups) {
        my $core_tf_set = $self->fetch_tf_set(
            -collection => 'CORE',
            -tax_group  => $tax_group,
            -min_ic     => $min_ic
        );

        $core_tf_sets{$tax_group} = $core_tf_set if $core_tf_set;

        #$tf_set->add_matrix_set($core_tf_set);
        
        #my $pending_tf_set = $self->fetch_tf_set(
        #    -collection => 'PENDING',
        #    -tax_group  => $tax_group,
        #    -min_ic     => $min_ic
        #);

        #$pending_tf_sets{$tax_group} = $pending_tf_set;

        #$tf_set->add_matrix_set($pending_tf_set) if $pending_tf_set;
        
        #unless ($species eq 'yeast') {
        #    my $pbm_tf_set = $self->fetch_tf_set(
        #        -collection => 'PBM',
        #        -tax_group  => $tax_group,
        #        -min_ic     => $min_ic
        #    );

        #    $pbm_tf_sets{$tax_group} = $pbm_tf_set;

            #$tf_set->add_matrix_set($pbm_tf_set) if $pbm_tf_set;
        #}
    }

    #$self->jaspar_db_disconnect();

    #
    # Format a tax group list for display on the web page. The $tax_group
    # variable is obtained from the db and may be a single value or a comma
    # separated list (no space after comma).
    #
    my @s_tax_groups;
    foreach my $tg (@tax_groups) {
        # remove trailing 's' (un-pluralize)
        my $stg = $tg;
        $stg =~ s/s$//;
        push @s_tax_groups, $stg;
    }

    my $tax_group_list = join ' / ', @s_tax_groups;

    my $vars = {
        abs_htdocs_path         => ABS_HTDOCS_PATH,
        rel_htdocs_path         => REL_HTDOCS_PATH,
        abs_cgi_bin_path        => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path        => REL_CGI_BIN_PATH,
        bg_color_class          => BG_COLOR_CLASS,
        title                   => $state->title(),
        heading                 => $state->heading(),
        species                 => $state->species,
        progress_step           => 5,
        #section                 => 'STEP 5: Select Transcription Factor Binding Site Parameters',
        section                 => 'Select Transcription Factor Binding Site Parameters',
        version                 => VERSION,
        devel_version           => DEVEL_VERSION,
        homer_url               => HOMER_URL,
        nresults                => NUM_RESULTS,
        dflt_nresults           => DFLT_NUM_RESULTS,
        zcutoffs                => ZSCORE_CUTOFFS,
        fcutoffs                => FISHER_CUTOFFS,
        dflt_min_ic             => DFLT_MIN_IC,
        dflt_threshold          => DFLT_TFBS_THRESHOLD,
        dflt_upstream_bp        => DFLT_UPSTREAM_BP,
        dflt_downstream_bp      => DFLT_DOWNSTREAM_BP,
        dflt_zcutoff            => DFLT_ZSCORE_CUTOFF,
        dflt_fcutoff            => DFLT_FISHER_CUTOFF,
        sid                     => $state->sid(),
        rm                      => 'results',
        event                   => 'tfbs_parameters_selected',
        db_info                 => $db_info,
        tax_groups              => \@tax_groups,
        num_tax_groups          => $num_tax_groups,
        tax_group_list          => $tax_group_list,
        core_tf_sets            => \%core_tf_sets,
        #pbm_tf_sets             => \%pbm_tf_sets,
        #pending_tf_sets         => \%pending_tf_sets,
        #fam_tf_set              => $fam_tf_set,
        max_upstream_bp         => $max_upstream_bp,
        max_downstream_bp       => $max_downstream_bp,
        var_template            => "select_integrated_ssa_tfbs.html"
    };

    my $output = $self->process_template('master.html', $vars);
    #print STDERR "input results:\n"
    #    . Data::Dumper::Dumper($output);

    return $output;
}

#
# Retrieve input from the target CAGE data selection form.
#
sub target_cage_data_selected
{
    my $self = shift;

    printf STDERR "%s: target_cage_data_selected called\n", scalar localtime;
    
    my $q = $self->query;
    my $state = $self->state();
    my $species = $state->species;
    my $results_dir = $state->results_dir();

    $state->t_tss_type(undef);
    $state->t_tss_input_method(undef);
    $state->t_tss_names(undef);
    $state->t_tss_names_file(undef);
    $state->t_user_tss_names_file(undef);
    $state->t_ff_ids(undef);
    $state->t_tag_count(undef);
    $state->t_tpm(undef);
    $state->t_relative_expression(undef);
    $state->t_expression_input_method(undef);
    if (my $tss_names = $self->parse_textbox_as_list('tss_names_text')) {
        my $filename = "$results_dir/t_tss_names.txt";

        unless ($self->create_local_file_from_list($filename, $tss_names)) {
            $self->_error(
                "Could not create local target TSS names file $filename"
            );
            return;
        }

        $state->t_tss_type('fantom5');
        $state->t_tss_input_method('paste');
        #$state->t_tss_names($tss_names);
        $state->t_tss_names_file($filename);
    } elsif (
        my $upload_filename = $self->parse_upload_filename('tss_names_file')
    ) {
        my $filename = "$results_dir/t_tss_names.txt";

        unless (
            $self->create_local_file_from_upload($filename, 'tss_names_file')
        ) {
            $self->_error(
                "Could not create local target TSS names file $filename"
            );
            return 0;
        }

        $state->t_tss_type('fantom5');
        $state->t_tss_input_method('upload');
        $state->t_tss_names_file($filename);
        $state->t_user_tss_names_file($upload_filename);
    } elsif (my $text = $self->parse_textbox('custom_tss_text')) {
        my $filename = "$results_dir/t_custom_tss.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local target custom TSS file $filename"
            );
            return;
        }

        unless ($self->check_file_format($filename, 'bed6')) {
            $self->_error("Error parsing BED formatted CAGE peaks text");
            return;
        }

        $state->t_tss_type('custom');
        $state->t_tss_input_method('paste');
        $state->t_custom_tss_file($filename);
    } elsif (
        my $upload_filename = $self->parse_upload_filename('custom_tss_file')
    ) {
        my $filename = "$results_dir/t_custom_tss.txt";

        unless ($self->create_local_file_from_upload(
            $filename, 'custom_tss_file'
        )) {
            $self->_error(
                "Could not create local target custom TSS file $filename"
            );
            return;
        }

        unless ($self->check_file_format($filename, 'bed6')) {
            $self->_error("Error parsing CAGE peaks BED file $upload_filename");
            return;
        }

        $state->t_tss_type('custom');
        $state->t_tss_input_method('upload');
        $state->t_custom_tss_file($filename);
        $state->t_user_custom_tss_file($upload_filename);
    } else {
        unless ($self->opossum_db_connect($species)) {
            $self->_error("Could not connect to CAGEd-oPOSSUM DB");
            return 0;
        }
        my $opdba = $self->opdba();

        my $expa = $opdba->get_ExperimentAdaptor();

        #my $all_experiments = $expa->fetch_where();
        #unless ($all_experiments) {
        #    $self->_error("Could not fetch experiments from DB");
        #    return 0;
        #}

        #my @experiments;
        #foreach my $exp (@$all_experiments) {
        #    if ($q->param($exp->FF_id)) {
        #        push @experiments, $exp;
        #    }
        #}

        my $all_ff_ids = $expa->fetch_ff_ids();
        $self->opossum_db_disconnect();

        unless ($all_ff_ids) {
            $self->_error(
                "Could not fetch experiment FANTOM5 IDs from DB"
            );
            return 0;
        }

        my @ff_ids;
        foreach my $ff_id (@$all_ff_ids) {
            if ($q->param($ff_id)) {
                #
                # To save a bit of space in the ontology tree file, I stripped
                # the (redundant) 'FF:' from the FANTOM5 ontology IDs. However,
                # I may forget to do this in future so to be on the safe side,
                # explicitly check for this before adding it back on.
                #
                unless ($ff_id =~ /^FF:/) {
                    $ff_id = "FF:$ff_id";
                }

                push @ff_ids, $ff_id;
            }
        }

        unless (@ff_ids && $ff_ids[0]) {
            $self->_error("No target experiments or TSSs specified");
            return 0;
        }
        $state->t_ff_ids(\@ff_ids);

        my $tag_count = undef;
        my $tpm = undef;
        my $relative_expression = undef;
        my $expression_input_method = $q->param("expression_input_method");
        $state->t_expression_input_method($expression_input_method);
        if ($expression_input_method eq 'tag_count_and_tpm') {
            $tag_count = $self->parse_textbox('tag_count');
            unless (defined $tag_count) {
                $tag_count = DFLT_TARGET_TAG_COUNT;
            }
            $state->t_tag_count($tag_count);

            $tpm = $self->parse_textbox('tpm');
            unless (defined $tpm) {
                $tpm = DFLT_TARGET_TPM;
            }
            $state->t_tpm($tpm);
        } elsif ($expression_input_method eq 'relative_expression') {
            $relative_expression = $self->parse_textbox('relative_expression');
            unless (defined $relative_expression) {
                $relative_expression = DFLT_TARGET_RELATIVE_EXPRESSION;
            }
            $state->t_relative_expression($relative_expression);
        }

        #
        # XXX
        # Does this only apply to TSSs selected via F5 experiments? If so,
        # keep here. Otherwise, this belongs to filters.
        #
        #if ($q->param('use_tss_only')) {
        #    $state->t_use_tss_only(1);
        #} else {
        #    $state->t_use_tss_only(0);
        #}

        $state->t_tss_type('fantom5');
        $state->t_tss_input_method('experiment');
    }

    return 1;
}

#
# Retrieve input from the background CAGE data selection form.
#
sub background_cage_data_selected
{
    my $self = shift;

    printf STDERR "%s: background_cage_data_selected called\n",
        scalar localtime;
    
    my $q = $self->query;
    my $state = $self->state();
    my $species = $state->species;
    my $results_dir = $state->results_dir();

    $state->b_tss_type(undef);
    $state->b_tss_input_method(undef);
    $state->b_tss_names(undef);
    $state->b_tss_names_file(undef);
    $state->b_user_tss_names_file(undef);
    $state->b_ff_ids(undef);
    $state->b_tag_count(undef);
    $state->b_tpm(undef);
    $state->b_relative_expression(undef);
    $state->b_expression_input_method(undef);
    if (my $tss_names = $self->parse_textbox_as_list('tss_names_text')) {
        my $filename = "$results_dir/b_tss_names.txt";

        unless ($self->create_local_file_from_list($filename, $tss_names)) {
            $self->_error(
                "Could not create local background TSS names file $filename"
            );
            return;
        }

        $state->b_tss_type('fantom5');
        $state->b_tss_input_method('paste');
        #$state->b_tss_names($tss_names);
        $state->b_tss_names_file($filename);
    } elsif (
        my $upload_filename = $self->parse_upload_filename('tss_names_file')
    ) {
        my $filename = "$results_dir/b_tss_names.txt";

        unless (
            $self->create_local_file_from_upload($filename, 'tss_names_file')
        ) {
            $self->_error(
                "Could not create local background TSS names file $filename"
            );
            return 0;
        }

        $state->b_tss_type('fantom5');
        $state->b_tss_input_method('upload');
        $state->b_tss_names_file($filename);
        $state->b_user_tss_names_file($upload_filename);
    } elsif (my $text = $self->parse_textbox('custom_tss_text')) {
        my $filename = "$results_dir/b_custom_tss.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local target custom TSS file $filename"
            );
            return;
        }

        unless ($self->check_file_format($filename, 'bed6')) {
            $self->_error("Error parsing BED formatted CAGE peaks text");
            return;
        }

        $state->b_tss_type('custom');
        $state->b_tss_input_method('paste');
        $state->b_custom_tss_file($filename);
    } elsif (
        my $upload_filename = $self->parse_upload_filename('custom_tss_file')
    ) {
        my $filename = "$results_dir/b_custom_tss.txt";

        unless ($self->create_local_file_from_upload(
            $filename, 'custom_tss_file'
        )) {
            $self->_error(
                "Could not create local target custom TSS file $filename"
            );
            return;
        }

        unless ($self->check_file_format($filename, 'bed6')) {
            $self->_error("Error parsing CAGE peaks BED file $upload_filename");
            return;
        }

        $state->b_tss_type('custom');
        $state->b_tss_input_method('upload');
        $state->b_custom_tss_file($filename);
        $state->b_user_custom_tss_file($upload_filename);
    } elsif ($q->param('use_rand_bg')
    ) {
        $state->b_tss_type('fantom5');
        $state->b_tss_input_method('random');
    } else {
        unless ($self->opossum_db_connect($species)) {
            $self->_error("Could not connect to CAGEd-oPOSSUM DB");
            return 0;
        }
        my $opdba = $self->opdba();

        my $expa = $opdba->get_ExperimentAdaptor();

        #my $all_experiments = $expa->fetch_where();
        #unless ($all_experiments) {
        #    $self->_error("Could not fetch experiments from DB");
        #    return 0;
        #}

        #my @experiments;
        #foreach my $exp (@$all_experiments) {
        #    if ($q->param($exp->FF_id)) {
        #        push @experiments, $exp;
        #    }
        #}

        my $all_ff_ids = $expa->fetch_ff_ids();
        $self->opossum_db_disconnect();

        unless ($all_ff_ids) {
            $self->_error("Could not fetch experiment FANTOM5 IDs from DB");
            return 0;
        }

        my @ff_ids;
        foreach my $ff_id (@$all_ff_ids) {
            if ($q->param($ff_id)) {
                #
                # To save a bit of space in the ontology tree file, I stripped
                # the (redundant) 'FF:' from the FANTOM5 ontology IDs. However,
                # I may forget to do this in future so to be on the safe side,
                # explicitly check for this before adding it back on.
                #
                unless ($ff_id =~ /^FF:/) {
                    $ff_id = "FF:$ff_id";
                }

                push @ff_ids, $ff_id;
            }
        }

        unless (@ff_ids && $ff_ids[0]) {
            $self->_error("No background experiments or TSSs specified");
            return 0;
        }
        $state->b_ff_ids(\@ff_ids);

        my $tag_count = undef;
        my $tpm = undef;
        my $relative_expression = undef;
        my $expression_input_method = $q->param("expression_input_method");
        $state->b_expression_input_method($expression_input_method);
        if ($expression_input_method eq 'tag_count_and_tpm') {
            $tag_count = $self->parse_textbox('tag_count');
            unless (defined $tag_count) {
                $tag_count = DFLT_BACKGROUND_TAG_COUNT;
            }
            $state->b_tag_count($tag_count);

            $tpm = $self->parse_textbox('tpm');
            unless (defined $tpm) {
                $tpm = DFLT_BACKGROUND_TPM;
            }
            $state->b_tpm($tpm);
        } elsif ($expression_input_method eq 'relative_expression') {
            $relative_expression = $self->parse_textbox('relative_expression');
            unless (defined $relative_expression) {
                $relative_expression = DFLT_BACKGROUND_RELATIVE_EXPRESSION;
            }
            $state->b_relative_expression($relative_expression);
        }

        #
        # XXX
        # Does this only apply to TSSs selected via F5 experiments? If so,
        # keep here. Otherwise, this belongs to filters.
        #
        #if ($q->param('use_tss_only')) {
        #    $state->b_use_tss_only(1);
        #} else {
        #    $state->b_use_tss_only(0);
        #}

        $state->b_tss_type('fantom5');
        $state->b_tss_input_method('experiment');
    }

    #
    # XXX
    # If the user selected FANTOM 5 experiments then we want to go to
    # the filtering page. Otherwise we want to skip to the select background
    # cage data page.
    # XXX
    #
    if ($state->b_tss_input_method() eq 'random') {
        $state->rm('select_tfbs');
    } else {
        $state->rm('select_b_filters');
    }

    return 1;
}

sub target_filters_selected
{
    my $self = shift;

    my $state   = $self->state();
    my $q       = $self->query;

    my $results_dir = $state->results_dir();

    $state->t_use_tss_only(0);
    $state->t_gene_ids(undef);
    $state->t_gene_ids_input_method(undef);
    $state->t_gene_ids_file(undef);
    $state->t_user_gene_ids_file(undef);
    $state->t_filter_regions_input_method(undef);
    $state->t_filter_regions(undef);
    $state->t_filter_regions_file(undef);
    $state->t_user_filter_regions_file(undef);

    if ($state->t_tss_type() eq 'fantom5') {
        # XXX
        # Does this apply only to FANTOM5 tag clusters selected via experiments
        # or to all FANTOM5 tag clusters, e.g. those specifically selected by
        # name? If all, keep here. Otherwise, this belongs to the
        # target_data_selected method.
        #
        # Actually a better way is to optionally display the TSS only checkbox
        # on the filter input HTML page to control this.
        # XXX
        #
        if ($q->param('use_tss_only')) {
            $state->t_use_tss_only(1);
            printf STDERR "Target using TSS only\n";
        }
    }

    #
    # This now applies to custom as well as FANTOM5 CAGE peaks.
    # DJA 2016/4/27
    #
    if (my $gene_ids
            = $self->parse_textbox_as_list('filter_gene_ids_text')
    ) {
        my $filename = "$results_dir/t_gene_ids.txt";

        unless ($self->create_local_file_from_list($filename, $gene_ids)) {
            $self->_error(
                "Could not create local target genes IDs filter file"
                . " $filename"
            );
            return;
        }

        $state->t_gene_ids_input_method("paste");
        #$state->t_gene_ids($gene_ids);
        $state->t_gene_ids_file($filename);
    } elsif (
        my $upload_filename
            = $self->parse_upload_filename('filter_gene_ids_file')
    ) {
        my $filename = "$results_dir/t_gene_ids.txt";

        unless($self->create_local_file_from_upload(
            $filename, 'filter_gene_ids_file')
        ) {
            $self->_error(
                "Could not create local target gene IDs filter file"
                . " $filename"
            );
            return 0;
        }

        $state->t_gene_ids_input_method("upload");
        $state->t_gene_ids_file($filename);
        $state->t_user_gene_ids_file($upload_filename);
    }

    #
    # Applies to both FANTOM5 and custom CAGE tag clusters
    #
    if (my $regions = $self->parse_textbox_as_list('filter_regions_text')) {
        my $filename = "$results_dir/t_filter_regions.bed";

        unless ($self->create_local_file_from_list($filename, $regions)) {
            $self->_error(
                "Could not create local target filter regions file"
                . " $filename"
            );
            return;
        }

        unless ($self->check_file_format($filename, 'bed3')) {
            $self->_error("Error parsing BED formatted filter regions text");
            return;
        }

        $state->t_filter_regions_input_method("paste");
        #$state->t_filter_regions($regions);
        $state->t_filter_regions_file($filename);
    } elsif (
        my $upload_filename
            = $self->parse_upload_filename('filter_regions_file')
    ) {
        my $filename = "$results_dir/t_filter_regions.bed";

        unless ($self->create_local_file_from_upload(
            $filename, 'filter_regions_file')
        ) {
            $self->_error(
                "Could not create local target filter regions file"
                . " $filename"
            );
            return 0;
        }

        unless ($self->check_file_format($filename, 'bed3')) {
            $self->_error(
                "Error parsing filter regions BED file $upload_filename"
            );
            return;
        }

        $state->t_filter_regions_input_method("upload");
        $state->t_filter_regions_file($filename);
        $state->t_user_filter_regions_file($upload_filename);
    }

    return 1;
}

sub background_filters_selected
{
    my $self = shift;

    my $state   = $self->state();
    my $q       = $self->query;

    my $results_dir = $state->results_dir();

    $state->b_use_tss_only(0);
    $state->b_gene_ids(undef);
    $state->b_gene_ids_input_method(undef);
    $state->b_gene_ids_file(undef);
    $state->b_user_gene_ids_file(undef);
    $state->b_filter_regions_input_method(undef);
    $state->b_filter_regions(undef);
    $state->b_filter_regions_file(undef);
    $state->b_user_filter_regions_file(undef);

    if ($state->b_tss_type() eq 'fantom5') {
        # XXX
        # Does this apply only to FANTOM5 tag clusters selected via experiments
        # or to all FANTOM5 tag clusters, e.g. those specifically selected by
        # name? If all, keep here. Otherwise, this belongs to the
        # target_data_selected method.
        #
        # Actually a better way is to optionally display the TSS only checkbox
        # on the filter input HTML page to control this.
        # XXX
        #
        if ($q->param('use_tss_only')) {
            $state->b_use_tss_only(1);
            printf STDERR "Target using TSS only\n";
        }
    }

    #
    # This now applies to custom as well as FANTOM5 CAGE peaks.
    # DJA 2016/4/27
    #
    if (my $gene_ids
            = $self->parse_textbox_as_list('filter_gene_ids_text')
    ) {
        my $filename = "$results_dir/b_gene_ids.txt";

        unless ($self->create_local_file_from_list($filename, $gene_ids)) {
            $self->_error(
                "Could not create local background gene IDs filter file"
                . " $filename"
            );
            return;
        }

        $state->b_gene_ids_input_method("paste");
        #$state->b_gene_ids($gene_ids);
        $state->b_gene_ids_file($filename);
    } elsif (
        my $upload_filename
            = $self->parse_upload_filename('filter_gene_ids_file')
    ) {
        my $filename = "$results_dir/b_gene_ids.txt";

        unless($self->create_local_file_from_upload(
                $filename, 'filter_gene_ids_file')
        ) {
            $self->_error(
                "Could not create local background gene IDs filter file"
                . " $filename"
            );
            return 0;
        }

        $state->b_gene_ids_input_method("upload");
        $state->b_gene_ids_file($filename);
        $state->b_user_gene_ids_file($upload_filename);
    }

    #
    # Applies to both FANTOM5 and custom CAGE tag clusters
    #
    if (my $regions = $self->parse_textbox_as_list('filter_regions_text')) {
        my $filename = "$results_dir/b_filter_regions.bed";

        unless ($self->create_local_file_from_list($filename, $regions)) {
            $self->_error(
                "Could not create local background filter regions file"
                . " $filename"
            );
            return;
        }

        unless ($self->check_file_format($filename, 'bed3')) {
            $self->_error("Error parsing BED formatted filter regions text");
            return;
        }

        $state->b_filter_regions_input_method("paste");
        #$state->b_filter_regions($regions);
        $state->b_filter_regions_file($filename);
    } elsif (
        my $upload_filename
            = $self->parse_upload_filename('filter_regions_file')
    ) {
        my $filename = "$results_dir/b_filter_regions.bed";

        unless ($self->create_local_file_from_upload(
                $filename, 'filter_regions_file')
        ) {
            $self->_error(
                "Could not create local background filter regions file"
                . " $filename"
            );
            return 0;
        }

        unless ($self->check_file_format($filename, 'bed3')) {
            $self->_error(
                "Error parsing filter regions BED file $upload_filename"
            );
            return;
        }

        $state->b_filter_regions_input_method("upload");
        $state->b_filter_regions_file($filename);
        $state->b_user_filter_regions_file($upload_filename);
    }

    return 1;
}

sub tfbs_parameters_selected
{
    my $self = shift;

    my $state   = $self->state();
    my $q       = $self->query;

    my $species = $state->species();
    my $results_dir = $state->results_dir();

    my $opdba = $self->opossum_db_connect($species);
    unless ($opdba) {
        $self->_error("Could not connect to FANTOM5-oPOSSUM database");
        return 0;
    }

    my $dbia = $opdba->get_DBInfoAdaptor();

    my $db_info = $dbia->fetch_db_info();
    $self->opossum_db_disconnect();

    my $dflt_tax_group_str  = $db_info->tax_group();
    my $dflt_min_ic         = $db_info->min_ic();
    my $min_threshold       = $db_info->min_threshold();
    my $max_flank_size      = $db_info->max_flank_size();
    my $max_upstream_bp     = $max_flank_size;
    my $max_downstream_bp   = $max_flank_size;

    my @dflt_tax_groups = split /\s*,\s*/, $dflt_tax_group_str;
    my $num_dflt_tax_groups = scalar @dflt_tax_groups;

    $state->tfbs_matrix_text(undef);
    $state->tfbs_matrix_file(undef);
    $state->user_tfbs_matrix_file(undef);
    $state->collection(undef);
    $state->min_ic(undef);
    $state->tax_groups(undef);
    $state->tf_select_method(undef);
    $state->threshold(undef);
    $state->upstream_bp(undef);
    $state->downstream_bp(undef);
    $state->result_type(undef);
    $state->num_display_results(undef);
    $state->zscore_cutoff(undef);
    $state->fisher_cutoff(undef);
    $state->result_sort_by(undef);
    $state->tfbs_details(undef);
    $state->tf_select_criteria(undef);
    $state->run_homer_motif_analysis(undef);
    $state->run_cluster_analysis(undef);

    if (my $text = $self->parse_textbox('matrix_paste_text')) {
        my $filename = "$results_dir/matrices.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local TFBS profile matrices file $filename"
            );
            return 0;
        }

        #$state->tfbs_matrix_text($text);
        $state->tfbs_matrix_file($filename);
        $state->tf_select_criteria('custom');
        $state->tf_select_method('paste');
    } elsif (
        my $upload_filename = $self->parse_upload_filename('matrix_upload_file')
    ) {
        my $filename = "$results_dir/matrices.txt";

        unless ($self->create_local_file_from_upload(
            $filename, 'matrix_upload_file'
        )) {
            $self->_error(
                "Could not create local TFBS profile matrices file $filename"
            );
            return 0;
        }

        $state->tfbs_matrix_file($filename);
        $state->user_tfbs_matrix_file($upload_filename);
        $state->tf_select_criteria('custom');
        $state->tf_select_method('upload');
    } else {
        my $collection = 'CORE';

        my @tf_ids;
        if ($collection eq 'CORE') {
            push @tf_ids, $q->param('core_tfs');
        } elsif ($collection eq 'PBM') {
            push @tf_ids, $q->param('pbm_tfs');
        } elsif ($collection eq 'PENDING') {
            push @tf_ids, $q->param('pending_tfs');
        }

        if (scalar @tf_ids > 0) {
            $state->tf_ids(\@tf_ids);
            $state->tf_select_method('specific');
        } else {
            my $min_ic;
            my @tax_groups;

            if ($collection eq 'CORE') {
                $min_ic = $q->param('core_min_ic');
                if ($num_dflt_tax_groups > 1) {
                    @tax_groups = $q->param("core_tax_groups");
                } else {
                    @tax_groups = @dflt_tax_groups;
                }
            } elsif ($collection eq 'PBM') {
                $min_ic = $q->param('pbm_min_ic');
                if ($num_dflt_tax_groups > 1) {
                    @tax_groups = $q->param("pbm_tax_groups");
                } else {
                    @tax_groups = @dflt_tax_groups;
                }
            } elsif ($collection eq 'PENDING') {
                $min_ic = $q->param('pending_min_ic');
                if ($num_dflt_tax_groups > 1) {
                    @tax_groups = $q->param("pending_tax_groups");
                } else {
                    @tax_groups = @dflt_tax_groups;
                }
            }

            if (!defined $min_ic || $min_ic < $dflt_min_ic) {
                $min_ic = $dflt_min_ic;
            }
            
            if ($collection eq 'CORE' && scalar @tax_groups == 0) {
                $self->_error(
                    "No JASPAR CORE collection tax groups selected"
                );
                return 0;
            }

            $state->min_ic($min_ic);
            $state->tax_groups(\@tax_groups) if @tax_groups && $tax_groups[0];
            $state->tf_select_method('min_ic');
        }

        $state->tf_select_criteria('jaspar');
        $state->collection($collection);
    }


    my $threshold = $self->parse_textbox('threshold');
    #printf STDERR "input threshold = $threshold\n";
    if (defined $threshold) {
        $threshold /= 100;
        if ($threshold < $min_threshold) {
            $threshold = $min_threshold;
        } elsif ($threshold > 1) {
            $threshold = 1;
        }
    } else {
        $threshold = DFLT_TFBS_THRESHOLD / 100;
    }
   
    $state->threshold($threshold);
    #printf STDERR "threshold set to $threshold\n";

    my $upstream_bp = $self->parse_textbox('upstream_bp');
    if (defined $upstream_bp) {
        $upstream_bp = $max_upstream_bp if $upstream_bp > $max_upstream_bp;
        $upstream_bp = 0 if $upstream_bp < 0;
    } else {
        $upstream_bp = DFLT_UPSTREAM_BP;
    }
    
    $state->upstream_bp($upstream_bp);

    my $downstream_bp = $self->parse_textbox('downstream_bp');
    if (defined $downstream_bp) {
        $downstream_bp = $max_downstream_bp
            if $downstream_bp > $max_downstream_bp;
        $downstream_bp = 0 if $downstream_bp < 0;
    } else {
        $downstream_bp = DFLT_DOWNSTREAM_BP;
    }
    
    $state->downstream_bp($downstream_bp);

    my $result_type = $q->param('result_type');
    $state->result_type($result_type);

    if ($result_type eq 'top_x_results') {
        $state->num_display_results($q->param('num_display_results'));
    } elsif ($result_type eq 'significant_hits') {
        $state->zscore_cutoff($q->param('zscore_cutoff'));
        $state->fisher_cutoff($q->param('fisher_cutoff'));
    }

    $state->result_sort_by($q->param('result_sort_by'));
    $state->tfbs_details($q->param('tfbs_details'));
    $state->run_homer_motif_analysis($q->param('run_homer_motif_analysis'));
    $state->run_cluster_analysis($q->param('run_cluster_analysis'));

    my $email = $q->param('email');
    unless (defined $email) {
        $self->_error(
              "No e-mail address provided. An e-mail address is"
            . " required to send notification when your results are ready."
        );
        return 0;
    }
    $state->email($email);

    return 1;
}

sub results
{
    my $self = shift;

    my $q = $self->query;
    my $state = $self->state;

    my $species = $state->species;

    my $opdba = $self->opossum_db_connect($species);
    unless ($opdba) {
        return $self->error("Could not connect to FANTOM5-oPOSSUM database");
    }

    my $dbia = $opdba->get_DBInfoAdaptor();
    my $db_info = $dbia->fetch_db_info();

    my $expa = $opdba->get_ExperimentAdaptor();

    my $results_dir = $state->results_dir();

    my $job_id = $results_dir;
    $job_id =~ s/.*\///;

    my $email = $state->email();
    unless ($email) {
        return $self->error("No email address specified");
    }

    #
    # Build the analysis script call
    #
    my $command = OPOSSUM_SCRIPTS_PATH . "/integrated_ssa.pl"
        . " -j " . $job_id
        . " -m " . $email
        . " -s " . $species
        . " -dir " . $results_dir
        . " -plot"
        . " -web";

    my $t_tss_input_method = $state->t_tss_input_method();
    my $t_tss_type = $state->t_tss_type();
    my $t_expression_input_method = $state->t_expression_input_method();
    my $t_ff_ids;
    my @t_experiments;
    if ($t_tss_type eq 'fantom5') {
        if ($t_tss_input_method eq 'experiment') {
            $t_ff_ids = $state->t_ff_ids();
            unless ($t_ff_ids) {
                return $self->error("No target experiment IDs provided");
            }

            $command .= " -txids " . join ',', @$t_ff_ids;

            foreach my $ff_id (@$t_ff_ids) {
                push @t_experiments, $expa->fetch_by_ff_id($ff_id);
            }

            if ($t_expression_input_method eq 'tag_count_and_tpm') {
                if (defined $state->t_tag_count()) {
                    $command .= " -ttc " . $state->t_tag_count();
                }

                if (defined $state->t_tpm()) {
                    $command .= " -ttpm " . $state->t_tpm();
                }
            } elsif ($t_expression_input_method eq 'relative_expression') {
                if (defined $state->t_relative_expression()) {
                    $command .= " -trex " . $state->t_relative_expression();
                }
            }
        } else {
            #
            # Whether the TSS names are pasted or uploaded, they have been
            # saved to a local file.
            #
            $command .= " -ttssf " . $state->t_tss_names_file();

            if (defined $state->t_user_tss_names_file()) {
                $command .= " -uttssf " . $state->t_user_tss_names_file();
            }
        }
    } elsif ($t_tss_type eq 'custom') {
        # This is the same whether the input method is 'upload' or 'paste'
        $command .= " -trf " . $state->t_custom_tss_file();
    }

    if ($state->t_use_tss_only()) {
        $command .= " -tto";
    }

    if (defined $state->t_gene_ids_file()) {
        $command .= " -tgf " . $state->t_gene_ids_file();
        $command .= " -utgf " . $state->t_user_gene_ids_file()
            if $state->t_user_gene_ids_file();
    }

    if (defined $state->t_filter_regions_file()) {
        $command .= " -tfrf " . $state->t_filter_regions_file();
        $command .= " -utfrf " . $state->t_user_filter_regions_file()
            if $state->t_user_filter_regions_file();
    }

    my $b_tss_type = $state->b_tss_type();
    my $b_tss_input_method = $state->b_tss_input_method();
    my $b_expression_input_method = $state->b_expression_input_method();

    printf STDERR "b_tss_type: $b_tss_type\n";
    printf STDERR "b_tss_input_method: $b_tss_input_method\n";
    printf STDERR "b_expression_input_method: $b_expression_input_method\n";
    printf STDERR "b_tag_count: %s\n", $state->b_tag_count;
    printf STDERR "b_tpm: %s\n", $state->b_tpm;
    printf STDERR "b_relative_expression: %s\n", $state->b_relative_expression;

    my $b_ff_ids;
    my @b_experiments;
    if ($b_tss_type eq 'fantom5') {
        if ($b_tss_input_method eq 'experiment') {
            $b_ff_ids = $state->b_ff_ids();
            unless ($b_ff_ids) {
                return $self->error("No background experiment IDs provided");
            }

            $command .= " -bxids " . join ',', @$b_ff_ids;

            foreach my $ff_id (@$b_ff_ids) {
                push @b_experiments, $expa->fetch_by_ff_id($ff_id);
            }

            if ($b_expression_input_method eq 'tag_count_and_tpm') {
                if (defined $state->b_tag_count()) {
                    $command .= " -btc ".  $state->b_tag_count();
                }

                if (defined $state->b_tpm()) {
                    $command .= " -btpm ". $state->b_tpm();
                }
            } elsif ($b_expression_input_method eq 'relative_expression') {
                if (defined $state->b_relative_expression()) {
                    $command .= " -brex ". $state->b_relative_expression();
                }
            }
        } elsif (
            $b_tss_input_method eq 'paste' || $b_tss_input_method eq 'upload'
        ) {
            #
            # Whether the TSS names are pasted or uploaded, they have been
            # saved to a local file.
            #
            $command .= " -btssf " . $state->b_tss_names_file();

            if (defined $state->b_user_tss_names_file()) {
                $command .= " -ubtssf " . $state->b_user_tss_names_file();
            }
        } elsif ($b_tss_input_method eq 'random') {
            $command .= " -brand";
        }
    } elsif ($b_tss_type eq 'custom') {
        # This is the same whether the input method is 'upload' or 'paste'
        $command .= " -brf " . $state->b_custom_tss_file();
    }

    if ($state->b_use_tss_only()) {
        $command .= " -bto";
    }

    if (defined $state->b_gene_ids_file()) {
        $command .= " -bgf " . $state->b_gene_ids_file();
        $command .= " -ubgf " . $state->b_user_gene_ids_file()
            if $state->b_user_gene_ids_file();
    }

    if (defined $state->b_filter_regions_file()) {
        $command .= " -bfrf " . $state->b_filter_regions_file();
        $command .= " -ubfrf " . $state->b_user_filter_regions_file()
            if $state->b_user_filter_regions_file();
    }

    #if (defined $tf_db) {
    #    $command .= " -tfdb $tf_db";
    #}

    if (defined $state->collection()) {
        $command .= " -co " . $state->collection();
    }


    my $tf_set;
    my $tf_ids = $state->tf_ids();
    my $tf_select_method = $state->tf_select_method();
    if ($tf_select_method eq 'paste' || $tf_select_method eq 'upload') {
        $command .= " -tfmf " . $state->tfbs_matrix_file();
    } elsif ($state->tf_select_method() eq 'specific') {
        $command .= " -tfids " . join ',', @$tf_ids;

        #
        # This is just to get the TF names for display on the analysis
        # summary page.
        #
        $self->jaspar_db_connect();

        $tf_set = $self->fetch_tf_set(
            -ID => $tf_ids
        );
    } elsif ($state->tf_select_method() eq 'min_ic') {
        if ($state->tax_groups()) {
            $command .= " -tax " . join ',', @{$state->tax_groups()};
        }

        if (defined $state->min_ic()) {
            $command .= " -ic " . $state->min_ic();
        }
    } else {
        return $self->error("No TFBS profiles selected");
    }

    if (defined $state->upstream_bp()) {
        $command .= " -up " . $state->upstream_bp();
    }

    if (defined $state->downstream_bp()) {
        $command .= " -dn " . $state->downstream_bp();
    }

    my $threshold = $state->threshold();
    #printf STDERR "threshold sent to command = $threshold\n";
    if (defined $threshold) {
        $command .= " -th $threshold";
    }

    if ($state->result_type() eq 'top_x_results') {
        $command .= " -n " . $state->num_display_results();
    } elsif ($state->result_type() eq 'significant_hits') {
        $command .= " -zcutoff " . $state->zscore_cutoff();
        $command .= " -fcutoff " . $state->fisher_cutoff();
    }

    if (defined $state->result_sort_by()) {
        $command .= " -sr " . $state->result_sort_by();
    }

    if ($state->tfbs_details()) {
        $command .= " -details";
    }

    if ($state->run_homer_motif_analysis()) {
        $command .= " -hma";
    }

    if ($state->run_cluster_analysis()) {
        $command .= " -cla";
    }

    my $submitted_time = scalar localtime(time);
    printf LOG "\nStarting analysis at $submitted_time:\n$command\n\n";

    #
    # Perform analysis in "real time", i.e. wait for script to finish and
    # dispay results page.
    #
    #my $out = `exec 2>&1; $command`;
    #if ($out) {
    #    printf LOG "\nCommand returned $out\n";
    #    #return $self->error("$out");
    #}

    #my $outfile = REL_HTDOCS_RESULTS_PATH . "/$job_id/results.html";

    #
    # XXX This does not work
    #
    # my $output = $self->process_html(
    #     ABS_HTDOCS_RESULTS_PATH . "/$job_id/results.html");

    #my $redirect = qq{
    #    <!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">";
    #    <html>
    #    <head>
    #    <title>Your Page Title</title>
    #    <meta http-equiv="REFRESH" content="0;url=$outfile"></HEAD>
    #    <BODY>
    #    </BODY>
    #    </HTML>
    #};

    #return $redirect;

    #
    # Perform analysis in background, i.e. launch script as background job
    # and display interim analysis summary page.
    #
    my $out = system("$command >/dev/null 2>&1 &");

    if ($out) {
        printf LOG "Analysis script returned $out - $!\n";
    }

    my $vars = {
        abs_htdocs_path         => ABS_HTDOCS_PATH,
        abs_cgi_bin_path        => ABS_CGI_BIN_PATH,
        rel_htdocs_path         => REL_HTDOCS_PATH,
        rel_cgi_bin_path        => REL_CGI_BIN_PATH,
        rel_htdocs_tmp_path     => REL_HTDOCS_TMP_PATH,
        bg_color_class          => BG_COLOR_CLASS,
        jaspar_url              => JASPAR_URL,
        section                 => 'Analysis Results',
        title                   => $state->title,
        heading                 => $state->heading,
        version                 => VERSION,
        devel_version           => DEVEL_VERSION,
        result_retain_days      => REMOVE_RESULTFILES_OLDER_THAN,
        low_matrix_ic           => LOW_MATRIX_IC,
        high_matrix_ic          => HIGH_MATRIX_IC,
        low_matrix_gc           => LOW_MATRIX_GC,
        high_matrix_gc          => HIGH_MATRIX_GC,
        #low_seq_gc             => LOW_SEQ_GC,
        #high_seq_gc            => HIGH_SEQ_GC,
        species                 => $state->species,
        job_id                  => $job_id,
        submitted_time          => $submitted_time,
        t_tss_type              => $state->t_tss_type,
        b_tss_type              => $state->b_tss_type,
        t_tss_input_method      => $state->t_tss_input_method,
        b_tss_input_method      => $state->b_tss_input_method,
        t_experiments           => \@t_experiments,
        b_experiments           => \@b_experiments,
        t_tag_count             => $state->t_tag_count(),
        t_tpm                   => $state->t_tpm(),
        t_relative_expression   => $state->t_relative_expression(),
        b_tag_count             => $state->b_tag_count(),
        b_tpm                   => $state->b_tpm(),
        b_relative_expression   => $state->b_relative_expression(),
        t_user_custom_tss_file  => $state->t_user_custom_tss_file(),
        b_user_custom_tss_file  => $state->b_user_custom_tss_file(),
        t_use_tss_only          => $state->t_use_tss_only(),
        b_use_tss_only          => $state->b_use_tss_only(),
        t_gene_ids_input_method => $state->t_gene_ids_input_method(),
        b_gene_ids_input_method => $state->b_gene_ids_input_method(),
        t_user_gene_ids_file    => $state->t_user_gene_ids_file(),
        b_user_gene_ids_file    => $state->b_user_gene_ids_file(),
        t_filter_regions_input_method
                                => $state->t_filter_regions_input_method(),
        b_filter_regions_input_method
                                => $state->b_filter_regions_input_method(),
        t_user_filter_regions_file
                                => $state->t_user_filter_regions_file(),
        b_user_filter_regions_file
                                => $state->b_user_filter_regions_file(),
        t_user_tss_names_file   => $state->t_user_tss_names_file(),
        b_user_tss_names_file   => $state->b_user_tss_names_file(),
        tf_select_method        => $state->tf_select_method(),
        #t_cr_gc_content        => $t_cr_gc_content,
        #b_cr_gc_content        => $b_cr_gc_content,
        collection              => $state->collection(),
        tax_groups              => $state->tax_groups(),
        tf_ids                  => $state->tf_ids(),
        tf_set                  => $tf_set,
        min_ic                  => $state->min_ic(),
        threshold               => $threshold,
        upstream_bp             => $state->upstream_bp(),
        downstream_bp           => $state->downstream_bp(),
        result_type             => $state->result_type(),
        num_display_results     => $state->num_display_results(),
        zscore_cutoff           => $state->zscore_cutoff(),
        fisher_cutoff           => $state->fisher_cutoff(),
        result_sort_by          => $state->result_sort_by(),
        email                   => $state->email(),

        formatf                 => sub {
                                    my $dec = shift;
                                    my $f = shift;
                                    return ($f || $f eq '0')
                                        ? sprintf("%.*f", $dec, $f)
                                        : 'NA'
                               },

        formatg                 => sub {
                                    my $dec = shift;
                                    my $f = shift;
                                    return ($f || $f eq '0')
                                        ? sprintf("%.*g", $dec, $f)
                                        : 'NA'
                               },

        var_template            => "analysis_summary_integrated_ssa.html"
    };

    my $output = $self->process_template('master.html', $vars);

    return $output;
}

sub create_new_state
{
    my ($self) = @_;

    printf STDERR "%s: initialize_state called\n", scalar localtime;

    my $sid = $$ . time;

    my $filename = sprintf("%s/$sid", OPOSSUM_TMP_PATH);

    #
    # Create a working/results directory for all upload and output
    # results files as a sub-directory under the defined results root
    # directory.
    #
    my $results_dir = tempdir(DIR => ABS_HTDOCS_RESULTS_PATH);
    unless ($results_dir) {
        $self->_error("Error creating results directory $results_dir");
        return;
    }

    printf STDERR "%s: Initializing new state file %s with sid %s and results directory %s\n",
        scalar localtime,
        $filename,
        $sid,
        $results_dir;

    my $state = OPOSSUM::Web::State->new(
        __Fn            => $filename,
        -sid            => $sid,
        -results_dir    => $results_dir
    );

    unless ($state) {
        $self->_error("Error creating new state file $filename with sid $sid and results directory $results_dir");
        return;
    }

    my $species = $self->param('species');
    if ($species) {
        $state->species($species);
    }

    my $heading = sprintf "%s Analysis",
        ucfirst $state->species();
    $state->heading($heading);

    $state->debug(DEBUG);
    $state->title("CAGEd-oPOSSUM $heading");
    $state->bg_color_class(BG_COLOR_CLASS);

    $state->errors(undef);
    $state->warnings(undef);

    return $state;
}

sub load_existing_state
{
    my ($self, $sid) = @_;

    my $filename = sprintf("%s/$sid", OPOSSUM_TMP_PATH);

    printf STDERR "%s: Loading existing state with sid %s from file %s\n",
        scalar localtime,
        $sid,
        $filename;

    my $state = OPOSSUM::Web::State->new(__Fn => $filename);

    unless ($state) {
        $self->_error("Error loading state from file $filename");
        return;
    }

    return $state;
}

1;
