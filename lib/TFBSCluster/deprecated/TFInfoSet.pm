=head1 NAME

TFBSCluster::TFInfoSet.pm - module to hold a set of TFInfo objects

=head1 DESCRIPTION

This module uses hash based methods to index the TFInfo objects by their database
IDs or JASPAR IDs for more efficient access to individuel objects and their matrices

=head1 AUTHOR

 Andrew Kwon
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: tjkwon@cmmt.ubc.ca

=head1 METHODS

=cut

package TFBSCluster::TFInfoSet;

use strict;

use Carp;

=head2 new

 Title    : new
 Usage    : $tfs = TFBSCluster::TFInfoSet->new();
 Function : Create a new TFBSCluster::TFInfoSet object.
 Returns  : An TFBSCluster::TFInfoSet object.
 Args     : None.

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {
        _params     => {},
        _tf_info_hash    => {} 
    }, ref $class || $class;

    if ($args{-tf_info_list}) {
        $self->add_tf_info_list($args{-tf_info_list});
    }

    if ($args{-tf_info_set}) {
        $self->add_tf_info_set($args{-tf_info_set});
    }

    return $self;
}

=head2 ids

 Title    : ids
 Usage    : $ids = $tfs->ids();
 Function : Return the IDs of the TFInfo objects in the set
 Returns  : A list/listref of TFInfo IDs
 Args     : None

=cut

sub ids
{
    my @ids = keys %{$_[0]->{_tf_info_hash}};

    #if (wantarray()) {
    #    return @ids;
    #} else {
        return @ids ? \@ids : undef;
    #}
}

=head2 external_ids

 Title    : external_ids
 Usage    : $ids = $tis->external_ids();
 Function : Returns the external DB IDs of the TFBS contained in the set
 Returns  : A list/listref of external TF IDs
 Args     : None

=cut

sub external_ids
{
    my @ex_ids;
    foreach my $id (keys %{$_[0]->{_tf_info_hash}})
    {
        my $ti = $_[0]->{_tf_info_hash}->{$id};
        push @ex_ids, $ti->external_id;
    }
    
    return @ex_ids ? \@ex_ids : undef;
}

=head2 tf_ids

 Title    : tf_ids
 Usage    : $ids = $tfs->tf_ids();
 Function : Alternate name for ids()

=cut

sub tf_ids
{
    return $_[0]->ids();
}

=head2 size

 Title    : size
 Usage    : $size = $tfs->size();
 Function : Return the size of the set (number of TF objects)
 Returns  : An integer
 Args     : None

=cut

sub size
{
    return scalar keys %{$_[0]->{_tf_info_hash}} || 0;
}

=head2 add_tf_info

 Title    : add_tf_info
 Usage    : $tis->add_tf_info($ti);
 Function : Add a new TFInfo object to the set
 Returns  : TFInfo object added
 Args     : A TFInfo object

=cut

sub add_tf_info
{
    my ($self, $tf_info) = @_;

    return if !$tf_info;

    unless (ref $tf_info && $tf_info->isa("TFBSCluster::TFInfo")) {
        carp "add_tf_info() argument is not a TFBSCluster::TFInfo object";
        return;
    }

    my $tid = $tf_info->id();
    if ($self->{_tf_info_hash}->{$tid}) {
        carp "TFInfo $tid is already in the set (IDs must be unique)";
        return;
    }

    $self->{_tf_info_hash}->{$tid} = $tf_info;
}

=head2 get_tf_info

 Title    : get_tf_info
 Usage    : $tfi = $tfs->get_tf_info($id);
 Function : Return a single TFInfo from the set by its id
 Returns  : A TFBSCluster::TFInfo object
 Args     : id of the TFInfo object

=cut

sub get_tf_info
{
    my ($self, $tid) = @_;

    my $tfi = $self->{_tf_info_hash}->{$tid};
    
    return $tfi ? $tfi : undef;
}

=head2 get_tf_info_by_external_id

 Title    : get_tf_info_by_external_id
 Usage    : $tfi = $tfs->get_tf_info_by_external_id($id);
 Function : Return a single TFInfo from the set by its external id
 Returns  : A TFBSCluster::TFInfo object
 Args     : external id of the TFInfo object

=cut

sub get_tf_info_by_external_id
{
    my ($self, $exid) = @_;

    my $tfi;
    foreach my $tid (keys %{$self->{_tf_info_hash}})
    {
        $tfi = $self->{_tf_info_hash}->{$tid};
        if ($exid == $tfi->external_id) {
            return $tfi;
        }
    }
    
    return undef;
}

=head2 add_tf_info_list

 Title    : add_tf_info_list
 Usage    : $tfs->add_tf_info_list();
 Function : Add a list of TFInfo objects to the set
 Returns  : Nothing
 Args     : A listref of TFInfo objects

=cut

sub add_tf_info_list
{
    my ($self, $tf_info_list) = @_;

    return unless $tf_info_list && $tf_info_list->[0];

    unless ($tf_info_list->[0]->isa('TFBSCluster::TFInfo')) {
        carp("Not a TFBSCluster::TFInfo listref");
        return;
    }

    foreach my $tf_info (@$tf_info_list) {
        $self->add_tf_info($tf_info);
    }
}

=head2 add_tf_info_set

 Title    : add_tf_info_set
 Usage    : $tfs->add_tf_info_set();
 Function : Add a set of TFBSCluster::TFInfo objects to the set
 Returns  : Nothing
 Args     : A TFBSCluster::TFInfoSet object

=cut

sub add_tf_info_set
{
    my ($self, $tf_info_set) = @_;

    return unless $tf_info_set;;

    unless ($tf_info_set->isa('TFBSCluster::TFInfoSet')) {
        carp("Not an TFBSCluster::TFInfoSet");
        return;
    }

    return unless $tf_info_set->size > 0;

    my $tf_infos = $tf_info_set->get_tf_info_list;
    foreach my $ti (@$tf_infos) {
        $self->add_tf_info($ti);
    }
}

=head2 get_tf_info_list

 Title    : get_tf_info_list
 Usage    : $tf_info_list = $tfs->get_tf_info_list($sort_field);
 Function : Return a list of the TFInfo objects in the set
 Returns  : A listref of TFBSCluster::TFInfo objects
 Args     : Optionally a field to sort TFInfo objects on (e.g. id)

=cut

sub get_tf_info_list
{
    my ($self, $sort_field) = @_;

    my $ids = $self->ids();

    return if !$ids;

    my @tf_info_list;
    foreach my $id (@$ids) {
        push @tf_info_list, $self->get_tf_info($id);
    }

    if ($sort_field) {
        if (uc $sort_field eq 'id') {
            @tf_info_list = sort {$a->id() cmp $b->id()} @tf_info_list;
        } elsif (uc $sort_field eq 'jaspar_id') {
            @tf_info_list = sort {$a->jaspar_id() cmp $b->jaspar_id()} @tf_info_list;
        }
    }

    return @tf_info_list ? \@tf_info_list : undef;
}

=head2 get_tf_info_set

 Title    : get_tf_info_set
 Usage    : $tf_info_set = $tfs->get_tf_info_set();
 Function : Return a TFInfoSet from this set (copy)
 Returns  : A TFBS::tf_infoSet object
 Args     : None.

=cut

sub get_tf_info_set
{
    my $self = shift;

    my $ids = $self->ids();

    return if !$ids;

    my $tf_info_set = TFBSCluster::TFInfoSet->new();

    foreach my $id (@$ids) {
        $tf_info_set->add_tf_info($self->get_tf_info($id));
    }

    return $tf_info_set;
}

=head2 subset

 Title    : subset
 Usage    : $tf_subset = $tfs->subset(
                -ids         => $ids,
                -external_ids=> $ex_ids,
                -sources     => $sources,
                -collections => $collections,
                -tax_groups  => $tax_groups,
                -min_ic      => $min_ic,
            );
 Function : Return a subset of this set based on arguments passed
 Returns  : An TFBSCluster::TFInfoSet object
 Args     : Optionally IDs of the matrices; overides all other
                arguments
            Optionally a collection or list of collections
            Optionally a tax group or list of tax groups
            Optionally a minimum information content

=cut

sub subset
{
    my ($self, %args) = @_;

    my $ids         = $args{-ids};
    my $ex_ids      = $args{-external_ids};
    my $sources     = $args{-sources};
    my $collections = $args{-collections};
    my $tax_groups  = $args{-tax_groups};
    my $min_ic      = $args{-min_ic};

    my $subset = TFBSCluster::TFInfoSet->new();

    if ($ids) {
        my @id_list;
        if (ref $ids eq 'ARRAY') {
            # -ids arg value is a listref of IDs
            @id_list = @$ids;
        } else {
            # -ids arg value is a single ID
            push @id_list, $ids;
        }

        foreach my $id (@id_list) {
            my $tfi = $self->get_tf_info($id);
            $subset->add_tf_info($tfi) if $tfi;
        }
    } elsif ($ex_ids) {
        my @id_list;
        if (ref $ids eq 'ARRAY') {
            # -ids arg value is a listref of IDs
            @id_list = @$ids;
        } else {
            # -ids arg value is a single ID
            push @id_list, $ids;
        }

        foreach my $id (@id_list) {
            my $tfi = $self->get_tf_info_by_external_id($id);
            $subset->add_tf_info($tfi) if $tfi;
        }
    } else {
        my %collection_hash;
        if ($collections) {
            if (ref $collections eq 'ARRAY') {
                # -collections arg value is a listref of values
                foreach my $collection (@$collections) {
                    $collection_hash{$collection} = 1;
                }
            } else {
                # -collections arg value is a single value
                $collection_hash{$collections} = 1;
            }
        }

        my %tax_group_hash;
        if ($tax_groups) {
            if (ref $tax_groups eq 'ARRAY') {
                # -tax_groups arg value is a listref of values
                foreach my $tax_group (@$tax_groups) {
                    $tax_group_hash{$tax_group} = 1;
                }
            } else {
                # -tax_groups arg value is a single value
                $tax_group_hash{$tax_groups} = 1;
            }
        }

        $min_ic = 0 if !$min_ic;

        # Get all the TFs
        foreach my $id (@{$self->ids()}) {
            my $tfi = $self->get_tf_info($id);

            if ($tfi) {
                my $include = 1;

                if ($include && %collection_hash) {
                    $include = 0
                        if !$collection_hash{$tfi->collection};
                }

                if ($include && %tax_group_hash) {
                    $include = 0
                        if !$tax_group_hash{$tfi->tax_group};
                }

                if ($include && $tfi->ic < $min_ic) {
                    $include = 0;
                }

                if ($include) {
                    $subset->add_tf_info($tfi);
                }
            }
        }
    }

    #
    # First set subset params to same as this set
    #
    foreach my $param_name ($self->param()) {
        $subset->param($param_name, $self->param($param_name));
    }

    #
    # Overwrite subset params depending on args passed
    #
    foreach my $arg_key (keys %args) {
        if (   $arg_key eq '-collections' || $arg_key eq '-tax_groups'
            || $arg_key eq '-min_ic'
        )
        {
            my $arg_name = $arg_key;
            $arg_name =~ s/^-//;
            
            $subset->param($arg_name, $args{$arg_key});
        }
    }

    return $subset;
}

=head2 param

 Title    : param
 Usage    : $value = $tfs->param($param)
            or $tfs->param($param, $value);
 Function : Get/set the value of a parameter
 Returns  : Value of the named parameter
 Args     : [1] name of a parameter
            [2] on set, the value of the parameter

=cut

sub param
{
    my ($self, $param, $value) = @_;

    if ($param) {
        if (defined $value) {
            $self->{_params}->{$param} = $value;
        }

        return $self->{_params}->{$param};
    }

    return keys %{$self->{_params}};
}

1;
