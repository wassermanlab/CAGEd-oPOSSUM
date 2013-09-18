=head1 NAME

OPOSSUM::DBSQL::ExpressionAdaptor - Adaptor for MySQL queries to
retrieve and store Expression objects.

=head1 SYNOPSIS

$exptsa = $db_adaptor->get_ExpressionAdaptor();

=head1 DESCRIPTION

The expression table contains records which store the expression levels (tag
count and tags per million) for each of the TSS cluster tags for each
experiment.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::DBSQL::ExpressionAdaptor;

use strict;

use Carp;

use OPOSSUM::DBSQL::BaseAdaptor;
use OPOSSUM::Expression;

use vars '@ISA';
@ISA = qw(OPOSSUM::DBSQL::BaseAdaptor);

sub new
{
    my ($class, @args) = @_;

    $class = ref $class || $class;

    my $self = $class->SUPER::new(@args);

    return $self;
}

=head2 fetch_experiment_ids

 Title    : fetch_experiment_ids
 Usage    : $ids = $exptsa->fetch_experiment_ids($where_clause);
 Function : Fetch a list of all the distinct experiment IDs from the
            expression table of the DB.
 Returns  : A list ref of integer experiment IDs.
 Args	  : Optionally an SQL where clause.

=cut

sub fetch_experiment_ids
{
    my ($self, $where_clause) = @_;

    my $sql = "select distinct experiment_id from expression";
    if ($where_clause) {
        $sql .= " where $where_clause";
    }

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch experiment IDs\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch experiment IDs\n" . $self->errstr;
        return;
    }

    my @ids;
    while (my ($id) = $sth->fetchrow_array) {
        push @ids, $id;
    }
    $sth->finish;

    return @ids ? \@ids : undef;
}

=head2 fetch_tss_ids

 Title    : fetch_tss_ids
 Usage    : $ids = $exptsa->fetch_tss_ids($where_clause);
 Function : Fetch a list of all the distinct TSS IDs from the
            expression table of the DB.
 Returns  : A list ref of integer TSS IDs.
 Args	  : Optionally an SQL where clause.

=cut

sub fetch_tss_ids
{
    my ($self, $where_clause) = @_;

    my $sql = "select distinct tss_id from expression";
    if ($where_clause) {
        $sql .= " where $where_clause";
    }

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch TSS IDs\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch TSS IDs\n" . $self->errstr;
        return;
    }

    my @ids;
    while (my ($id) = $sth->fetchrow_array) {
        push @ids, $id;
    }
    $sth->finish;

    return @ids ? \@ids : undef;
}

=head2 fetch_where

 Title    : fetch_where
 Usage    : $et_scores = $exptsa->fetch_where($where_clause);
 Function : Fetch a list of OPOSSUM::Expression objects using an
            optional where clause.
 Returns  : A list ref of OPOSSUM::Expression objects.
 Args	  : Optional where clause.

=cut

sub fetch_where
{
    my ($self, $where) = @_;

    my $sql = qq{
        select experiment_id, tss_id, tag_count, tpm
        from expression
    };

    if ($where) {
        unless ($where =~ /^\s*where\s+/) {
            $sql .= " where";
        }

        $sql .= " $where";
    }

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch expression:\n$sql\n"
            . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch expression:\n$sql\n"
            . $self->errstr;
        return;
    }

    my @expression;
    while (my @row = $sth->fetchrow_array) {
        push @expression,
            OPOSSUM::Expression->new(
            -experiment_id  => $row[0],
            -tss_id         => $row[1],
            -tag_count      => $row[2],
            -tpm            => $row[3]
        );
    }

    return @expression ? \@expression : undef;
}

=head2 fetch

 Title    : fetch
 Usage    : $et_scores = $exptsa->fetch(
                -experiment_ids => $experiment_ids,
                -tss_ids        => $tss_ids,
                -min_tag_count  => $min_tag_count,
                -min_tpm        => $min_tpm,
                -max_tag_count  => $max_tag_count,
                -max_tpm        => $max_tpm
            );
 Function : Fetch a list of OPOSSUM::Expression objects for the
            given experiment IDs, TSS IDs and score threshold.
 Returns  : A list ref of OPOSSUM::Expression objects.
 Args	  : Hash argument optionally specifying a list of experiment IDs,
            TSS IDs and/or min./max. tag counts and/or TPM values.

=cut

sub fetch
{
    my ($self, %args) = @_;

    my $exp_ids       = $args{-experiment_ids};
    my $tss_ids       = $args{-tss_ids};
    my $min_tag_count = $args{-min_tag_count};
    my $min_tpm       = $args{-min_tpm};
    my $max_tag_count = $args{-max_tag_count};
    my $max_tpm       = $args{-max_tpm};

    my $where;

    my $ref = ref $exp_ids;
    if (defined $exp_ids
        && (!$ref || ($ref eq 'ARRAY' && $exp_ids->[0]))
    ) {
        if ($ref eq 'ARRAY') {
            $where .= " experiment_id in (";
            $where .= join ",", @$exp_ids;
            $where .= ")";
        } else {
            $where .= " experiment_id = $exp_ids";
        }
    }

    $ref = ref $tss_ids;
    if (defined $tss_ids
        && (!$ref || ($ref eq 'ARRAY' && $tss_ids->[0]))
    ) {
        $where .= " and" if $where;
        if ($ref eq 'ARRAY') {
            $where .= " tss_id in (";
            $where .= join ",", @$tss_ids;
            $where .= ")";
        } else {
            $where .= " tss_id = $tss_ids";
        }
    }

    if (defined $min_tag_count) {
        $where .= " and" if $where;
        $where .= " tag_count >= $min_tag_count";
    }

    if (defined $min_tpm) {
        $where .= " and" if $where;
        $where .= " tpm >= $min_tpm";
    }

    if (defined $max_tag_count) {
        $where .= " and" if $where;
        $where .= " tag_count <= $max_tag_count";
    }

    if (defined $max_tpm) {
        $where .= " and" if $where;
        $where .= " tpm <= $max_tpm";
    }

    return $self->fetch_where($where);
}

=head2 fetch_experiment_tss_ids

 Title    : fetch_experiment_tss_ids
 Usage    : $tss = $exptsa->fetch_experiment_tss_ids
                -experiment_ids => $experiment_ids,
                -min_tag_count  => $min_tag_count,
                -min_tpm        => $min_tpm,
                -max_tag_count  => $max_tag_count,
                -max_tpm        => $max_tpm
            );
 Function : Fetch a list of OPOSSUM::TSS IDs for the given experiment
            IDs, where the TSS counts and/or TPM values are above or below
            the given score thresholds.
 Returns  : A list ref of TSS IDs.
 Args	  : Hash argument specifying which experiments with the given 
            min./max tag count and/or TPM thresholds.

=cut

sub fetch_experiment_tss_ids
{
    my ($self, %args) = @_;

    my $exp_ids       = $args{-experiment_ids};
    my $min_tag_count = $args{-min_tag_count};
    my $min_tpm       = $args{-min_tpm};
    my $max_tag_count = $args{-max_tag_count};
    my $max_tpm       = $args{-max_tpm};

    my $where;

    my $ref = ref $exp_ids;
    if (defined $exp_ids
        && (!$ref || ($ref eq 'ARRAY' && $exp_ids->[0]))
    ) {
        if ($ref eq 'ARRAY') {
            $where .= " experiment_id in (";
            $where .= join ",", @$exp_ids;
            $where .= ")";
        } else {
            $where .= " experiment_id = $exp_ids";
        }
    }

    if (defined $min_tag_count) {
        $where .= " and" if $where;
        $where .= " tag_count >= $min_tag_count";
    }

    if (defined $min_tpm) {
        $where .= " and" if $where;
        $where .= " tpm >= $min_tpm";
    }

    if (defined $max_tag_count) {
        $where .= " and" if $where;
        $where .= " tag_count <= $max_tag_count";
    }

    if (defined $max_tpm) {
        $where .= " and" if $where;
        $where .= " tpm <= $max_tpm";
    }

    my $sql = "select distinct tss_id from expression";
    $sql .= " where $where" if $where;

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch experiment tss_ids:\n$sql\n"
            . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch experiment tss_ids:\n$sql\n"
            . $self->errstr;
        return;
    }

    my @tss_ids;
    while (my @row = $sth->fetchrow_array) {
        push @tss_ids, $row[0];
    }

    return @tss_ids ? \@tss_ids : undef;
}

=head2 store

 Title   : store
 Usage   : $exptsa->store($et_score);
 Function: Store expression in the database.
 Args    : The expression (OPOSSUM::Expression) to store.
 Returns : 1 on success, otherwise 0

=cut

sub store
{
    my ($self, $et_score) = @_;

    if (!ref $et_score || !$et_score->isa('OPOSSUM::Expression')) {
        carp "Not an OPOSSUM::Expression object";
        return;
    }

    my $sql = qq{
        insert into expression (experiment_id, tss_id, tag_count,
        tpm) values (?,?,?,?)
    };

    my $sth = $self->prepare($sql);
    unless ($sth) {
        carp "Error preparing insert expression statement\n"
            . $self->errstr;
        return 0;
    }

    unless (
        $sth->execute(
            $et_score->experiment_id, $et_score->tss_id, $et_score->tag_count,
            $et_score->tpm
        )
    ) {
        carp "Error inserting expression\n" . $self->errstr;
        return 0;
    }

    return 1;
}

1;
