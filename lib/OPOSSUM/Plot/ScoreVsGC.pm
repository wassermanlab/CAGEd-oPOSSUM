=head1 NAME

OPOSSUM::Plot::ScoreVsGC.pm - module to call R to plot Z, Fisher or KS scores
vs. GC content of the TFs.

=head1 SYNOPSIS

 $plotter = OPOSSUM::Plot::ScoreVsGC->new();

 $plotter->plot($results, $tf_set, $plot_type, $sd_fold, $filename);

=head1 DESCRIPTION

Given an oPOSSUM analysis result set, plot the relevant score vs. TF GC
content using R. Must have R installed to run.

=head1 AUTHORS

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::Plot::ScoreVsGC;
use parent 'Statistics::R';

use strict;

use Carp;
use POSIX;

my $inf    = 9**9**9;
my $neginf = -9**9**9;
my $nan    = -sin(9**9**9);

=head2 new

 Title    : new
 Usage    : $plotter = OPOSSUM::Plot::ScoreVsGC->new();
 Function : Create a new OPOSSUM::Plot::ScoreVsGC object.
 Returns  : An OPOSSUM::Plot::ScoreVsGC object.
 Args     : None

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = Statistics::R->new();

    my $logger = $args{-logger};
    if ($logger) {
        $self->{-logger} = $logger;
        $logger->info("Initialized ScoreVsGC content plotter");
    }

    bless $self, $class;

    return $self;
}

=head2 plot

 Title    : plot
 Usage    : $plotter->plot(
                $results,
                $tf_set,
                $plot_type,
                $sd_fold,
                $filename,
                $errors
            );
 Function : Plot the appropriate score from the oPOSSUM result set.
 Returns  : 
 Args     : results     - A listref of OPOSSUM::Analysis::CombinedResult
                          objects.
            tf_set      - An OPOSSUM::TFSet object.
            plot_type   - String informing which score to plot, either
                          'Z', 'Fisher' or 'KS'.
            sd_fold     - Numeric indicating the standard deviation
                          fold used to determine the threshold.
            filename    - The name of the output plot file. Output file is
                          in PNG format.
            errors      - A reference to a list of error messages to be
                          passed back to caller.

=cut

sub plot
{
    my ($self, $results, $tf_set, $plot_type, $sd_fold, $filename,
        $errors) = @_;

    my $logger = $self->{-logger};

    if ($logger) {
        $logger->info("Plotting ${plot_type}-score vs. %GC composition to file $filename");
    }

    my $error;

    unless ($results) {
        $error = "No result set provided";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless (ref $results eq 'ARRAY' && $results->[0]) {
        $error = "No result set provided";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless ($tf_set) {
        $error = "No TF set provided";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless ($plot_type) {
        $error = "No plot type provided";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless ($sd_fold) {
        $error = "No SD fold provided";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless ($filename) {
        $error = "No output plot file name provided";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless ($results->[0]->isa("OPOSSUM::Analysis::CombinedResult")) {
        $error = "Results is not an arrayref of"
                . " OPOSSUM::Analysis::CombinedResult objects";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless (ref $tf_set && $tf_set->isa("OPOSSUM::TFSet")) {
        $error = "TF set is not an OPOSSUM::TFSet object";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    unless ($plot_type eq 'Z' || $plot_type eq 'Fisher' || $plot_type eq 'KS')
    {
        $error = "Provided plot type is not one of 'Z', 'F' or 'KS'";
        push @$errors, $error;
        carp $error;
        return 0;
    }

    my $title;
    my $ylab;
    if ($plot_type eq 'Z') {
        $title = 'Z-score vs. TF profile %GC composition';
        $ylab = 'Z-score';
    } elsif ($plot_type eq 'Fisher') {
        $title = 'Fisher score vs. TF profile %GC composition';
        $ylab = 'Fisher score';
    } elsif ($plot_type eq 'KS') {
        $title = 'KS-score vs. TF profile %GC composition';
        $ylab = 'KS score';
    }

    my @gc;
    my @scores;
    my @names;
    foreach my $result (@$results) {
        my $id = $result->id;

        my $score;
        if ($plot_type eq 'Z') {
            $score = $result->zscore();
        } elsif ($plot_type eq 'Fisher') {
            $score = $result->fisher_p_value();
        } elsif ($plot_type eq 'KS') {
            $score = $result->ks_p_value();
        }

        next unless defined $score;
        next if $score == $nan;

        push @scores, $score;

        my $tf = $tf_set->get_tf($id);

        push @gc, $tf->tag('gc_content') * 100;
        push @names, $tf->name;
    }

    my $mean = _compute_mean(\@scores);
    my $sd = _compute_sd(\@scores, $mean);
    my $threshold = _compute_threshold($mean, $sd, $sd_fold);

    my $max_score = $neginf;
    my $min_score = $inf;
    my @gc_above;
    my @scores_above;
    my @names_above;
    #my @gc_below;
    #my @scores_below;

    #
    # Find max/min scores. Scores of inf/-inf are treated as 500/-100.
    # Find all IDs whose scores are above threshold and store the information
    # for labelling on the graph.
    #
    my $has_inf = 0;
    my $num_scores = scalar @scores;
    foreach my $i (0..$num_scores - 1) {
        my $score = $scores[$i];

        next unless defined $score;
        next if $score == $nan;

        if ($score > $max_score) {
            if ($score == $inf) {
                $max_score = 500;
                $has_inf = 1;
            } else {
                $max_score = $score;
            }
        }

        if ($score < $min_score) {
            if ($score == $neginf) {
                $min_score = -100;
            } else {
                $min_score = $score;
            }
        }

        if ($score >= $threshold) {
            push @gc_above, $gc[$i];
            push @scores_above, $score;
            push @names_above, $names[$i];
        #} else {
        #    push @gc_below, $gc[$i];
        #    push @scores_below, $scores[$i];
        }
    }

    if ($max_score > 50) {
        #
        # Round max score up to closest 100
        #
        $max_score = ceil($max_score / 100) * 100;
    } else {
        #
        # Round max score up to closest 10
        #
        $max_score = ceil($max_score / 10) * 10;
    }

    if ($min_score < 0) {
        $min_score = floor($min_score / 10) * 10;
    } else {
        $min_score = 0;
    }

    #
    # Convert inf/-inf scores to max/min
    #
    foreach my $i (0..$num_scores - 1) {
        if ($scores[$i] == $nan) {
            $scores[$i] = 0;
        } elsif ($scores[$i] > $max_score) {
            $scores[$i] = $max_score;
        } elsif ($scores[$i] < $min_score) {
            $scores[$i] = $min_score;
        }
    }

    my $num_scores_above = scalar @scores_above;
    foreach my $i (0..$num_scores_above - 1) {
        if ($scores[$i] == $nan) {
            $scores[$i] = 0;
        } elsif ($scores_above[$i] > $max_score) {
            $scores_above[$i] = $max_score;
        } elsif ($scores_above[$i] < $min_score) {
            $scores_above[$i] = $min_score;
        }
    }

    my @legend;
    push @legend, "mean + $sd_fold * sd";

    $self->set('scores', \@scores);
    $self->set('gc', \@gc);
    $self->set('gc_above', \@gc_above);
    $self->set('scores_above', \@scores_above);
    $self->set('names_above', \@names_above);
    $self->set('gc', \@gc);
    $self->set('leg', \@legend);

    my @R_cmds;

    push @R_cmds, q{xlimit = c(0, 100)};
    push @R_cmds, qq{ylimit = c($min_score, $max_score)};
    push @R_cmds, qq{png(filename="$filename", units="px", width=1024, height=1024, res=NA, pointsize=16, bg="white")};

    if (@scores && $scores[0]) {
        push @R_cmds, qq{plot(gc, scores, cex=0.5, cex.axis=0.9, cex.main=0.8, main="$title", xlab="TF profile \%GC composition", ylab="$ylab", xlim=xlimit, ylim=ylimit, las=1)};
    }

    if (@scores_above && $scores_above[0]) {
        push @R_cmds, q{text(gc_above, scores_above, labels=names_above, pos=3, offset=0.2, cex=0.8)};
    }

    if ($has_inf) {
        push @R_cmds, qq{text(c(0), c($max_score), labels=c("(Inf)"), pos=2, cex=0.9)};
    }

    push @R_cmds, qq{abline(h=$threshold, col="red", lty=2)};
    push @R_cmds, q{legend("topright", legend=leg, cex=0.8, col="red", lty=2, bty="n")};

    #
    # Note: this returns message "null device 1"
    #
    #push @R_cmds, q{dev.off()};

    #
    # Try running commands one at a time to catch errors in a more fine grained
    # way. DJA 2016/1/22
    #
    foreach my $cmd (@R_cmds) {
        $logger->info("Running R command: $cmd") if $logger;

        my $out;
        eval {
            $out = $self->run($cmd);
        };

        if ($@) {
            $logger->error("R command eval error: $@") if $logger;
        }

        if ($out) {
            unless ($out =~ /^null device/) {
                carp $out;
                push @$errors, $out;
            }

            $logger->info("R command returned: $out") if $logger;
        }
    }

    if (@$errors) {
        return 0;
    }

    return 1;
}

sub _compute_mean
{
    my ($scores) = @_;

    return 0 unless $scores && $scores->[0];

    #my $n = scalar @$scores;
    my $n = 0;
    my $sum = 0;
    foreach my $score (@$scores) {
        next unless defined $score;
        next if $score == $inf || $score == $neginf || $score == $nan;

        $sum += $score;
        $n++;
    }

    if ($n) {
        return $sum / $n;
    }

    return 0;
}

sub _compute_sd
{
    my ($scores, $mean) = @_;

    #my $n = scalar @$scores;
    my $sum = 0;
    my $n = 0;
    foreach my $score (@$scores) {
        next unless defined $score;
        next if $score == $inf || $score == $neginf || $score == $nan;

        $sum += ($score - $mean)**2;
        $n++;
    }

    if ($n) {
        return sqrt($sum / $n);
    }

    return 0;
}

sub _compute_threshold
{
    my ($mean, $sd, $sd_fold) = @_;

    return $mean + $sd * $sd_fold;
}

1;
