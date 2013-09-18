package CustomCAGESSA;

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
use constant BG_COLOR_CLASS => 'bgc_custom_cage';

use strict;

my $USER = $ENV{'USER'};

my $log_dir;
if (DEVEL_VERSION || ($USER && $USER ne 'nobody' && $USER ne 'apache')) {
    $log_dir = "/tmp";
} else {
    $log_dir = OPOSSUM_LOG_PATH;
}

my $log_file = "$log_dir/F5OP_custom_cage_ssa";
$log_file .= "_devel" if DEVEL_VERSION;
$log_file .= "_$USER" if $USER;
$log_file .= ".log";

open(LOG, ">>$log_file") || die "Error opening log file $log_file - $!\n";

carpout(\*LOG);

sub setup
{
    my $self = shift;

    #print STDERR "setup\n";
    
    $self->start_mode('input');
    $self->mode_param('rm');
    $self->run_modes(
        'input'             => 'input',
        'process'           => 'process',
#        'tfbs_details'      => 'tfbs_details',
#        'text_results'      => 'text_results',
#        'text_tfbs_details' => 'text_tfbs_details'
    );

    my $q = $self->query();
    
    my $sid = $q->param('sid');

    my $state;
    if ($sid) {
        #
        # Existing session. Load state from file.
        #
        my $filename = _session_tmp_file($sid);

        #printf STDERR "%s: loading state\n", scalar localtime;

        $state = OPOSSUM::Web::State->new(__Fn => $filename);
    } else {
        #
        # New session. Create new session ID and state object.
        #

        #printf STDERR "%s: creating state\n", scalar localtime;

        $sid = $$ . time;
        my $filename = _session_tmp_file($sid);

        $state = OPOSSUM::Web::State->new(
            -sid => $sid,
            __Fn => $filename
        );

        #printf STDERR "%s: initializing state\n", scalar localtime;

        $self->initialize_state($state);
    }

    $self->state($state);

    #printf STDERR sprintf("\n\noPOSSUM State:\n%s\n\n",
    #    Data::Dumper::Dumper($self->state())
    #);

    #printf STDERR "%s: connecting to oPOSSUM DB\n", scalar localtime;

    unless ($self->opossum_db_connect()) {
        return $self->error("Could not connect to FANTOM5 oPOSSUM DB");
    }
    
    #printf STDERR "\n\nrun mode = %s\n\n", $q->param('rm');
}


sub teardown
{
    my $self = shift;

    #print STDERR "teardown\n";

    if ($self->opdba()) {
        if ($self->opdba()->dbc()) {
            $self->opdba()->dbc()->disconnect();
        }
        $self->{-opdba} = undef;
    }

    my $state = $self->state();
    if ($state) {
        $state->dumper->Purity(1);
        $state->dumper->Deepcopy(1);
        $state->commit();
    }

    $self->_clean_tempfiles;
    $self->_clean_resultfiles;
}

sub input
{
    my $self = shift;

    #print STDERR "input\n";
    
    my $q = $self->query;
    #print STDERR "input query:\n"
    #    . Data::Dumper::Dumper($q);

    my $state = $self->state();

    my $species = $state->species() || $self->param('species');
    
    # This doesn't work properly, db_info methods seem to be lost when 
    # retrieving from state later on DJA 19/10/2010
    #$state->db_info($db_info);

    my $db_info = $self->fetch_db_info();

    my $tax_group         = $db_info->tax_group();
    my $min_ic            = $db_info->min_ic();
    my $max_flank_size    = $db_info->max_flank_size();
    my $max_upstream_bp   = $max_flank_size;
    my $max_downstream_bp = $max_flank_size;

    my @tax_groups = split /\s*,\s*/, $tax_group;
    my $num_tax_groups = scalar @tax_groups;

    $state->tax_groups(\@tax_groups);
    $state->num_tax_groups($num_tax_groups);

    #
    # Connect to JASPAR DB and retrieve TF info
    #
    $self->jaspar_db_connect();

    #my $tf_set = OPOSSUM::TFSet->new();
    my %core_tf_sets;
    my %pending_tf_sets;
    my %pbm_tf_sets;
    foreach my $tax_group (@tax_groups) {
        my $core_tf_set = $self->fetch_tf_set(
            -collection => 'CORE',
            -tax_group  => $tax_group,
            -min_ic     => $min_ic
        );

        $core_tf_sets{$tax_group} = $core_tf_set if $core_tf_set;

        #$tf_set->add_matrix_set($core_tf_set);
        
        my $pending_tf_set = $self->fetch_tf_set(
            -collection => 'PENDING',
            -tax_group  => $tax_group,
            -min_ic     => $min_ic
        );

        $pending_tf_sets{$tax_group} = $pending_tf_set;

        #$tf_set->add_matrix_set($pending_tf_set) if $pending_tf_set;
        
        unless ($species eq 'yeast') {
            my $pbm_tf_set = $self->fetch_tf_set(
                -collection => 'PBM',
                -tax_group  => $tax_group,
                -min_ic     => $min_ic
            );

            $pbm_tf_sets{$tax_group} = $pbm_tf_set;

            #$tf_set->add_matrix_set($pbm_tf_set) if $pbm_tf_set;
        }
    }

    #my $fam_tf_set;
    #unless ($species eq 'yeast' or $species eq 'worm') {
    #    $fam_tf_set = $self->fetch_tf_set(-collection => 'FAM');
    #}
    
    # so that the second db access won't be necessary 
    # why do I get tainted data error?
    #$state->core_tf_sets(\%core_tf_sets);
    #$state->pbm_tf_sets(\%pbm_tf_sets);
    #$state->pending_tf_sets(\%pending_tf_sets);
    #$state->fam_tf_set($fam_tf_set);

    #printf STDERR "\ncore_tf_set:\n"
    #    . Data::Dumper::Dumper($core_tf_set) . "\n\n";

    #printf STDERR "input_exp_ids:\n" . Data::Dumper::Dumper(\@input_exp_ids);

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
        bg_color_class          => $state->bg_color_class(),
        title                   => $state->title(),
        heading                 => $state->heading(),
        section                 => 'Select Analysis Parameters',
        version                 => VERSION,
        devel_version           => DEVEL_VERSION,
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
        max_t_experiments       => MAX_TARGET_EXPERIMENTS,
        max_t_tss               => MAX_TARGET_TSS,
        max_b_experiments       => MAX_BACKGROUND_EXPERIMENTS,
        max_b_tss               => MAX_BACKGROUND_TSS,
        dflt_b_num_rand_experiments  => DFLT_BG_NUM_RAND_EXPERIMENTS,
        dflt_t_tag_count        => DFLT_TARGET_TAG_COUNT,
        dflt_t_tpm              => DFLT_TARGET_TPM,
        dflt_b_tag_count        => DFLT_BACKGROUND_TAG_COUNT,
        dflt_b_tpm              => DFLT_BACKGROUND_TPM,
        sid                     => $state->sid(),
        species                 => $species,
        db_info                 => $db_info,
        tax_groups              => \@tax_groups,
        num_tax_groups          => $num_tax_groups,
        tax_group_list          => $tax_group_list,
        core_tf_sets            => \%core_tf_sets,
        pbm_tf_sets             => \%pbm_tf_sets,
        pending_tf_sets         => \%pending_tf_sets,
        #fam_tf_set              => $fam_tf_set,
        max_upstream_bp         => $max_upstream_bp,
        max_downstream_bp       => $max_downstream_bp,
        var_template            => "input_custom_cage_ssa.html"
    };

    my $output = $self->process_template('master.html', $vars);
    #print STDERR "input results:\n"
    #    . Data::Dumper::Dumper($output);

    return $output;
}

sub process
{
    my $self = shift;

    unless($self->process_cgi_query) {
        return $self->error();
    }

    my $state = $self->state;

    my $opdba = $self->opdba();

    #
    # This doesn't work properly, db_info methods seem to get lost
    # DJA 19/10/2010
    #
    #my $db_info = $state->db_info();

    my $dbia = $opdba->get_DBInfoAdaptor();
    my $db_info = $dbia->fetch_db_info();

    #my $tax_group         = $db_info->tax_group();
    my $dflt_min_ic       = $db_info->min_ic();
    my $max_flank_size    = $db_info->max_flank_size();
    my $max_upstream_bp   = $max_flank_size;
    my $max_downstream_bp = $max_flank_size;

    #
    # Call the analysis script
    #
    my $command = OPOSSUM_SCRIPTS_PATH . "/custom_cage_ssa.pl"
        . " -j " . $self->param('job_id')
        . " -m " . $self->param('email')
        . " -s " . $self->param('species')
        . " -dir " . $self->param('results_dir')
        . " -plot"
        . " -web";


    if (defined $self->param('t_regions_file')) {
        $command .= " -trf " . $self->param('t_regions_file');
        $command .= " -utrf " . $self->param('t_user_regions_file')
            if $self->param('t_user_regions_file');
    }

    if (defined $self->param('t_filter_regions_file')) {
        $command .= " -tfrf " . $self->param('t_filter_regions_file');
        $command .= " -utfrf " . $self->param('t_user_filter_regions_file')
            if $self->param('t_user_filter_regions_file');
    }

    if ($self->param('b_input_method') eq 'tss_regions') {
        $command .= " -brf " . $self->param('b_regions_file');
        $command .= " -ubrf " . $self->param('b_user_regions_file')
            if $self->param('b_user_regions_file');
    } elsif ($self->param('b_input_method') eq 'experiment') {
        my @exp_ids = map {$_->id} @{$self->param('b_experiments')};

        $command .= " -bxids " . join ',', @exp_ids;

        if (defined $self->param('b_tag_count')) {
            $command .= " -btc ".  $self->param('b_tag_count');
        }

        if (defined $self->param('b_tpm')) {
            $command .= " -btpm ". $self->param('b_tpm');
        }
    } elsif ($self->param('b_input_method') eq 'tss_names') {
        $command .= " -btssf " . $self->param('b_tss_names_file');

        if (defined $self->param('b_user_tss_names_file')) {
            $command .= " -ubtssf " . $self->param('b_user_tss_names_file');
        }
    #} elsif ($b_input_method eq 'random') {
    #    $command .= " -bnr $b_num_rand_genes";
    }

    if (defined $self->param('b_use_tss_only')) {
        $command .= " -bto";
    }

    if (defined $self->param('b_gene_ids_file')) {
        $command .= " -bgf " . $self->param('b_gene_ids_file');
        $command .= " -ubgf " . $self->param('b_user_gene_ids_file')
            if $self->param('b_user_gene_ids_file');
    }

    if (defined $self->param('b_filter_regions_file')) {
        $command .= " -bfrf " . $self->param('b_filter_regions_file');
        $command .= " -ubfrf " . $self->param('b_user_filter_regions_file')
            if $self->param('b_user_filter_regions_file');
    }

    #if (defined $tf_db) {
    #    $command .= " -tfdb $tf_db";
    #}

    if (defined $self->param('collection')) {
        $command .= " -co " . $self->param('collection');
    }


    my $tf_set;
    my $tf_ids = $self->param('tf_ids');
    if ($self->param('tf_select_method') eq 'paste') {
        $command .= " -tfmf " . $self->param('tfbs_matrix_file');
    } elsif ($self->param('tf_select_method') eq 'upload') {
        $command .= " -tfmf " . $self->param('tfbs_matrix_file');
    } elsif ($self->param('tf_select_method') eq 'specific') {
        $command .= " -tfids " . join ',', @$tf_ids;

        #
        # This is just to get the TF names for display on the analysis
        # summary page.
        #
        $self->jaspar_db_connect();

        $tf_set = $self->fetch_tf_set(
            -ID => $tf_ids
        );
    } elsif ($self->param('tf_select_method') eq 'min_ic') {
        if ($self->param('tax_groups')) {
            $command .= " -tax " . join ',', @{$self->param('tax_groups')};
        }

        if (defined $self->param('min_ic')) {
            $command .= " -ic " . $self->param('min_ic');
        }
    } else {
        return $self->error("No TFBS profiles selected");
    }

    if (defined $self->param('upstream_bp')) {
        $command .= " -up " . $self->param('upstream_bp');
    }

    if (defined $self->param('downstream_bp')) {
        $command .= " -dn " . $self->param('downstream_bp');
    }

    my $threshold = $self->param('threshold');
    #printf STDERR "threshold sent to command = $threshold\n";
    if (defined $threshold) {
        $command .= " -th $threshold";
    }

    if ($self->param('result_type') eq 'top_x_results') {
        $command .= " -n " . $self->param('num_display_results');
    } elsif ($self->param('result_type') eq 'significant_hits') {
        $command .= " -zcutoff " . $self->param('zscore_cutoff');
        $command .= " -fcutoff " . $self->param('fisher_cutoff');
    }

    if (defined $self->param('result_sort_by')) {
        $command .= " -sr " . $self->param('result_sort_by');
    }

    if ($self->param('tfbs_details')) {
        $command .= " -details";
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
        abs_htdocs_path     => ABS_HTDOCS_PATH,
        abs_cgi_bin_path    => ABS_CGI_BIN_PATH,
        rel_htdocs_path     => REL_HTDOCS_PATH,
        rel_cgi_bin_path    => REL_CGI_BIN_PATH,
        rel_htdocs_tmp_path => REL_HTDOCS_TMP_PATH,
        jaspar_url          => JASPAR_URL,
        section             => 'Analysis Results',
        title               => $state->title,
        heading             => $state->heading,
        bg_color_class      => $state->bg_color_class(),
        version             => VERSION,
        devel_version       => DEVEL_VERSION,
        result_retain_days  => REMOVE_RESULTFILES_OLDER_THAN,
        low_matrix_ic       => LOW_MATRIX_IC,
        high_matrix_ic      => HIGH_MATRIX_IC,
        low_matrix_gc       => LOW_MATRIX_GC,
        high_matrix_gc      => HIGH_MATRIX_GC,
        #low_seq_gc          => LOW_SEQ_GC,
        #high_seq_gc         => HIGH_SEQ_GC,
        species             => $state->species,
        job_id              => $self->param('job_id'),
        submitted_time      => $submitted_time,
        t_user_regions_file => $self->param('t_user_regions_file'),
        t_user_filter_regions_file
                            => $self->param('t_user_filter_regions_file'),
        b_user_regions_file => $self->param('b_user_regions_file'),
        b_user_filter_regions_file
                            => $self->param('b_user_filter_regions_file'),
        b_experiments       => $self->param('b_experiments'),
        b_tag_count         => $self->param('b_tag_count'),
        b_tpm               => $self->param('b_tpm'),
        b_user_tss_names_file => $self->param('b_user_tss_names_file'),
        upstream_bp         => $self->param('upstream_bp'),
        downstream_bp       => $self->param('downstream_bp'),
        tf_select_criteria  => $self->param('tf_select_criteria'),
        #t_cr_gc_content     => $t_cr_gc_content,
        #b_cr_gc_content     => $b_cr_gc_content,
        collection          => $self->param('collection'),
        tax_groups          => $self->param('tax_groups'),
        tf_ids              => $self->param('tf_ids'),
        tf_set              => $tf_set,
        min_ic              => $self->param('min_ic'),
        threshold           => $threshold,
        result_type         => $self->param('result_type'),
        num_display_results => $self->param('num_display_results'),
        zscore_cutoff       => $self->param('zscore_cutoff'),
        fisher_cutoff       => $self->param('fisher_cutoff'),
        result_sort_by      => $self->param('result_sort_by'),
        email               => $self->param('email'),

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

        var_template        => "analysis_summary_custom_cage_ssa.html"
    };

    my $output = $self->process_template('master.html', $vars);

    return $output;
}

sub process_cgi_query
{
    my $self = shift;

    my $state   = $self->state();
    my $q       = $self->query;

    my $opdba = $self->opdba();
    unless ($opdba) {
        $self->_error("Could not connect to FANTOM5-oPOSSUM database");
        return;
    }

    my $dbia = $opdba->get_DBInfoAdaptor();

    my $db_info = $dbia->fetch_db_info();

    #my $tax_group         = $db_info->tax_group();
    my $dflt_min_ic       = $db_info->min_ic();
    my $min_threshold     = $db_info->min_threshold();
    my $max_flank_size    = $db_info->max_flank_size();
    my $max_upstream_bp   = $max_flank_size;
    my $max_downstream_bp = $max_flank_size;

    my $email = $q->param('email');

    unless (defined $email) {
        $self->_error(
              "No e-mail address provided. An e-mail address is"
            . " required to send notification when your results are ready."
        );
        return;
    }

    $self->param('email', $email);

    #
    # Create a temporary working directory for all the temp. input files and
    # output results file as a sub-directory under the defined temp. dir.
    #
    my $results_dir = tempdir(DIR => ABS_HTDOCS_RESULTS_PATH);
    unless ($results_dir) {
        $self->_error("Error creating results directory $results_dir");
        return;
    }

    $self->param('results_dir', $results_dir);

    my $job_id = $results_dir;
    $job_id =~ s/.*\///;

    $self->param('job_id', $job_id);

    if (my $text = $self->parse_textbox('t_regions_text')) {
        my $filename = "$results_dir/t_regions.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local target TSS regions file $filename"
            );
            return;
        }

        $self->param('t_regions_file', $filename);
    } elsif (
        my $upload_filename
            = $self->parse_upload_filename('t_regions_file')
    ) {
        my $filename = "$results_dir/t_regions.txt";

        unless ($self->create_local_file_from_upload(
            $filename, 't_regions_file'
        )) {
            $self->_error(
                "Could not create local target TSS regions file $filename"
            );
            return;
        }

        $self->param('t_regions_file', $filename);
        $self->param('t_user_regions_file', $upload_filename);
    }

    if (my $text = $self->parse_textbox('t_filter_regions_text')) {
        my $filename = "$results_dir/t_filter_regions.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local target filter regions file $filename"
            );
            return;
        }

        $self->param('t_filter_regions_file', $filename);
    } elsif (
        my $upload_filename
            = $self->parse_upload_filename('t_filter_regions_file')
    ) {
        my $filename = "$results_dir/t_filter_regions.txt";

        unless ($self->create_local_file_from_upload(
            $filename, 't_filter_regions_file'
        )) {
            $self->_error(
                "Could not create local target filter regions file $filename"
            );
            return;
        }

        $self->param('t_filter_regions_file', $filename);
        $self->param('t_user_filter_regions_file', $upload_filename);
    }

    my $b_input_method;
    if (my $text = $self->parse_textbox('b_regions_text')) {
        my $filename = "$results_dir/b_regions.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local background TSS regions file $filename"
            );
            return;
        }

        $self->param('b_regions_file', $filename);

        $b_input_method = 'tss_regions';
    } elsif (
        my $upload_filename = $self->parse_upload_filename('b_regions_file')
    ) {
        my $filename = "$results_dir/b_regions.txt";

        unless (
            $self->create_local_file_from_upload($filename, 'b_regions_file')
        ) {
            $self->_error(
                "Could not create local background TSS regions file $filename"
            );
            return;
        }

        $self->param('b_regions_file', $filename);
        $self->param('b_user_regions_file', $upload_filename);

        $b_input_method = 'tss_regions';
    } elsif (my $text = $self->parse_textbox('b_tss_names_text')) {
        my $filename = "$results_dir/b_tss_names.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local background TSS names file $filename"
            );
            return;
        }

        $self->param('b_tss_names_file', $filename);

        $b_input_method = 'tss_names';
    } elsif (
        my $upload_filename = $self->parse_upload_filename('b_tss_names_file')
    ) {
        my $filename = "$results_dir/b_tss_names.txt";

        unless (
            $self->create_local_file_from_upload($filename, 'b_tss_names_file')
        ) {
            $self->_error(
                "Could not create local background TSS names file $filename"
            );
            return;
        }

        $self->param('b_tss_names_file', $filename);
        $self->param('b_user_tss_names_file', $upload_filename);

        $b_input_method = 'tss_names';
    } else {
        $b_input_method = 'experiment';

        my $expa = $opdba->get_ExperimentAdaptor();

        my $all_experiments = $expa->fetch_where();
        unless ($all_experiments) {
            $self->_error("Could not fetch experiments from DB");
            return;
        }

        my @b_experiments;
        foreach my $exp (@$all_experiments) {
            if ($q->param('b_' . $exp->FF_id)) {
                push @b_experiments, $exp;
            }
        }

        unless (@b_experiments) {
            $self->_error("No background experiments or TSSs specified");
            return;
        }

        $self->param('b_experiments', \@b_experiments);

        my $b_tag_count = $self->parse_textbox('b_tag_count');
        unless (defined $b_tag_count) {
            $b_tag_count = DFLT_BACKGROUND_TAG_COUNT;
        }

        $self->param('b_tag_count', $b_tag_count);

        my $b_tpm = $self->parse_textbox('b_tpm');
        unless (defined $b_tpm) {
            $b_tpm = DFLT_BACKGROUND_TPM;
        }

        $self->param('b_tpm', $b_tpm);
    }

    $self->param('b_input_method', $b_input_method);

    $self->param('b_use_tss_only', $q->param('b_use_tss_only'));

    if (my $text = $self->parse_textbox('b_gene_ids_text')) {
        my $filename = "$results_dir/b_gene_ids.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local background gene IDs file $filename"
            );
            return;
        }

        $self->param('b_gene_ids_file', $filename);
    } elsif (
        my $upload_filename
            = $self->parse_upload_filename('b_gene_ids_file')
    ) {
        my $filename = "$results_dir/b_gene_ids.txt";

        unless ($self->create_local_file_from_upload(
            $filename, 'b_gene_ids_file'
        )) {
            $self->_error(
                "Could not create local background gene IDs file $filename"
            );
            return;
        }

        $self->param('b_gene_ids_file', $filename);
        $self->param('b_user_gene_ids_file', $upload_filename);
    }

    if (my $text = $self->parse_textbox('b_filter_regions_text')) {
        my $filename = "$results_dir/b_filter_regions.txt";

        unless ($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local background filter regions file "
                . "$filename"
            );
            return;
        }

        $self->param('b_filter_regions_file', $filename);
    } elsif (my $upload_filename
            = $self->parse_upload_filename('b_filter_regions_file')
    ) {
        my $filename = "$results_dir/b_filter_regions.txt";

        unless (
            $self->create_local_file_from_upload(
                $filename, 'b_filter_regions_file'
            )
        ) {
            $self->_error(
                "Could not create local background filter regions file "
                . "$filename"
            );
            return;
        }

        $self->param('b_filter_regions_file', $filename);
        $self->param('b_user_filter_regions_file', $upload_filename);
    }

    #
    # XXX
    # No longer using the tf_select_method radio button...
    # XXX
    #
    #my $tf_select_method = $q->param('tf_select_method');
    #if (!$tf_select_method) {
    #    $self->_error("Unknown TFBS profiles select method");
    #    return;
    #}

    #
    # Divine the collection name from the tf_select_method parameter.
    # The tf_select_method parameter should be something like, 
    # e.g. core_min_ic, fam_specific, pbm etc.
    #
    #my $collection;
    #if ($tf_select_method =~ /(\w+?)_/) {
    #    $collection = uc $1;
    #} else {
    #    $collection = uc $tf_select_method;
    #}

    #$self->param('collection', $collection);

    #my $tf_select_criteria;
    #if ($tf_select_method =~ /min_ic/) {
    #    $tf_select_criteria = 'min_ic';
    #} elsif ($tf_select_method =~ /specific/) {
    #    $tf_select_criteria = 'specific';
    #} else {
    #    $tf_select_criteria = 'all';
    #}

    #$self->param('tf_select_criteria', $tf_select_criteria);

    my $collection;
    my $tf_select_method;
    if (my $text = $self->parse_textbox('matrix_paste_text')) {
        my $filename = "$results_dir/matrices.txt";

        unless($self->create_local_file_from_text($filename, $text)) {
            $self->_error(
                "Could not create local TFBS profile matrices file $filename"
            );
            return;
        }

        $self->param('tfbs_matrix_file', $filename);

        $tf_select_method = 'paste';
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
            return;
        }

        $self->param('tfbs_matrix_file', $filename);
        $self->param('user_tfbs_matrix_file', $upload_filename);

        $tf_select_method = 'upload';
    } else {
        $collection = 'CORE';

        my @tf_ids;
        if ($collection eq 'CORE') {
            push @tf_ids, $q->param('core_tfs');
        } elsif ($collection eq 'PBM') {
            push @tf_ids, $q->param('pbm_tfs');
        } elsif ($collection eq 'PENDING') {
            push @tf_ids, $q->param('pending_tfs');
        }

        if (scalar @tf_ids > 0) {
            $tf_select_method = 'specific';
            $self->param('tf_ids', \@tf_ids);
        } else {
            $tf_select_method = 'min_ic';

            my $min_ic;
            my @tax_groups;
            my $num_tax_groups = $state->num_tax_groups();

            if ($collection eq 'CORE') {
                $min_ic = $q->param('core_min_ic');
                if ($num_tax_groups > 1) {
                    @tax_groups = $q->param("core_tax_groups");
                } else {
                    @tax_groups = @{$state->tax_groups()};
                }
            } elsif ($collection eq 'PBM') {
                $min_ic = $q->param('pbm_min_ic');
                if ($num_tax_groups > 1) {
                    @tax_groups = $q->param("pbm_tax_groups");
                } else {
                    @tax_groups = @{$state->tax_groups()};
                }
            } elsif ($collection eq 'PENDING') {
                $min_ic = $q->param('pending_min_ic');
                if ($num_tax_groups > 1) {
                    @tax_groups = $q->param("pending_tax_groups");
                } else {
                    @tax_groups = @{$state->tax_groups()};
                }
            }

            if (!defined $min_ic || $min_ic < $dflt_min_ic) {
                $min_ic = $dflt_min_ic;
            }

            $self->param('min_ic', $min_ic);

            if ($collection eq 'CORE' && scalar @tax_groups == 0) {
                $self->_error("No JASPAR CORE collection tax groups selected");
                return;
            }

            $self->param('tax_groups', \@tax_groups) if @tax_groups;
        }
    }

    $self->param('collection', $collection);
    $self->param('tf_select_method', $tf_select_method);

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
   
    $self->param('threshold', $threshold);
    #printf STDERR "threshold set to $threshold\n";

    my $upstream_bp = $self->parse_textbox('upstream_bp');
    if (defined $upstream_bp) {
        $upstream_bp = $max_upstream_bp if $upstream_bp > $max_upstream_bp;
        $upstream_bp = 0 if $upstream_bp < 0;
    } else {
        $upstream_bp = DFLT_UPSTREAM_BP;
    }

    $self->param('upstream_bp', $upstream_bp);

    my $downstream_bp = $self->parse_textbox('downstream_bp');
    if (defined $downstream_bp) {
        $downstream_bp = $max_downstream_bp
            if $downstream_bp > $max_downstream_bp;
        $downstream_bp = 0 if $downstream_bp < 0;
    } else {
        $downstream_bp = DFLT_DOWNSTREAM_BP;
    }
    
    $self->param('downstream_bp', $downstream_bp);

    my $result_type = $q->param('result_type');
    $self->param('result_type', $result_type);

    if ($result_type eq 'top_x_results') {
        $self->param('num_display_results', $q->param('num_display_results'));
    } elsif ($result_type eq 'significant_hits') {
        $self->param('zscore_cutoff', $q->param('zscore_cutoff'));
        $self->param('fisher_cutoff', $q->param('fisher_cutoff'));
    }

    $self->param('result_sort_by', $q->param('result_sort_by'));

    $self->param('tfbs_details', $q->param('tfbs_details'));

    return 1;
}

sub initialize_state
{
    my ($self, $state) = @_;

    my $species = $self->param('species');

    unless ($species) {
        return $self->error("Species is undefined");
    }
    $state->species($species);

    my $heading = sprintf "%s Custom CAGE Single Site Analysis",
        ucfirst $state->species();
    $state->heading($heading);

    $state->debug(DEBUG);
    $state->title("FANTOM5 oPOSSUM $heading");
    $state->bg_color_class(BG_COLOR_CLASS);

    $state->errors(undef);
    $state->warnings(undef);
}

1;
