=head1 NAME

OPOSSUM::Tools::Homer - quick and dirty class to run HOMER.

=head1 DESCRIPTION

=head1 MODIFICATIONS

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 Child & Family Research Institute
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::Tools::Homer;

use Carp;
use FileHandle;
use File::Path qw(make_path remove_tree);
use Readonly;
use PDL;

use constant MIN_MATRIX_PROB => 0.001;
#
# This is a rather feeble way of trying to scale the HOMER PWM detection
# thresholds so that the results approximate those found by the JASPAR/TFBS
# perl modules.
#
use constant DETECTION_THRESHOLD_SCALE_FACTOR => 1.2;

use strict;

=head2 new

 Title   : new
 Usage   : $ba = OPOSSUM::Tools::Homer->new(
               -debug           => 0,
               -logger          => $logger
           );

 Function: Construct a new OPOSSUM::Tools::Homer object.

 Args    : -debug           => If true turn on debugging mode. Temp. files
                               are not deleted. If a logger is passed in
                               then debugging messages are written to it.
           -logger          => (optional) Log4perl logger object. If
                               provided write warning/error messages to
                               it.

 Returns : A new OPOSSUM::Tools::Homer object

=cut

sub new
{
    my ($class, %args) = @_;
    
    my $self = bless {
        %args
    }, ref $class || $class;

    return $self;
}

=head2 preparse_genome

 Title   : preparse_genome
 Usage   : OPOSSUM::Tools::Homer->preparse_genome(
                -assembly               => $assembly,
                -size                   => $fragment_size,
                -reference              => $reference_file,
                -preparsed_dir          => $dir

           );

 Function: Run the HOMER preparseGenome.pl tool

 Args    : -assembly    => Name of the assembly from which regions are
                           selected
           -size        => Size of fragments to use for preparsing the
                           genome
           -reference_file
                        => Reference position file
           -preparsed_dir
                        => Directory in which to place the preparsed output
                           files

 Returns : True on success, false otherwise.

=cut

sub preparse_genome
{
    my ($self, %args) = @_;

    my $assembly        = $args{-assembly};
    my $size            = $args{-size};
    my $reference_file  = $args{-reference_file};
    my $preparsed_dir   = $args{-preparsed_dir};

    unless ($assembly) {
        carp "No assembly provided";
        return 0;
    }

    unless ($size) {
        carp "No fragment size provided";
        return 0;
    }

    unless ($reference_file) {
        carp "No reference regions file provided";
        return 0;
    }

    unless ($preparsed_dir) {
        carp "No HOMER preparsed directory provided";
        return 0;
    }

    if (-d $preparsed_dir) {
        unless (-w $preparsed_dir) {
            carp "Specified HOMER preparsed directory $preparsed_dir is not writable";
            return 0;
        }
    } else {
        unless (make_path($preparsed_dir)) {
            carp "Unable to create HOMER preparsed directory $preparsed_dir";
            return 0;
        }

        $self->{-preparsed_dir_created} = 1;
        $self->{-preparsed_dir} = $preparsed_dir;
    }

    my $cmd = "preparseGenome.pl $assembly -size $size -ref $reference_file"
            . " -preparsedDir $preparsed_dir";

    my $logger = $self->{-logger};
    if ($logger) {
        $logger->info("Running HOMER command:\n$cmd\n");
    }

    my $out = `exec 2>&1; $cmd`;
    my $status = $? >> 8;
    if ($status) {
        carp "Error running HOMER preparseGenome - $out";
        return 0;
    }

    return 1;
}

=head2 find_motifs_genome

 Title   : find_motifs_genome
 Usage   : OPOSSUM::Tools::Homer->find_motifs_genome(
                -target_regions_file        => $target_regions_file,
                -background_regions_file    => $background_regions_file,
                -assembly                   => $assembly,
                -size                       => $size,
                -nlen                       => $nlen,
                -N                          => $num_regions,
                -cpg                        => 1,
                -chopify                    => 1,
                -dumpfasta                  => 1,
                -motif_file                 => $motif_file,
                -preparsed_dir              => $preparsed_dir,
                -output_dir                 => $output_dir
            );

 Function: Run the HOMER findMotifsGenome.pl tool.

 Args    : -target_regions_file => Name of the foreground regions file.
           -background_regions_file
                                => Name of the background regions file.
           -assembly            => Name of the assembly
           -size                => Fragment size to use for motif finding.
           -nlen                => Length of lower-order oligos to normalize
                                   in background
           -N                   => Number of regions to generate
           -cpg                 => If true, set -cpg flag
           -chopify             => If true, set -chopify flag
           -dumpfasta           => If true, set -dumpFasta flag
           -nomotif             => If true, set the -nomotif flag (do not
                                   search for de novo motif enrichment)
           -motif_file          => Name of a file containing motifs in HOMER
                                   format.
           -preparsed_dir       => The directory containing the preparsed
                                   region information
           -output_dir          => The directory to which the output GC
                                   composition matching regions are written

 Returns : True on success, false otherwise.

=cut

sub find_motifs_genome
{
    my ($self, %args) = @_;

    my $t_regions_file  = $args{-target_regions_file};
    my $b_regions_file  = $args{-background_regions_file};
    my $assembly        = $args{-assembly};
    my $size            = $args{-size};
    my $nlen            = $args{-nlen};
    my $num_regions     = $args{-N};
    my $cpg             = $args{-cpg};
    my $chopify         = $args{-chopify};
    my $dumpfasta       = $args{-dumpfasta};
    my $nomotif         = $args{-nomotif};
    my $motif_file      = $args{-motif_file};
    my $preparsed_dir   = $args{-preparsed_dir};
    my $output_dir      = $args{-output_dir};

    unless ($output_dir) {
        carp "No HOMER output directory provided";
        return 0;
    }

    if (-d $output_dir) {
        unless (-w $output_dir) {
            carp "Specified HOMER output directory $output_dir is not writable";
            return 0;
        }
    } else {
        unless (make_path($output_dir)) {
            carp "Unable to create HOMER output directory $output_dir";
            return 0;
        }

        $self->{-output_dir_created} = 1;
        $self->{-output_dir} = $output_dir;
    }

    my $cmd = "findMotifsGenome.pl $t_regions_file $assembly $output_dir";

    if ($preparsed_dir) {
        $cmd .= " -preparsedDir $preparsed_dir";
    }

    if ($b_regions_file) {
        $cmd .= " -bg $b_regions_file";
    }

    if ($motif_file) {
        $cmd .= " -mknown $motif_file";
    } else {
        $cmd .= " -noknown";
    }

    if ($size) {
        $cmd .= " -size $size";
    }

    if ($nlen) {
        $cmd .= " -nlen $nlen";
    }

    if ($num_regions) {
        $cmd .= " -N $num_regions";
    }

    if ($cpg) {
        $cmd .= " -cpg";
    }

    if ($chopify) {
        $cmd .= " -chopify";
    }

    if ($dumpfasta) {
        $cmd .= " -dumpFasta";
    }

    if ($nomotif) {
        $cmd .= " -nomotif";
    }

    my $logger = $self->{-logger};
    if ($logger) {
        $logger->info("Running HOMER command:\n$cmd\n");
    }

    my $out = `exec 2>&1; $cmd`;
    my $status = $? >> 8;
    if ($status) {
        carp "Error running HOMER preparseGenome - $out";
        return 0;
    }

    return 1;
}

sub print_matrix_set
{
    my ($self, $filename, $matrix_set, $threshold) = @_;

    unless (open(FH, ">$filename")) {
        carp "Could not open HOMER motif file $filename for writing - $!";
        return 0;
    }

    if ($matrix_set->isa('TFBS::MatrixSet')) {
        # If using a TFBS::MatrixSet
        my $iter = $matrix_set->Iterator();
        while (my $pfm = $iter->next()) {
            printf FH $self->print_matrix($pfm, $threshold);
        }
    } elsif ($matrix_set->isa('OPOSSUM::TFSet')) {
        # If using an OPOSSUM::TFSet
        my $matrix_list = $matrix_set->get_matrix_list();
        foreach my $pfm (@$matrix_list) {
            printf FH $self->print_matrix($pfm, $threshold);
        }
    }

    close(FH);
}

#
# Print a JASPAR matrix in HOMER format required for scanning for binding sites
# and determining over-representation.
# See http://homer.salk.edu/homer/motif/creatingCustomMotifs.html
#
# Returns a string representation of the matrix in HOMER format. This is a
# true frequency matrix.
# XXX
# The HOMER header requires a '>' followed by three tab delimeted fields:
# 1) The consensus sequence string (this is not actually used by HOMER so
#    we will substitute this with the JASPAR matrix ID.
# 2) The matrix name
# 3) The log odds detection threshold. It is not clear what we should use here
#    or how this number can be derived from a relative score threshold.
#
# The matrix printed 
#
sub print_matrix
{
    my ($self, $jaspar_pfm, $threshold) = @_;

    #
    # If threshold defined as a percentage, convert to value from 0 to 1
    #
    if ($threshold =~ /(.+)%$/) {
        $threshold = $1 / 100;
    }

    my $matrix_id = $jaspar_pfm->{'ID'};
    my $matrix_name = $jaspar_pfm->{'name'};

    printf "\nJASPAR Matrix %s\t%s\n", $matrix_id, $matrix_name;

    my $homer_pfm = $self->jaspar_pfm_to_homer_pfm($jaspar_pfm);
    #my $homer_pfm_min_score = $homer_pfm->min_score();
    #my $homer_pfm_max_score = $homer_pfm->max_score();
    #my $homer_pfm_threshold = log(
    #    ($homer_pfm_max_score - $homer_pfm_min_score)
    #    * $threshold + $homer_pfm_min_score
    #);

    #my $jaspar_pwm = $jaspar_pfm->to_PWM();
    #my $jaspar_min_score = $jaspar_pwm->min_score();
    #my $jaspar_max_score = $jaspar_pwm->max_score();

    #my $jaspar_threshold = ($jaspar_max_score - $jaspar_min_score)
    #    * $threshold + $jaspar_min_score;

    #print "\nJASPAR PWM min. score = $jaspar_min_score;"
    #    . " max. score = $jaspar_max_score; rel. score = $jaspar_threshold\n";

    my $homer_pwm = $self->homer_pfm_to_homer_pwm($homer_pfm);
    my $homer_min_score = $homer_pwm->min_score();
    my $homer_max_score = $homer_pwm->max_score();

    my $homer_threshold = ($homer_max_score - $homer_min_score)
        * $threshold + $homer_min_score;

    #print "\nHOMER PWM min. score = $homer_min_score;"
    #    . " max. score = $homer_max_score; rel. score = $homer_threshold\n";

    #
    # Writing a JASPAR counts matrix. Doesn't work even though HOMER docs
    # states it should.
    #
    #my $pfm_string = sprintf($jaspar_pfm->pdl_matrix);
    #
    # Writing a HOMER frequency matrix.
    #
    my $pfm_string = sprintf($homer_pfm->pdl_matrix);

    $pfm_string =~ s/\[|\]//g;                # lose []
    $pfm_string =~ s/\n\s+/\n/g;              # lose leading spaces
    my @pfmlines = split(/\n+/, $pfm_string);
    @pfmlines = map { [ split(/\s+/, $_) ] } @pfmlines;

    my $detection_threshold
                = $homer_threshold * DETECTION_THRESHOLD_SCALE_FACTOR; 

    my $print_string = sprintf(">%s\t%s\t%.6f\n",
        $matrix_id,
        $matrix_name,
        $detection_threshold
    );

    for my $row (0..$#{ $pfmlines[1] }) {
        #
        # If writing counts matrix - doesn't seem to work even though the
        # HOMER documentation states that it should take a counts matrix.
        #
        #$print_string .= sprintf("%d\t", $pfmlines[$_]->[$row])
        #    for (1..$#pfmlines);

        #
        # If writing frequency matrix.
        #
        $print_string .= sprintf("%0.6f\t", $pfmlines[$_]->[$row])
            for (1..$#pfmlines);

        $print_string .= "\n";
    }

    return $print_string;
}

#
# Convert a JASPAR/TFBS PFM (actually a counts matrix) to a HOMER style
# probability (frequency) matrix.
#
# This duplicates the PSSM::adjustValues() routine in the HOMER Motif.cpp
# module. It leaves out the adjustment for values below 0.
#
# HOMER adjusts the frequencies according to the min. allowed frequency
# defined by MIN_MATRIX_PROB.
#
sub jaspar_pfm_to_homer_pfm
{
    my ($self, $pfm) = @_;

    my $pdl = $pfm->pdl_matrix;
    my $length = $pdl->getdim(0);
    my $size = $pdl->getdim(1);

    for my $i (0..$length-1) {
        my $total = 0;

        for my $j (0..$size-1) {
            $total += $pdl->at($i, $j);
        }

        my $under = 0;
        my $totalOver = 0;

        for my $j (0..$size-1) {
            my $val = $pdl->at($i, $j);
            my $new_val = $val / $total;

            $pdl->set($i, $j, $new_val);

            if ($new_val < MIN_MATRIX_PROB) {
                $under++;
            } else {
                $totalOver += $new_val;
            }
        }

        for my $j (0..$size-1) {
            my $val = $pdl->at($i, $j);
            if ($val < MIN_MATRIX_PROB) {
                $pdl->set($i, $j, MIN_MATRIX_PROB);
            } else {
                my $new_val = $val
                    * (($totalOver - $under * MIN_MATRIX_PROB)
                    / $totalOver);

                $pdl->set($i, $j, $new_val);
            }
        }
    }

    #
    # NOTE: Using a PWM as PFM does not provide min and max score methods
    #
    my $homer_pfm = TFBS::Matrix::PWM->new(
        (map {("-$_", $pfm->{$_}) } keys %$pfm),
        # do not want tags to point to the same arrayref as in $pfm:
        -tags               => \%{$pfm->{'tags'}},
        -bg_probabilities   => \%{$pfm->{'bg_probabilities'}},
        -matrix             => $pdl
    );

    return $homer_pfm;
}

#
# Convert a HOMER style frequency matrix to a HOMER style PWM (PSSM).
#
# The following duplicates the PSSM::logXform() routine in the HOMER
# Motif.cpp module.
#
#
# The formula for computing HOMER PWMs is a little different than JASPAR/TFBS.
#
# JASPAR/TFBS PWM log-odds ratio for each of the nucleotide counts n where the
# total number of sequences composing the matrix is N is given as:
# log2((n + sqrt(N) x 0.25) / (N + sqrt(N)) * 4)
#
# Instead HOMER adjusts the frequencies (see the jaspar_pfm_to_homer_pfm
# routine).
#
# NOTE: HOMER also uses the natural logarithm instead of log base 2.
#
sub homer_pfm_to_homer_pwm
{
    my ($self, $pfm) = @_;

    my $bg = $pfm->{'bg_probabilities'};
    my $bg_pdl = transpose pdl($bg->{'A'}, $bg->{'C'}, $bg->{'G'}, $bg->{'T'});

    my $pdl = $pfm->pdl_matrix;
    my $length = $pdl->getdim(0);
    my $size = $pdl->getdim(1);

    #for my $i (0..$length-1) {
    #    for my $j (0..$size-1) {
    #        my $val = log($pdl->at($i, $j) / $bg_pdl->at(0, $j));
    #        $pdl->set($i, $j, $val);
    #    }
    #}
    # Assume background frequency is 0.25
    $pdl = log($pdl * 4);
    
    my $homer_pwm = TFBS::Matrix::PWM->new(
        (map {("-$_", $pfm->{$_}) } keys %$pfm),
        # do not want tags to point to the same arrayref as in $pfm:
        -tags               => \%{$pfm->{'tags'}},
        -bg_probabilities   => \%{$pfm->{'bg_probabilities'}},
        -matrix             => $pdl
    );

    return $homer_pwm;
}

sub log2 {
    log($_[0]) / log(2);
}

sub DESTROY
{
    my $self = shift;

    #
    # Remove working directory if and only if debug mode is NOT set and the
    # directory was actually created on object creation (don't remove it if
    # the directory already existed).
    #
    unless ($self->{-debug}) {
        if ($self->{-preparsed_dir_created}) {
            remove_tree($self->{-preparsed_dir});
        }

        if ($self->{-output_dir_created}) {
            remove_tree($self->{-output_dir});
        }
    }
}

1;
