=head1 NAME

 OPOSSUM::Include::ExperimentInclude.pm

=head1 SYNOPSIS

=head1 DESCRIPTION

  Contains common options and routines that are related to extacting
  information wrt to experiments table or OPOSSUM::Experiment objects.

=head1 AUTHOR

  Andrew Kwon & David Arenillas
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia

  E-mail: tjkwon@cmmt.ubc.ca, dave@cmmt.ubc.ca

=cut

use strict;

#use oPossumWebOpt;
use OPOSSUM::Opt::ExperimentOpt;
use OPOSSUM::Include::BaseInclude;

#use Data::Dumper;    # for debugging only

use Bio::SeqIO;

#use TFBS::DB::JASPAR5;

sub read_experiment_ids_from_file
{
	my ($file, $job_args) = @_;

	return read_ids_from_file($file, $job_args);
}

#
# Given a list of experiment IDs which may be either internal DB IDs or
# FANTOM5 IDs, determine the ID type and set lists of both ID types.
#
sub get_experiment_ids
{
    my ($expa, $exp_ids, $out_db_ids, $out_ff_ids) = @_;

    my $exp_id_type = experiment_id_type($exp_ids);

    return $exp_id_type if $exp_id_type == EXPERIMENT_ID_TYPE_UNKNOWN;

    my $experiments;
    if ($exp_id_type == EXPERIMENT_ID_TYPE_DB) {
        $experiments = $expa->fetch_by_experiment_ids($exp_ids);
    } elsif ($exp_id_type == EXPERIMENT_ID_TYPE_FF) {
        $experiments = $expa->fetch_by_ff_ids($exp_ids);
    }

    foreach my $exp (@$experiments) {
        @$out_db_ids = $exp->id;
        @$out_ff_ids = $exp->FF_id;
    }

    return $exp_id_type;
}

sub get_experiments
{
    my ($expa, $torb, $exp_ids, $exp_ids_file, $job_args) = @_;

    my $logger = $job_args->{-logger};

    my $experiments;

    my @exp_db_ids;
    my @exp_ff_ids;

    if ($exp_ids_file && !$exp_ids) {
        #
        # Read experiment IDs from file.
        #
        $logger->info(
            "Reading $torb experiment IDs from file $exp_ids_file"
        );

        $exp_ids = read_experiment_ids_from_file($exp_ids_file, $job_args);

        unless ($exp_ids && $exp_ids->[0]) {
            fatal(
                "No $torb experiment IDs read from file $exp_ids_file",
                $job_args
            );
        }

        $logger->info(
            sprintf(
                "Read %d $torb experiment IDs from file $exp_ids_file",
                scalar @$exp_ids
            )
        );
    }

    #
    # Check number of targer experiments does not exceed maximum allowed.
    #
    #if (scalar @$exp_ids > MAX_TARGET_EXPERIMENTS) {
    #    fatal(
    #          "Number of background experiments input exceeds maximum of "
    #          . MAX_TARGET_EXPERIMENTS . " allowed", $job_args
    #    );
    #}

    #
    # Determine the experiment ID type.
    #
    my $exp_id_type = experiment_id_type($exp_ids);

    $logger->info("Fetching $torb experiments");

    if ($exp_id_type == EXPERIMENT_ID_TYPE_UNKNOWN) {
        fatal(
              "Provided $torb experiment IDs contain at least one unrecognized"
            . " ID or mixed ID types. Experiment IDs should either be FANTOM5"
            . " experiment IDs or internal oPOSSUM database IDs.", $job_args
        );
    } elsif ($exp_id_type == EXPERIMENT_ID_TYPE_DB) {
        $experiments = $expa->fetch_by_experiment_ids($exp_ids);
    } elsif ($exp_id_type == EXPERIMENT_ID_TYPE_FF) {
        $experiments = $expa->fetch_by_ff_ids($exp_ids);
    }

    unless ($experiments) {
        fatal(
            "No $torb experiments retrieved for the provided experiment"
            . " IDs", $job_args
        );
    }

    return $experiments;
}

sub fetch_tss_by_experimental_criteria
{
    my (
        $tssa, $torb, $experiments, $tag_count, $tpm, $tss_only, $gene_ids,
        $job_args
    ) = @_;

    my $logger = $job_args->{-logger};

    my @exp_ids = map {$_->id} @$experiments;

    #
    # Read TSSs based on these experiment IDs with the optionally specified
    # tag count and/or TPM.
    #

    $logger->info(
          "Fetching $torb TSSs associated with the specified"
        . " experimental criteria"
    ) if $logger;

    my $tss = $tssa->fetch(
        -is_tss         => $tss_only,
        -experiment_ids => \@exp_ids,
        -min_tag_count  => $tag_count,
        -min_tpm        => $tpm,
        -gene_ids       => $gene_ids
    );

    unless ($tss) {
        fatal(
              "No $torb TSSs found corresponding to the experimental"
            . " criteria specified",
            $job_args
        );
    }

    $logger->info(
        sprintf(
            "Fetched %d $torb TSSs based on %d experiment(s)",
            scalar @$tss,
            scalar @exp_ids
        )
    ) if $logger;

    return $tss;
}

#
# Determine the ID type of a list of experiment IDs. If the list consists
# entirely of DB experiments table IDs or entirely of FANTOM5 IDs return
# the corresponding type. If it's a mixed list or an unknown ID is found in
# the list, return error.
#
sub experiment_id_type
{
    my ($exp_ids) = @_;

    my $is_db_id = 0;
    my $is_ff_id = 0;
    my $is_bad_id = 0;
    foreach my $id (@$exp_ids) {
        if ($id =~ /^FF:/) {
            $is_ff_id = 1;
        } elsif ($id =~ /^\d+$/) {
            $is_db_id = 1;
        } else {
            $is_bad_id = 1;
            last;
        }
    }

    if ($is_bad_id || ($is_db_id && $is_ff_id)) {
        return EXPERIMENT_ID_TYPE_UNKNOWN;
    } elsif ($is_db_id) {
        return EXPERIMENT_ID_TYPE_DB;
    } elsif ($is_ff_id) {
        return EXPERIMENT_ID_TYPE_FF;
    }
}

sub fetch_all_experiment_ids
{
    my ($expa, $where) = @_;
    
    my $exp_ids = $expa->fetch_experiment_ids($where);

    return $exp_ids;
}

1;
