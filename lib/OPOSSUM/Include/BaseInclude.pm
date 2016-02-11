=head1 NAME

 OPOSSUM::Include::BaseInclude.pm

=head1 SYNOPSIS

=head1 DESCRIPTION

  Contains all options and routines that are common to all the analyses.

=head1 AUTHOR

  Andrew Kwon & David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia

  E-mail: tjkwon@cmmt.ubc.ca, dave@cmmt.ubc.ca

=cut

use strict;

use Bio::Seq;

use OPOSSUM::Opt::BaseOpt;
use OPOSSUM::Web::Opt::BaseOpt;

#use Data::Dumper;    # for debugging only
use Carp;

use File::Temp qw/ tempfile /;

use Template;
use CGI;

#use TFBS::DB::JASPAR5;
use TFBS::DB::JASPAR;

use OPOSSUM::DBSQL::DBAdaptor;
use OPOSSUM::TFSet;
use OPOSSUM::TFBS;
use OPOSSUM::Analysis::Counts;
use OPOSSUM::TSS;

use Bio::SeqIO;


#
# Get log file
#
sub get_log_filename
{
	my ($analysis_type, $results_dir) = @_;

	#my $USER = $ENV{'USER'};
    #
	#my $log_dir;
	#if ($USER && $USER ne 'nobody' && $USER ne 'apache') {
	#	$log_dir = "/tmp";
	#} else {
	#	$log_dir = $results_dir;
	#}

    my $log_dir = $results_dir;

	my $log_file = "$log_dir/$analysis_type";

	#$log_file .= "_devel" if DEVEL_VERSION;
	#$log_file .= "_$USER" if $USER;

	$log_file .= ".log";

	return $log_file;
}


#
# Connect to JASPAR database
#
sub jaspar_db_connect
{
    my ($tf_db) = @_;
    
    my $jdb = TFBS::DB::JASPAR7->connect(
        "dbi:mysql:" . $tf_db . ":" . JASPAR_DB_HOST,
        JASPAR_DB_USER,
        JASPAR_DB_PASS
    );

    return $jdb;
}

sub read_gene_ids_from_file
{
    my ($file, $job_args) = @_;

    return read_ids_from_file($file, $job_args);
}

sub read_tf_ids_from_file
{
    my ($file, $job_args) = @_;

    return read_ids_from_file($file, $job_args);
}

#
# Generic read IDs (gene or TF IDs) from file.
#
sub read_ids_from_file
{
    my ($file, $job_args) = @_;

    my $text = read_file($file, $job_args);

    my $ids = parse_id_text($text);

    return $ids;
}

sub read_file
{
    my ($file, $job_args) = @_;

    unless (open(FH, $file)) {
        fatal("Could not open file $file", $job_args);
        return;
    }

    my $text = "";
    while (my $line = <FH>) {
        $text .= $line;
    }

    close(FH);

    return $text;
}

#
# Read TSS (tag cluster) names from file. The file may be either a
# simple file containing just TSS names (one per line) or a BED file.
#
sub read_tss_names_from_file
{
    my ($file, $job_args) = @_;

    unless (open(FH, $file)) {
        fatal("Could not open TSS IDs file $file", $job_args);
        return;
    }

    my @tss_names;
    my %included;
    while (my $line = <FH>) {
        chomp $line;

        my $tss_name;
        if ($line =~ /^\s*chr(\w+):(\d+)\.\.(\d+)\,([+-])/) {
            #
            # Simple file containing just FANTOM5 tag cluster IDs (or at
            # least each line begins with tag cluster ID).
            #
            # A properly formatted FANTOM5 tag cluster ID is of the format,
            # e.g.:
            #   chr10:100005881..100005885,+
            #

            $tss_name = "chr$1:$2..$3,$4";

        } elsif ($line =~ /^\s*chr\w+\s+\d+\s+\d+/) {
            #
            # BED file format
            #

            my @data = split /\s+/, $line;

            $tss_name = $data[3];

            unless ($tss_name =~ /^chr(\w+):(\d+)\.\.(\d+)\,([+-])$/) {
                warning(
                      "BED file contains inproperly formatted FANTOM5 cluster"
                    . " IDs in name field\n", $job_args
                );

                #
                # Create TSS name from the other fields in the BED file.
                #
                # XXX
                # BED file specification is for 0-based start. Should we
                # add 1 to the start to create the tag cluster name?
                # XXX
                #
                $tss_name = sprintf "chr%s:%d..%d,%s",
                    $data[0], $data[1], $data[2], $data[5];
            }
        }

        unless ($included{$tss_name}) {
            push @tss_names, $tss_name;

            $included{$tss_name} = 1;
        }
    }

    close(FH);

    return @tss_names ? \@tss_names : undef;
}

#
# Read regions from a BED file. This only requires that the chromosom, start
# and end columns are defined.
#
sub read_regions_from_file
{
    my ($file, $job_args) = @_;

    unless (open(FH, $file)) {
        fatal("Could not open regions BED file $file", $job_args);
        return;
    }

    my @regions;
    while (my $line = <FH>) {
        chomp $line;

        next unless $line =~ /^\s*(\w+)\s+(\d+)\s+(\d+)/;

        my $chrom  = $1;
        my $start  = $2;
        my $end    = $3;

        if ($chrom =~ /chr(\w+)/) {
            $chrom = $1;
        }

        #
        # Note: BED specification is for 0-based start coordinates.
        #
        $start += 1;

        push @regions, OPOSSUM::SearchRegion->new(
            -chrom      => $chrom,
            -start      => $start,
            -end        => $end,
        );
    }

    close(FH);

    return @regions ? \@regions : undef;
}

#
# Read TSS regions from a BED file.
#
sub read_tss_regions_from_file
{
    my ($file, $job_args) = @_;

    unless (open(FH, $file)) {
        fatal("Could not open regions BED file $file", $job_args);
        return;
    }

    my @regions;
    my $id = 1;
    while (my $line = <FH>) {
        chomp $line;

        #
        # XXX
        # We need the strand so we can apply flanking regions properly
        # but should we be forgiving about the strand (and name, score)
        # columns and if strand is not provided, assume +ve strand?
        # XXX
        #
        next unless $line
            =~ /^\s*(\w+)\s+(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+([+-.])/;

        my $chrom  = $1;
        my $start  = $2;
        my $end    = $3;
        my $name   = $4;
        my $score  = $5;    # not used
        my $strand = $6;

        if ($chrom =~ /chr(\w+)/) {
            $chrom = $1;
        }

        #
        # Note: BED specification is for 0-based start coordinates.
        #
        $start += 1;

        unless ($name) {
            #
            # Construct CAGE tag cluster ID in standard FANTOM5 format,
            # e.g. chr10:100000569..100000577,+
            #
            $name = "chr$chrom:$start..$end,$strand";
        }

        push @regions, OPOSSUM::TSS->new(
            -id         => $id++,
            -chrom      => $chrom,
            -start      => $start,
            -end        => $end,
            -name       => $name,
            -strand     => $strand
        );
    }

    close(FH);

    return @regions ? \@regions : undef;
}

sub parse_id_text
{
    my $text = shift;

    #
    # Strip anything out that is NOT a part of the ID or a valid
    # separator
    #
    $text =~ s/[^\w\.\/_\-,;:\s\n]+//g;

    #
    # Strip out leading and trailing separators
    #
    $text =~ s/^[,;:\s\n]+//g;
    $text =~ s/[,;:\s\n]+$//g;

    my @raw_list = split /[,;:\n\s]+/, $text;

    my %included;
    my @unique_list;
    if (@raw_list) {
        foreach my $id (@raw_list) {
            unless ($included{$id}) {
                push @unique_list, $id;
                $included{$id} = 1;
            }
        }
    }

    return @unique_list ? \@unique_list : undef;
}

sub revcom
{
	my ($seq) = @_;

	my $rc_seq = reverse $seq;

	$rc_seq =~ tr/[acgtACGT]/[tgcaTGCA]/;

	return $rc_seq;
}


#
# With JASPAR 2016, profiles may have multiple values for such things
# as class and family (and maybe others). Determine if given TF attribute is
# a scalar or array ref and stringify if the latter.
#
# If the TF is some sort of dimer (trimer etc.) indicated by '::' in the name,
# then for class and family use '::' as the concatenated string delimeter,
# otherwise use ', '.
# NOTE that there is actually no guarantee that the class and family attribute
# values were entered into the JASPAR DB in the same order as the dimer name
# appears so it's possible that the resulting stringified name may be a bit
# misleading...
#
sub stringify_tf_attribute
{
    my ($tf, $attr) = @_;

    my $val;
    if ($attr eq 'class') {
        # class has it's own method
        $val = $tf->class();
    } else {
        # generic tag/values (includes 'family' attribute)
        $val = $tf->tag($attr);
    }

    my $is_dimer = 0;
    if ($tf->name =~ /::/) {
        $is_dimer = 1;
    }

    my $str_val;
    if (ref $val eq 'ARRAY') {
        #
        # If the TF is some sort of dimer and we are concatenating values for
        # class and family then user the conventional dimer delimeter '::',
        # otherwise use a comma delimeter.
        #
        if ($is_dimer && $attr eq 'class' || $attr eq 'family') {
            $str_val = join('::', @$val);
        } else {
            $str_val = join(', ', @$val);
        }
    } else {
        $str_val = $val;
    }

    if ($attr eq 'class') {
        # class has it's own method
        $tf->class($str_val);
    } else {
        # generic tag/values (includes 'family' attribute)
        $tf->tag($attr, $str_val);
    }

    return $tf;
}

#
# With JASPAR 2016, profiles may have multiple values for such things
# as class and family (and maybe others). For the given TFSet process each
# TF and stringify any of the given attributes which may be stored as array
# refs.
#
sub stringify_tf_set_attributes
{
    my ($tf_set, @attrs) = @_;

    my $tf_ids = $tf_set->ids();

    foreach my $tf_id (@$tf_ids) {
        my $tf = $tf_set->get_tf($tf_id);
        foreach my $attr (@attrs) {
            stringify_tf_attribute($tf, $attr);
        }
    }
}


sub read_matrices
{
    my ($file, $job_args) = @_;

    unless (open(FH, $file)) {
        fatal("Could not open matrix file $file - $!", $job_args);
        return;
    }

    my $matrix_set = TFBS::MatrixSet->new();

    my $id              = '';
    my $name            = '';
    my $matrix_string   = '';
    my $line_count      = 0;
    my $matrix_count    = 0;
    while (my $line = <FH>) {
        chomp $line;

        next if !$line;

        if ($line =~ /^>\s*(\S+)\s+(\S+)/) {
            $id = $1;
            $name = $2;
        } elsif ($line =~ /^>\s*(\S+)/) {
            $name = $1;
        } else {
            if ($line =~ /^\s*[ACGT]\s*\[\s*(.*)\s*\]/) {
                # line of the form: A [ # # # ... # ]
                $matrix_string .= "$1\n";
            } elsif ($line =~ /^\s*\d+/) {
                # line of the form: # # # ... #
                $matrix_string .= "$line\n";
            } else {
                next;
            }
            $line_count++;

            if ($line_count == 4) {
                #$id = sprintf "matrix%d", $matrix_count + 1 unless $id;
                #
                #unless ($name) {
                #    $name = $id;
                #}
                unless ($id) {
                    $id = $name;
                }

                #
                # Simplistic determination of whether matrix looks more like
                # a PWM than a PFM.
                #
                my $matrix_type = 'PFM';
                if ($matrix_string =~ /\d*\.\d+/) {
                    $matrix_type = 'PWM';
                }

                my $matrix;
                if ($matrix_type eq 'PWM') {
                    $matrix = TFBS::Matrix::PWM->new(
                        -ID           => $id,
                        -name         => $name,
                        -matrixstring => $matrix_string
                    );
                } else {
                    $matrix = TFBS::Matrix::PFM->new(
                        -ID           => $id,
                        -name         => $name,
                        -matrixstring => $matrix_string
                    );
                }

                $matrix_set->add_matrix($matrix);

                $matrix_string = '';
                $id   = '';
                $name = '';
                $line_count = 0;
                $matrix_count++;
            }
        }
    }
    close(FH);

    return $matrix_set;
}

=head2 matrix_set_compute_gc_content

 Title   : matrix_set_compute_gc_content

 Function: Compute the GC content of each of the matrices in a set of TFBS
           matrices and set the matrix tag value 'gc_content' to the value
           computed.

 Args    : matrix_set   - a TFBS::MatrixSet object

 Returns : 1 on success, otherwise undef.

=cut

sub matrix_set_compute_gc_content
{
    my ($matrix_set, $job_args) = @_;

    unless ($matrix_set && $matrix_set->size) {
        return undef;
    }

    my $iter = $matrix_set->Iterator;
    while (my $matrix = $iter->next) {
        my $gc_content = matrix_compute_gc_content($matrix, $job_args);

        if (defined $gc_content) {
            $matrix->tag('gc_content', $gc_content);
        }
    }

    return 1;
}

=head2 matrix_compute_gc_content

 Title   : matrix_compute_gc_content

 Function: Compute the GC content of a TFBS matrix.

 Args    : pfm  - a TFBS::Matrix::PFM object

 Returns : On success, the GC content of the matrix in the range 0 - 1,
           otherwise undef.

=cut

sub matrix_compute_gc_content
{
    my ($pfm, $job_args) = @_;

    unless ($pfm->isa("TFBS::Matrix::PFM")) {
        warning("Cannot compute GC content for non-PFM matrix", $job_args); 
        return undef;
    }

    my $matrix = $pfm->matrix();

    my $gc_count = 0;
    my $total_count = 0;
    my $row_num = 0;
    foreach my $row (@$matrix) {
        $row_num++;
        foreach my $val (@$row) {
            if ($row_num == 2 || $row_num == 3) {
                $gc_count += $val;
            }

            $total_count += $val;
        }
    }

    my $gc_content = $gc_count / $total_count;

    return $gc_content;
}

#
# XXX Fix up to make consistent with the new method of filtering employed by
# the compute_tfbss.pl build script but we can't use this method directly on
# a TFBS::SiteSet object (because of the need to delete sites).
#
# This may have to be revisited for more sophisticated filtering.
# Take a TFBS::SiteSet where each site in the set corresponds to the
# same transcription factor and filter overlapping sites such that only
# the highest scoring site of any mutually overlapping sites is kept.
# In the event that sites equally, the first site is kept, i.e.
# bias is towards the site with the lowest starting position.
#
sub filter_overlapping_sites
{
    my ($siteset) = @_;

    return if !defined $siteset || $siteset->size == 0;

    my $filtered_set = TFBS::SiteSet->new();

    my $iter = $siteset->Iterator(-sort_by => 'start');
    my $prev_site = $iter->next;
    if ($prev_site) {
        while (my $site = $iter->next) {
            if ($site->overlaps($prev_site)) {
                #
                # Bias is toward the site pair with the lower start
                # site (i.e. if the scores are equal).
                # 
                if ($site->score > $prev_site->score) {
                    $prev_site = $site;
                }
            } else {
                $filtered_set->add_site($prev_site);
                $prev_site = $site;
            }
        }
        $filtered_set->add_site($prev_site);
    }

    return $filtered_set;
}

sub tfbss_to_conserved_tfbss
{
    my ($sites, $cluster_id, $seq_id) = @_;
    
    return if !defined $sites || scalar($sites) == 0;
    
    my @ctfbss;
    foreach my $site (@$sites)
    {
        my $ctfbs = OPOSSUM::TFBS->new(
            -tf_id      => $cluster_id,
            -gene_id    => $seq_id,
            -start      => $site->start,
            -end        => $site->end,
            -strand     => $site->strand,
            -score      => $site->score,
            -rel_score  => $site->rel_score,
            -seq        => $site->seq->seq
        );
        
        push @ctfbss, $ctfbs;
    }
    
    return @ctfbss ? \@ctfbss : undef;
}


sub process_template
{
    my ($template_name, $vars, $job_args) = @_;

    my $config = {
        ABSOLUTE        => 1,
        INCLUDE_PATH    => ABS_HTDOCS_TEMPLATE_PATH . "/",  # or list ref
        INTERPOLATE     => 1,   # expand "$var" in plain text
        POST_CHOMP      => 1,   # cleanup whitespace
        #PRE_PROCESS     => 'header',   # prefix each template
        EVAL_PERL       => 1,   # evaluate Perl code blocks
        DEBUG           => DEBUG
    };

    my $string   = '';
    my $template = Template->new($config);
    my $input    = ABS_HTDOCS_TEMPLATE_PATH . "/$template_name";

    unless ($template->process($input, $vars, \$string)) {
        fatal(
            "Error processing template $input\n" . $template->error() . "\n\n",
            $job_args
        );
        return;
    }

    return $string;
}

sub send_email
{
    my ($args) = @_;

    my $job_id = $args->{-job_id};
    my $heading = $args->{-heading};
    my $email = $args->{-email};
    my $web = $args->{-web};
    my $results_dir = $args->{-results_dir};
    my $rel_results_dir = $args->{-rel_results_dir};
    my $user_t_exp_file = $args->{-user_t_exp_file};
    my $user_b_exp_file = $args->{-user_b_exp_file};
    my $t_exp_ids = $args->{-t_exp_ids};
    my $t_exp_ff_ids = $args->{-t_exp_ff_ids};
    my $b_exp_ids = $args->{-b_exp_ids};
    my $b_exp_ff_ids = $args->{-b_exp_ff_ids};
    my $t_search_regions = $args->{-t_search_regions};
    my $b_search_regions = $args->{-b_search_regions};
    my $t_tss = $args->{-t_tss};
    my $b_tss = $args->{-b_tss};
    my $tf_db = $args->{-tf_db};
    my $collections_str = $args->{-collections_str};
    my $tax_groups_str = $args->{-tax_groups_str};
    my $fam_file = $args->{-families};
    my $tf_ids = $args->{-tf_ids};
    my $tf_names = $args->{-tf_names};
    my $min_ic = $args->{-min_ic};
    my $threshold = $args->{-threshold};
    my $flank_size = $args->{-flank_size};
    my $z_cutoff = $args->{-z_cutoff};
    my $f_cutoff = $args->{-f_cutoff};
    my $ks_cutoff = $args->{-ks_cutoff};
    my $num_results = $args->{-num_results};
    my $sort_by = $args->{-sort_by};
    my $logger = $args->{-logger};

    return if !$email;

    my $t_sr_num = scalar @$t_search_regions
        if $t_search_regions && $t_search_regions->[0];

    my $b_sr_num = scalar @$b_search_regions
        if $b_search_regions && $b_search_regions->[0];

    my $t_tss_num = scalar @$t_tss if $t_tss && $t_tss->[0];

    my $b_tss_num = scalar @$b_tss if $b_tss && $b_tss->[0];


    my $cmd = "/usr/sbin/sendmail -i -t";

    my $msg .= "\n";
    $msg = "Your CAGEd-oPOSSUM $heading results are now available at\n\n";
    if ($web) {
        my $results_url = sprintf "%s%s/%s",
            WEB_SERVER_URL,
            "$rel_results_dir",
            RESULTS_HTDOCS_FILENAME;
        $msg .= "$results_url\n\n";
    } else {
        $msg .= "$results_dir\n\n";
    }
    
    $msg .= "\nAnalysis Summary\n\n";

    $msg .= "Job ID:                                    $job_id\n";

    $msg .= "Target experiment file:                    $user_t_exp_file\n"
        if $user_t_exp_file;
    $msg .= "Number of target tag clusters:             $t_tss_num\n"
        if $t_tss_num;
    $msg .= "Number of target tag cluster regions:      $t_sr_num\n"
        if $t_sr_num;
    $msg .= "Background experiment file:                $user_b_exp_file\n"
        if $user_b_exp_file;
    $msg .= "Number of background tag clusters:         $b_tss_num\n"
        if $b_tss_num;
    $msg .= "Number of background tag cluster regions:  $b_sr_num\n"
        if $b_sr_num;

    if ($tf_db) {
        $msg .= "TFBS profile source:                       JASPAR\n";
        $msg .= "JASPAR collection:                         $collections_str\n"
            if $collections_str;
        $msg .= "Taxonomic supergroups:                     $tax_groups_str\n"
            if $tax_groups_str;
        $msg .= "TFs:                                       $tf_names\n"
            if $tf_names;
        $msg .= "Min. IC                                    $min_ic\n"
            if $min_ic;
    } else {
        $msg .= "TFBS profile source:                       User supplied matrices\n";
    }

    $msg .= "TFBS matrix score threshold:               $threshold\n" if $threshold;

    $msg .= "Results returned:                          ";

    if (defined $z_cutoff || defined $f_cutoff || defined $ks_cutoff) {
        $msg .= "All results with a z-score >= $z_cutoff\n";
        if (defined $f_cutoff) {
            $msg .= " and a Fisher score >= $f_cutoff\n";
        }
        if (defined $ks_cutoff) {
            $msg .= " and a KS p-value <= $ks_cutoff\n";
        }
    } else {
        if (!$num_results || $num_results =~ /^all/i) {
            $msg .= "All results";
        } else {
            $msg .= "Top $num_results results";
        }
        
        if (defined $sort_by) {
            $msg .= " sorted by";
            if ($sort_by =~ /zscore/) {
                $msg .= " z-score\n";
            } elsif ($sort_by =~ /fisher/) {
                $msg .= " Fisher score\n";
            } elsif ($sort_by =~ /ks/) {
                $msg .= " KS p-value\n";
            }
        }
    }

    $msg .= "\n";
    $msg .= "\nYour analysis results will be kept on our server for "
            . REMOVE_RESULTFILES_OLDER_THAN . " days.\n";
    $msg .= "\nThank-you,\n";
    $msg .= "The CAGEd-oPOSSUM development team\n";
    $msg .= ADMIN_EMAIL . "\n";

    if (!open(SM, "|" . $cmd)) {
        $logger->error("Could not open sendmail - $!");
        return;
    }

    printf SM "To: %s\n", $email;
    printf SM "From: %s\n", ADMIN_EMAIL;
    print SM "Subject: CAGEd-oPOSSUM $heading results\n\n";
    print SM "$msg" ;

    close(SM);
}

sub fatal
{
    my ($error, $args) = @_;

    my $job_id          = $args->{-job_id};
    my $heading         = $args->{-heading};
    my $email           = $args->{-email};
    my $logger          = $args->{-logger};
    my $web             = $args->{-web};
    
    $error = 'Unknown error' unless $error;

    #
    # If we have a logger defined, log error.
    #
    $logger->error("$error") if $logger;

    if ($web) {
        #
        # If called in web context send e-mails to admin and user (if user
        # email set).
        #
        my $cmd = "/usr/sbin/sendmail -i -t";

        my $msg = "CAGEd-oPOSSUM $heading failed\n";
        $msg .= "\nJob ID: $job_id\n";
        $msg .= "\nError: $error\n";

        if (open(SM, "|" . $cmd)) {
            printf SM "To: %s\n", ADMIN_EMAIL;
            print SM "Subject: CAGEd-oPOSSUM $heading fatal error\n\n";
            print SM "$msg" ;
            print SM "\nUser e-mail: $email\n" if $email;

            close(SM);
        } else {
            $logger->error("Could not open sendmail - $!") if $logger;
        }

        if ($email) {
            if (open(SM, "|" . $cmd)) {
                printf SM "To: %s\n", $email;
                printf SM "From: %s\n", ADMIN_EMAIL;
                print SM "Subject: CAGEd-oPOSSUM $heading fatal error\n\n";
                print SM "$msg" ;

                close(SM);
            } else {
                $logger->error("Could not open sendmail - $!") if $logger;
            }
        }

        croak "$error\n";
    } else {
        #
        # Otherwise print usage message.
        #
        pod2usage(
            -msg        => "$error\n",
            -verbose    => 1
        );
    }
}

sub warning
{
    my ($error, $args) = @_;

    my $logger = $args->{-logger};
    
    $error = 'Unknown error' unless $error;

    $logger->warn("$error") if $logger;

    carp "$error\n";
}

sub opossum_db_connect
{
    my ($species) = @_;
    
    my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);
    
    my $opdba = OPOSSUM::DBSQL::DBAdaptor->new(
        -host     => OPOSSUM_DB_HOST,
        -dbname   => $db_name,
        -user     => OPOSSUM_DB_USER,
        -password => OPOSSUM_DB_PASS
    );
    
    return $opdba;
}

sub write_search_regions
{
    my ($search_regions, $outfile, $format) = @_;
    
    unless (open(FH, ">$outfile")) {
        return;
    }

    if ($format && lc $format eq 'bed') {
        foreach my $sr (@$search_regions) {
            printf FH "chr%s\t%d\t%d\n",
                $sr->chrom,
                $sr->start - 1,
                $sr->end;
        }
    } else {
        foreach my $sr (@$search_regions) {
            printf FH "%d\tchr%s:%d-%d\n",
                $sr->id,
                $sr->chrom,
                $sr->start,
                $sr->end;
        }
    }

    close(FH);
}

sub read_sequences
{
    my ($file, $job_args) = @_;

    my $seqIO = Bio::SeqIO->new(-file => $file, -format => "fasta");

    unless ($seqIO) {
        fatal("Error opening fasta sequence file $file", $job_args);
    }

    my @seqs;
    while (my $seq = $seqIO->next_seq()) {
        push @seqs, $seq;
    }

    return @seqs ? \@seqs : undef;
}

sub write_sequences
{
    my ($seqs, $outfile) = @_;
    
    my $seqIO = Bio::SeqIO->new(-file => ">$outfile", -format => 'fasta');

    foreach my $seq (@$seqs) {
        $seqIO->write_seq($seq);
    }
}

sub fetch_tss_by_names_file
{
    my ($tssa, $torb, $tss_names_file, $tss_only, $gene_ids, $job_args
    ) = @_;

    my $logger = $job_args->{-logger};

    $logger->info("Reading $torb TSS names from file $tss_names_file");

    my $tss_names = read_tss_names_from_file($tss_names_file, $job_args);

    unless ($tss_names) {
        fatal(
            "No $torb TSS names read from file $tss_names_file", $job_args
        );
    }

    my $num_tss_names = scalar @$tss_names;

    $logger->info(
        "Read $num_tss_names $torb TSS names from $tss_names_file
    ");

    my $tss = $tssa->fetch(
        -names      => $tss_names,
        -is_tss     => $tss_only,
        -gene_ids   => $gene_ids
    );

    unless ($tss) {
        fatal(
              "No TSSs fetched from DB corresponding to TSS names in file"
            . " $tss_names_file", $job_args
        );
    }

    my $num_tss = scalar @$tss;

    $logger->info("Fetched $num_tss $torb CAGE peaks from DB");

    #
    # Check for missing TSSs - TSSs fetched from DB is less than the
    # number of unique TSS names read from the file. This can happen
    # normally if any filters are on.
    #
    unless ($tss_only || $gene_ids) {
        if ($num_tss < $num_tss_names) {
            warning(
                  "The number of $torb CAGE peaks fetched from DB ($num_tss)"
                . " is less than the number of TSS names provided in the TSS"
                . " names file $tss_names_file ($num_tss_names)", $job_args
            );
        }
    }

    return $tss;
}

sub compute_search_region_length
{
    my ($search_regions) = @_;

    my $length = 0;
    foreach my $sr (@$search_regions) {
        $length += $sr->length;
    }

    return $length;
}

sub compute_total_sequences_length
{
    my ($seqs) = @_;

    my $length = 0;
    foreach my $seq (@$seqs) {
        $length += $seq->length();
    }

    return $length;
}

#
# Foreach search region and TF combination, count the number binding sites
# and store them in an OPOSSUM::Analysis::Counts object.
#
# While doing this, for each TFBS set the search region which the TFBS falls
# into.
#
#
sub compute_search_region_tfbs_counts
{
    my ($search_regions, $tf_ids, $tfbss) = @_;

    my @sr_ids = map {$_->id} @$search_regions;

    my $counts = OPOSSUM::Analysis::Counts->new(
        -seq_ids    => \@sr_ids,
        -tf_ids     => $tf_ids
    );

    my %sr_tf_sites;
    foreach my $sr (@$search_regions) {
        my $sr_id = $sr->id;

        my %tf_sites;
        foreach my $tfbs (@$tfbss) {
            next if ($sr->chrom ne $tfbs->chrom);

            #
            # TFBS must fall completely within search region, not just
            # overlap it.
            #
            if ($tfbs->start >= $sr->start && $tfbs->end <= $sr->end) {
                my $tf_id = $tfbs->tf_id;

                #
                # Set the search region ID of this TFBS
                # Not really used?
                #
                $tfbs->search_region_id($sr_id);

                #
                # Store the binding site for this TF within this search
                # region.
                #
                push @{$tf_sites{$tf_id}}, $tfbs;
            }
        }

        #
        # Add the TF binding site mapping for this search region.
        #
        $sr_tf_sites{$sr_id} = \%tf_sites;

        foreach my $tf_id (keys %tf_sites) {
            $counts->seq_tfbs_count(
                $sr_id, $tf_id, scalar @{$tf_sites{$tf_id}}
            );
        }
    }

    return ($counts, \%sr_tf_sites);
}

#
# Given a mapping of pre-computed search regions to actual search regions and
# the binding sites for an individual TF, return a mapping of search regions
# to binding sites for this TF.
#
sub compute_tf_search_region_tfbss
{
    my ($pc_sr_to_sr, $tfbss) = @_;

    my %sr_tfbss;

    foreach my $tfbs (@$tfbss) {
        my $pc_sr_id = $tfbs->search_region_id;

        my $search_regions = $pc_sr_to_sr->{$pc_sr_id};

        unless ($search_regions) {
            fatal(
                  "No search region mapping for TFBS in pre-computed search"
                . " region $pc_sr_id"
            );
        }

        foreach my $sr (@$search_regions) {
            if ($tfbs->start >= $sr->start && $tfbs->end <= $sr->end) {
                push @{$sr_tfbss{$sr->id}}, $tfbs;
                last;
            }
        }
    }

    return %sr_tfbss ? \%sr_tfbss : undef;
}

#
# Check if features should be combined. They should if they overlap or are
# adjacent (no gap between them).
#
sub do_features_combine
{
    my ($feat1, $feat2) = @_;

    my $combine = 1;
    $combine = 0 if $feat1->{-start} > $feat2->{-end} + 1
        || $feat1->{-end} < $feat2->{-start} - 1;

    return $combine;
}

#
# Create a mapping of pre-computed search region IDs to actual search regions
# computed for the analysis.
#
sub create_search_region_map
{
    my ($search_regions) = @_;

    my %sr_map;

    foreach my $sr (@$search_regions) {
        push @{$sr_map{$sr->parent_id}}, $sr;
    }

    return %sr_map ? \%sr_map : undef;
}

sub chrom_compare
{
    my $chrom1 = $a;
    my $chrom2 = $b;

    if ($chrom1 =~ /^\d$/) {
        $chrom1 = sprintf "%02d", $chrom1;
    }

    if ($chrom2 =~ /^\d$/) {
        $chrom2 = sprintf "%02d", $chrom2;
    }
    
    return $chrom1 cmp $chrom2;
}

sub fetch_search_region_sequences
{
    my ($regions, $ens_sa, $job_args) = @_;

    my @seqs;

    foreach my $reg (@$regions) {
        my $chrom = $reg->chrom;
        my $start = $reg->start;
        my $end   = $reg->end;

        if ($chrom eq 'M') {
            $chrom = 'MT';
        }

        my $slice = $ens_sa->fetch_by_region(
            'chromosome', $chrom, $start, $end
        );

        unless ($slice) {
            fatal(
                "Could not fetch chr$chrom:$start-$end slice from Ensembl",
                $job_args
            );
        }

        push @seqs, Bio::Seq->new(
            -alphabet       => 'dna',
            -display_id     => "chr$chrom:$start-$end",
            -seq            => $slice->seq
        );
    }

    return @seqs ? \@seqs : undef;
}

#
# Search sequences for binding sites and compute the TFBS counts. The binding
# site destails are written to temporary data files for later conversion to
# text and html files to avoid having to store all the binding sites in memory.
#
# Search seqs with all the TFs in the TF set. Return an
# OPOSSUM::Analysis::Counts object of the seq-TF binding site counts.
#
sub search_seqs_and_compute_tfbs_counts
{
    my ($tf_set, $seqs, $threshold, $write_details, $job_args) = @_;

    my $any_tfbs_found = 0;

    my $logger = $job_args->{-logger};
    my $results_dir = $job_args->{-results_dir};

    my $tf_ids = $tf_set->ids();

    my @seq_ids = map {$_->display_id} @$seqs;

    #
    # If threshold is specified as a decimal, convert it to a
    # percentage, otherwise the TFBS::Matrix::PWM::search_seq method
    # treats the number as an absolute matrix score which is not what
    # we intended. DJA 2012/06/07
    #
    unless ($threshold =~ /(.+)%$/ || $threshold > 1) {
        $threshold *= 100;
        $threshold .= '%';
    }

    my $counts = OPOSSUM::Analysis::Counts->new(
        -gene_ids   => \@seq_ids,
        -tf_ids     => $tf_ids
    );

	foreach my $tf_id (@$tf_ids) {
        my $fh;

        if ($write_details && $results_dir) {
            my $fname = $tf_id;
            $fname =~ s/\//_/g;

            my $data_file = "$results_dir/$fname.data";

            if (open($fh, ">$data_file")) {
                #
                # Specific header format recognized by Datafile plugin of the
                # Template Toolkit.
                #
                printf $fh
                    "region|chr|start|end|strand|score|rel_score"
                    . "|seq\n";
            } else {
                carp "Error opening output TFBS details data file"
                    . " $data_file - $!\n";
            }
        }

	    my $matrix = $tf_set->get_matrix($tf_id);

        my $pwm;
        if ($matrix->isa("TFBS::Matrix::PFM")) {
            $pwm = $matrix->to_PWM();
        } else {
            $pwm = $matrix;
        }

        foreach my $seq (@$seqs) {
            my $tfbs_count = 0;

            my $seq_id = $seq->display_id();

            #$logger->info("processing sequence $seq_id");

            my $siteset = $pwm->search_seq(
                -seqobj     => $seq,
                -threshold  => $threshold
            );

            my $filtered_siteset;
            if ($siteset && $siteset->size > 0) {
                $filtered_siteset = filter_overlapping_sites($siteset);

                if ($filtered_siteset && $filtered_siteset->size > 0) {
                    $any_tfbs_found = 1;

                    if ($write_details && $results_dir && $fh) {
                        write_tfbs_details_data(
                            $fh, $seq_id, $filtered_siteset, $job_args
                        );
                    }

                    $tfbs_count = $filtered_siteset->size;
                }
            }

            $counts->seq_tfbs_count($seq_id, $tf_id, $tfbs_count);
        }

        close($fh) if $fh;
    }

    return $any_tfbs_found ? $counts : undef;
}

#
# For each TF's TFBS hit data files written out by whichever method fetched
# or computed the TFBS hits, create formatted text and HTML TFBS detail files.
#
sub write_tfbs_details
{
    my ($results, $tf_set, $job_args) = @_;

    my $logger      = $job_args->{-logger};
    my $web         = $job_args->{-web};
    my $results_dir = $job_args->{-results_dir};

    #
    # Cycle through results rather than getting the TF IDs from the tf_set as
    # not all TFs may actually have any hits (and therefore no associated
    # hit details data file).
    #
    foreach my $result (@$results) {
        my $tf_id = $result->id;
        my $tf = $tf_set->get_tf($tf_id);

        #
        # In the case where we are not using JASPAR matrices, we have to make
        # sure the TF IDs (which are used to create the details file names)
        # do not contain special characters interpreted by the OS and replace
        # them if so. For now just replacing '/', any others?
        #
        my $fname = $tf_id;
        $fname =~ s/\//_/g;

        my $data_file = "$results_dir/$fname.data";

        #
        # If there were no hits for this TF then the data file will not exist.
        # DJA 2014/11/24
        #
        if (-e $data_file) {
            my $text_file = "$results_dir/$fname.txt";

            write_tfbs_details_text_from_data(
                $tf, $data_file, $text_file, $job_args
            );

            if ($web) {
                my $html_file = "$results_dir/$fname.html";

                write_tfbs_details_html_from_data(
                    $tf, $data_file, $html_file, $job_args
                );
            }
        }

        #
        # Remove data file
        #
        #unlink $data_file;
    }
}

#
# Write the details of the putative TFBSs to the given file in a format
# recognized by the Datafile plugin of the Template Toolkit, for later
# conversion into text and html files.
#
sub write_tfbs_details_data
{
    my ($fh, $seq_id, $siteset) = @_;
    
    my $seq_start = 1;
    my $seq_chrom = '';
    if ($seq_id =~ /chr(\w+):(\d+)-(\d+)/) {
        $seq_chrom = $1;
        $seq_start = $2;
    }

    my $iter = $siteset->Iterator(-sort_by => 'start');

    while (my $site = $iter->next()) {
        printf $fh "%s|%s|%d|%d|%s|%.3f|%.1f|%s\n",
            $seq_id,
            $seq_chrom,
            $site->start + $seq_start - 1,
            $site->end + $seq_start - 1,
            $site->strand == -1 ? '-' : '+',
            $site->score,
            $site->rel_score * 100,
            $site->seq->seq();
    }
}

sub write_tfbs_details_text_from_data
{
    my ($tf, $data_file, $text_file, $job_args) = @_;

    my $logger = $job_args->{-logger};
    my $tf_db  = $job_args->{-tf_db};

    unless (open(DFH, $data_file)) {
        $logger->error("Error opening TFBS detail data file $data_file - $!");
        return;
    }

    unless (open(OFH, ">$text_file")) {
        $logger->error("Error creating TFBS detail text file $text_file - $!");
        return;
    }

    write_tfbs_details_text_header(\*OFH, $tf);

    my $last_region = '';
    while (my $line = <DFH>) {
        next if $line =~ /^\s*region/i;  # skip header

        chomp $line;

        my @cols = split /\s*\|\s*/, $line;

        my $region = $cols[0];

        if ($region eq $last_region) {
            print OFH "\t";
        } else {
            print OFH "$region\t";

            $last_region = $region;
        }

        printf(OFH "%s\t%s\t%s\t%s\t%s\t%s%%\t%s\n",
            $cols[1],
            $cols[2],
            $cols[3],
            $cols[4],
            $cols[5],
            $cols[6],
            $cols[7]
        );
    }
}

sub write_tfbs_details_text_header
{
    my ($fh, $tf) = @_;

    my $total_ic;
    if ($tf->isa("TFBS::Matrix::PFM")) {
        $total_ic = sprintf("%.3f", $tf->to_ICM->total_ic());
    } else {
        $total_ic = 'NA';
    }

    printf $fh "%s Binding Sites\n\n", $tf->name();

    printf $fh "TF name:\t%s\n", $tf->name();
    printf $fh "JASPAR ID:\t%s\n", $tf->ID();
    printf $fh "Class:\t%s\n", $tf->class() || '';
    printf $fh "Family:\t%s\n", $tf->tag('family') || '';
    printf $fh "Tax group:\t%s\n", $tf->tag('tax_group') || '';
    printf $fh "GC content:\t%s\n",
        sprintf("%.3f", $tf->tag('gc_content')) || '';
    printf $fh "Information content:\t%s\n", $total_ic;

    print $fh "\n\nBinding Sites:\n\n";

    print $fh "Region\tChr\tStart\tEnd\tStrand\tAbs. Score\tRel. Score\tSequence\n";
}

sub write_tfbs_details_html_from_data
{
    my ($tf, $data_file, $html_file, $job_args) = @_;

    my $tf_name = $tf->name();
    my $tf_id   = $tf->ID();

    my $job_id          = $job_args->{-job_id};
    my $heading         = $job_args->{-heading};
    my $bg_color_class  = $job_args->{-bg_color_class};
    my $rel_results_dir = $job_args->{-rel_results_dir};
    my $tf_db           = $job_args->{-tf_db};
    my $email           = $job_args->{-email};
    my $logger          = $job_args->{-logger};

    open(FH, ">$html_file") || fatal(
        "Could not create TFBS details html file $html_file", $job_args
    );

    $logger->info("Writing '$tf_id - $tf_name' TFBS details to $html_file");

    my $title = "CAGEd-oPOSSUM $heading Results";
    my $section = sprintf("%s Binding Sites", $tf_name);

    my $fname = $tf_id;
    $fname =~ s/\//_/g;

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
        jaspar_url          => JASPAR_URL,
        tf_db               => $tf_db,
        tf                  => $tf,
        rel_results_dir     => $rel_results_dir,
        data_file           => $data_file,
        tfbs_details_file   => "$fname.txt",

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

1;
