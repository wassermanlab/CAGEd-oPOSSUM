=head1 NAME

OPOSSUM::SearchRegionSet.pm - module to hold a set of search regions
(OPOSSUM::SearchRegion objects)

=head1 DESCRIPTION

This object uses hash based methods to store and index OPOSSUM::SearchRegion
objects by their IDs for more efficient access to individuel search regions.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::SearchRegionSet;

use strict;

use Carp;

=head2 new

 Title    : new
 Usage    : $srs = OPOSSUM::SearchRegionSet->new();
 Function : Create a new OPOSSUM::SearchRegionSet object.
 Returns  : An OPOSSUM::SearchRegionSet object.
 Args     : None.

=cut

sub new
{
    my ($class, %args) = @_;

    if ($args{-sr_list} && $args{-sr_set}) {
        carp "Please provide either -sr_list or -sr_set argument,"
            . " but not both\n";
        return;
    }

    my $self = bless {
        _params     => {},
        _sr_hash    => {} 
    }, ref $class || $class;

    if ($args{-sr_list}) {
        $self->add_search_region_list($args{-sr_list});
    }

    if ($args{-sr_set}) {
        $self->add_search_region_set($args{-sr_set});
    }

    return $self;
}

=head2 ids

 Title    : ids
 Usage    : $ids = $srs->ids();
 Function : Return the IDs of the search region objects in the set
 Returns  : A list/listref of search region IDs
 Args     : None

=cut

sub ids
{
    my @ids = keys %{$_[0]->{_sr_hash}};

    #if (wantarray()) {
    #    return @ids;
    #} else {
        return @ids ? \@ids : undef;
    #}
}

=head2 search_region_ids

 Title    : search_region_ids
 Usage    : $ids = $srs->search_region_ids();
 Function : Alternate name for ids()

=cut

sub search_region_ids
{
    return $_[0]->ids();
}

=head2 size

 Title    : size
 Usage    : $size = $srs->size();
 Function : Return the size of the set (number of search region objects)
 Returns  : An integer
 Args     : None

=cut

sub size
{
    return scalar keys %{$_[0]->{_sr_hash}} || 0;
}

=head2 add_search_region

 Title    : add_search_region
 Usage    : $srs->add_search_region($sr);
 Function : Add a new search region to the set
 Returns  : OPOSSUM::SearchRegion added
 Args     : A OPOSSUM::SearchRegion object

=cut

sub add_search_region
{
    my ($self, $sr) = @_;

    return if !$sr;

    unless (ref $sr && $sr->isa("OPOSSUM::SearchRegion")) {
        carp
              "add_search_region() argument is not an OPOSSUM::SearchRegion"
            . " object";
        return;
    }

    my $sr_id = $sr->id();
    if ($self->{_sr_hash}->{$sr_id}) {
        carp "Search region $sr_id is already in the set (IDs must be unique)";
        return;
    }

    #
    # It's probably bad to add search region to hash as a ref instead of copying
    # but there is no OPOSSUM::SearchRegion copy function or other way to easily
    # copy OPOSSUM::SearchRegion objects
    #
    $self->{_sr_hash}->{$sr_id} = $sr;
}

=head2 get_search_region

 Title    : get_search_region
 Usage    : $sr = $srs->get_search_region($id);
 Function : Return a single search region from the set by it's ID
 Returns  : A OPOSSUM::SearchRegion object
 Args     : ID of the search region

=cut

sub get_search_region
{
    my ($self, $sr_id) = @_;

    return if !defined $sr_id;

    return $self->{_sr_hash}->{$sr_id};
}

=head2 add_search_region_list

 Title    : add_search_region_list
 Usage    : $srs->add_search_region_list();
 Function : Add a list of OPOSSUM::SearchRegion objects to the set
 Returns  : Nothing
 Args     : A listref of OPOSSUM::SearchRegion objects

=cut

sub add_search_region_list
{
    my ($self, $sr_list) = @_;

    return unless $sr_list && $sr_list->[0];

    unless ($sr_list->[0]->isa('OPOSSUM::SearchRegion')) {
        carp("Not an OPOSSUM::SearchRegion listref");
        return;
    }

    foreach my $sr (@$sr_list) {
        $self->add_search_region($sr);
    }
}

=head2 add_search_region_set

 Title    : add_search_region_set
 Usage    : $srs->add_search_region_set();
 Function : Add a set of OPOSSUM::SearchRegion objects to the set
 Returns  : Nothing
 Args     : A OPOSSUM::SearchRegionSet object

=cut

sub add_search_region_set
{
    my ($self, $sr_set) = @_;

    return unless $sr_set;;

    unless ($sr_set->isa('OPOSSUM::SearchRegionSet')) {
        carp("Not an OPOSSUM::SearchRegionSet");
        return;
    }

    return unless $sr_set->size > 0;

    my $iter = $sr_set->Iterator();
    while (my $sr = $iter->next()) {
        $self->add_search_region($sr);
    }
}

=head2 get_search_region_list

 Title    : get_search_region_list
 Usage    : $sr_list = $srs->get_search_region_list($sort_field);
 Function : Return a list of the search region objects in the set
 Returns  : A listref OPOSSUM::SearchRegion objects
 Args     : Optional field(s) to sort search regions on
            (e.g. ID or position)

=cut

sub get_search_region_list
{
    my ($self, $sort_field) = @_;

    my $ids = $self->ids();

    return if !$ids;

    my @sr_list;
    foreach my $id (@$ids) {
        push @sr_list, $self->get_search_region($id);
    }

    if ($sort_field) {
        $sort_field = lc $sort_field;

        if ($sort_field eq 'id' || $sort_field =~ /_id$/) {
            @sr_list = sort {$a->id() <=> $b->id()} @sr_list;
        } elsif (
               $sort_field =~ /chrom/
            || $sort_field =~ /start/
            || $sort_field =~ /position/
            || $sort_field =~ /location/
        ) {
            @sr_list = sort {
                    (($a->chrom =~ /\d+/)
                        ? sprintf("%02d", $a->chrom())
                        : uc $a->chrom())
                cmp (($b->chrom =~ /\d+/)
                        ? sprintf("%2d", $b->chrom())
                        : uc $b->chrom())
                || $a->start() <=> $b->start()
                || $a->end() <=> $b->end()
            } @sr_list;
        }
    }

    return @sr_list ? \@sr_list : undef;
}

=head2 subset

 Title    : subset
 Usage    : $sr_subset = $srs->subset(
                -ids         => $ids,
                -chrom       => $chromosome
            );
 Function : Return a subset of this set based on arguments passed (either
            a list of IDs or chromosome name).
 Returns  : An OPOSSUM::SearchRegionSet object
 Args     : Optional ID(s) of the search regions (single ID or listref of
            IDs) - overides all other arguments
            Optional chromosome name

=cut

sub subset
{
    my ($self, %args) = @_;

    my $ids         = $args{-ids};
    my $chrom       = $args{-chrom};

    my $subset = OPOSSUM::SearchRegionSet->new();

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
            my $sr = $self->get_search_region($id);

            $subset->add_search_region($sr) if $sr;
        }
    } else {
        # Get all the TFs
        foreach my $id (@{$self->search_region_ids()}) {
            my $sr = $self->get_search_region($id);

            if ($sr) {
                if (uc $sr->chrom eq uc $chrom) {
                    $subset->add_search_region($sr);
                }
            }
        }
    }

    #
    # Set subset params to same as this set
    #
    foreach my $param_name ($self->param()) {
        $subset->param($param_name, $self->param($param_name));
    }

    #
    # Overwride subset params depending on args passed
    #
    #foreach my $arg_key (keys %args) {
    #    if (   $arg_key eq '-collections' || $arg_key eq '-tax_groups'
    #        || $arg_key eq '-min_ic'
    #    )
    #    {
    #        my $arg_name = $arg_key;
    #        $arg_name =~ s/^-//;
    #        
    #        $subset->param($arg_name, $args{$arg_key});
    #    }
    #}

    return $subset;
}

=head2 param

 Title    : param
 Usage    : $value = $srs->param($param)
            or $srs->param($param, $value);
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
