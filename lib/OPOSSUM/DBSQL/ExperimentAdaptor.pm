=head1 NAME

OPOSSUM::DBSQL::ExperimentAdaptor - Adaptor for MySQL queries to retrieve and
store Experiment objects.

=head1 SYNOPSIS

$expa = $db_adaptor->get_ExperimentAdaptor();

=head1 DESCRIPTION

The experiments table of the oPOSSUM database stores experimentral experiment
information.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 MODIFICATIONS

=cut

package OPOSSUM::DBSQL::ExperimentAdaptor;

use strict;

use Carp;

use OPOSSUM::DBSQL::BaseAdaptor;
use OPOSSUM::Experiment;

use vars '@ISA';
@ISA = qw(OPOSSUM::DBSQL::BaseAdaptor);

=head2 new

 Title   : new
 Usage   : $expa = OPOSSUM::DBSQL::ExperimentAdaptor->new($db_adaptor);
 Function: Construct a new ExperimentAdaptor object
 Args    : An OPOSSUM::DBSQL::DBAdaptor object
 Returns : a new OPOSSUM::DBSQL::ExperimentAdaptor object

=cut

sub new
{
    my ($class, @args) = @_;

    $class = ref $class || $class;

    my $self = $class->SUPER::new(@args);

    return $self;
}

=head2 fetch_experiment_count

 Title   : fetch_experiment_count
 Usage   : $count = $expa->fetch_experiment_count($where);
 Function: Fetch count of experiments from the DB with the given where
           clause.
 Args    : Optionally, a where clause.
 Returns : An integer count of the experiments fitting the select criteria.

=cut

sub fetch_experiment_count
{
    my ($self, $where) = @_;

    my $sql = qq{select count(*) from experiments};
	if ($where) {
        unless ($where =~ /^\s*where /) {
            $sql .= " where";
        }
		$sql .= " $where";
	}
	
    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch experiment count:\n$sql\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch experiment count:\n$sql\n" . $self->errstr;
        return;
    }

    my $count;
    unless (($count) = $sth->fetchrow_array()) {
        carp "Error fetching experiment count:\n$sql\n" . $self->errstr;
        return;
    }

    $sth->finish();

    return $count;
}

=head2 fetch_where

 Title   : fetch_where
 Usage   : $experiments = $expa->fetch_where($where);
 Function: Generic fetch method. Fetch experiment object(s) from the DB
           with the given where clause.
 Args    : Optionally, a where clause.
 Returns : Either an OPOSSUM::Experiment object or a reference to an array
           of OPOSSUM::Experiment objects depending on whether query returns
           1 or more rows and whether an array or scalar is expected by the
           caller.

=cut

sub fetch_where
{
    my ($self, $where) = @_;

    my $sql = "select id, FF_id, CNhs_id, type, method, name from experiments";

	if ($where) {
        unless ($where =~ /^\s*where / or $where =~ /^\s*order /) {
            $sql .= " where";
        }
		$sql .= " $where";
	}
	
    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch experiments:\n$sql\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch experiments:\n$sql\n" . $self->errstr;
        return;
    }

    my $row_count = 0;
    my @experiments;
    while (my @row = $sth->fetchrow_array) {
        $row_count++;

        my $experiment = OPOSSUM::Experiment->new(
            #-adaptor        => $self,
            -id             => $row[0],
            -FF_id          => $row[1],
            -CNhs_id        => $row[2],
            -type           => $row[3],
            -method         => $row[4],
            -name           => $row[5]
        );

        push @experiments, $experiment;
    }
    $sth->finish;

    return @experiments ? \@experiments : undef;
}

=head2 fetch_experiment_ids

 Title   : fetch_experiment_ids
 Usage   : $exp_ids = $expa->fetch_experiment_ids($where);
 Function: Fetch list of experiment IDs from the DB.
 Args    : Optionally a where clause.
 Returns : Reference to a list of internal experiment IDs. If no where
           clause is provided, returns all experiment IDs in the database.

=cut

sub fetch_experiment_ids
{
    my ($self, $where) = @_;

    my $sql = "select id from experiments";

	if ($where) {
        unless ($where =~ /^\s*where / or $where =~ /^\s*order /) {
            $sql .= " where";
        }
		$sql .= " $where";
	}

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error fetching experiment IDs\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error fetching experiment IDs\n" . $self->errstr;
        return;
    }

    my @ids;
    while (my ($id) = $sth->fetchrow_array) {
        push @ids, $id;
    }
    $sth->finish;

    if (wantarray) {
        return @ids;
    }

    return @ids ? \@ids : undef;
}

=head2 fetch_ff_ids

 Title   : fetch_ff_ids
 Usage   : $exp_ids = $expa->fetch_ff_ids($where);
 Function: Fetch list of FANTOM5 ontology IDs from the DB.
 Args    : Optionally a where clause.
 Returns : Reference to a list of FANTOM5 ontology IDs. If no where
           clause is provided, returns all FANTOM5 ontology IDs in the
           database.

=cut

sub fetch_ff_ids
{
    my ($self, $where) = @_;

    my $sql = "select distinct FF_id from experiments";

	if ($where) {
        unless ($where =~ /^\s*where / or $where =~ /^\s*order /) {
            $sql .= " where";
        }
		$sql .= " $where";
	}

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error fetching experiment IDs\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error fetching experiment IDs\n" . $self->errstr;
        return;
    }

    my @ids;
    while (my ($id) = $sth->fetchrow_array) {
        push @ids, $id;
    }
    $sth->finish;

    if (wantarray) {
        return @ids;
    }

    return @ids ? \@ids : undef;
}

=head2 fetch_by_id

 Title   : fetch_by_id
 Usage   : $experiment = $expa->fetch_by_id($id);
 Function: Fetch an experiment object from the DB using its ID.
 Args    : The unique internal experiment ID.
 Returns : An OPOSSUM::Experiment object.

=cut

sub fetch_by_id
{
    my ($self, $id) = @_;

    my $where = "where experiment_id = $id";

    my $experiments = $self->fetch_where($where);

    if ($experiments && $experiments->[0]) {
        return $experiments->[0];
    }

    return undef;
}

=head2 fetch_by_experiment_id

 Title   : fetch_by_experiment_id
 Usage   : $experiment = $expa->fetch_by_experiment_id($id);
 Function: Fetch a experiment object from the DB using its ID. Synonym of
           fetch_by_id.
 Args    : The unique internal experiment ID.
 Returns : An OPOSSUM::Experiment object.

=cut

sub fetch_by_experiment_id
{
    my ($self, $id) = @_;

    return $self->fetch_by_id($id);
}

=head2 fetch_by_ff_id

 Title   : fetch_by_ff_id
 Usage   : $experiment = $expa->fetch_by_ff_id($ff_id);
 Function: Fetch an experiment object from the DB using its FANTOM5 ID.
 Args    : The unique FANTOM5 experiment ID.
 Returns : An OPOSSUM::Experiment object.

=cut

sub fetch_by_ff_id
{
    my ($self, $id) = @_;

    #
    # Strip leading 'FF:' if any
    #
    $id =~ s/^FF://;

    my $where = "where FF_id = '$id'";

    my $experiments = $self->fetch_where($where);

    if ($experiments && $experiments->[0]) {
        return $experiments->[0];
    }

    return undef;
}

=head2 fetch_by_term

 Title   : fetch_by_term
 Usage   : $experiments = $expa->fetch_by_term($term);
 Function: Fetch experiment object(s) from the DB using a search term
           (substring) within the experiment name.
 Args    : A search term.
 Returns : An array ref of OPOSSUM::Experiment objects.

=cut

sub fetch_by_term
{
    my ($self, $term) = @_;

    return if !$term;

    my $where = "where name like '\%$term\%'";

    return $self->fetch_where($where);
}

=head2 fetch_by_experiment_ids

 Title   : fetch_by_experiment_ids
 Usage   : $experiments = $expa->fetch_by_experiment_ids($ids);
 Function: Fetch a list of experiment objects from the DB according to a
           list of experiment IDs.
 Args    : A reference to a list of unique internal experiment IDs.
 Returns : A reference to a list of OPOSSUM::Experiment objects.

=cut

sub fetch_by_experiment_ids
{
	my ($self, $experiment_ids) = @_;
	
	my $where = "id in (" . join(",", @$experiment_ids) . ")";

	return $self->fetch_where($where);
}

=head2 fetch_by_ff_ids

 Title   : fetch_by_ff_ids
 Usage   : $experiments = $expa->fetch_by_ff_ids($ff_id_list);
 Function: Fetch a list of experiment objects from the DB according to a
           list of FANTOM5 experiment IDs.
 Args    : A reference to a list of unique FANTOM5 experiment IDs.
 Returns : A reference to a list of OPOSSUM::Experiment objects.

=cut

sub fetch_by_ff_ids
{
	my ($self, $ff_ids) = @_;

    my @stripped_ids;
    foreach my $ff_id (@$ff_ids) {
        $ff_id =~ s/^FF://;
        push @stripped_ids, $ff_id;
    }

	my $where = "FF_id in ('" . join("','", @stripped_ids) . "')";

	return $self->fetch_where($where);
}

=head2 fetch_by_terms

 Title   : fetch_by_terms
 Usage   : $experiments = $expa->fetch_by_terms($terms);
 Function: Fetch a list of experiment objects from the DB according to a
           list of search terms.
 Args    : A reference to a list of search terms.
 Returns : A reference to a list of OPOSSUM::Experiment objects.

=cut

sub fetch_by_terms
{
	my ($self, $terms) = @_;
	
    my $where;
    my $first = 1;
    foreach my $term (@$terms) {
        if ($first) {
            $where = "name like '\%$term\%'";
            $first = 0;
        } else {
            $where .= " or name like '\%$term\%'";
        }
    }

	return $self->fetch_where($where);
}

=head2 fetch_random_experiments

 Title   : fetch_random_random_experiments
 Usage   : $experiments = $expa->fetch_random_experiments(
               -num_experiments => 5,
               -terms           => $search_terms
           );
 Function: Fetches a random list of OPOSSUM::Experiment objects.
 Args    : The number of experiments to retrieve and optionally a search
           term or listref of search terms of experiments to be
           fetched.
 Returns : A listref of OPOSSUM::Experiment objects.

=cut

sub fetch_random_experiments
{
	my ($self, %args) = @_;
	
	my $num_experiments = $args{-num_experiments};
	my $terms           = $args{-terms};
	
    my $where;

    my $ref = ref $terms;
    if (defined $terms
        && (!$ref || ($ref eq 'ARRAY' && $terms->[0]))
    ) {
        if ($ref eq 'ARRAY') {
            my $first = 1;
            foreach my $term (@$terms) {
                if ($first) {
                    $where = "name like '\%$term\%'";
                    $first = 0;
                } else {
                    $where .= " or name like '\%$term\%'";
                }
            }
        } else {
            $where = "name like '\%$terms\%'";
        }
	}

	$where .= " order by rand() limit $num_experiments";
	
	return $self->fetch_where($where);
}

=head2 fetch_random_experiment_ids

 Title   : fetch_random_random_experiment_ids
 Usage   : $exp_ids = $expa->fetch_random_experiment_ids($num
               -num_experiments => 5,
               -terms           => $search_terms
           );
 Args    : The number of experiments to retrieve and an optional search
           term or listref of search terms of experiments to be fetched.
 Function: Fetches a random list of experiment IDs.
 Returns : A listref of experiment IDs.

=cut

sub fetch_random_experiment_ids
{
	my ($self, %args) = @_;
	
	my $num_experiments = $args{-num_experiments};
	my $terms           = $args{-terms};
	
    my $where;

    my $ref = ref $terms;
	if (defined $terms
        && (!$ref || ($ref eq 'ARRAY' && $terms->[0]))
    ) {
        if ($ref eq 'ARRAY') {
            my $first = 1;
            foreach my $term (@$terms) {
                if ($first) {
                    $where = "name like '\%$term\%'";
                    $first = 0;
                } else {
                    $where .= " or name like '\%$term\%'";
                }
            }
        } else {
            $where = "name like '\%$terms\%'";
        }
	}

	$where .= " order by rand() limit $num_experiments";
	
	return $self->fetch_experiment_ids($where);
}

=head2 store

 Title   : store
 Usage   : $id = $expa->store($experiment);
 Function: Store experiment in the database.
 Args    : The experiment (OPOSSUM::Experiment) to store.
 Returns : 1 on success, 0 on failure.

=cut

sub store
{
    my ($self, $experiment) = @_;

    if (!ref $experiment || !$experiment->isa('OPOSSUM::Experiment')) {
        carp "Not an OPOSSUM::Experiment object";
        return;
    }

    my $sql = qq{
        insert into experiments (id, FF_id, CNhs_id, type, method, name)
        values (?,?,?,?,?,?)};

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing insert experiment statement\n" . $self->errstr;
        return;
    }

    if (!$sth->execute(
        $experiment->id, $experiment->FF_id, $experiment->CNhs_id,
        $experiment->type, $experiment->method, $experiment->name
    )) {
        carp "Error inserting experiment\n" . $self->errstr;
        return 0;
    }
    $sth->finish;

    return 1;
}

1;
