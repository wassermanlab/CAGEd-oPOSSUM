=head1 NAME

OPOSSUM::DBSQL::SearchRegionAdaptor - Adaptor for MySQL queries to retrieve and
store search region information.

=head1 SYNOPSIS

$sra = $db_adaptor->get_SearchRegionAdaptor();

=head1 DESCRIPTION

The search_regions table of the oPOSSUM database stores the search regions
associated with the TSSs. These are the initial search regions which are
computed when the DB is first built. A maximum flanking region (2000 bp)
is placed around each TSS. Overlapping regions are merged and stored in
the search_regions table. The search regions can then be used as a bin to
rapidly retrieve TFBSs.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::DBSQL::SearchRegionAdaptor;

use strict;

use Carp;

use OPOSSUM::DBSQL::BaseAdaptor;
use OPOSSUM::SearchRegion;

use vars '@ISA';
@ISA = qw(OPOSSUM::DBSQL::BaseAdaptor);

=head2 new

 Title   : new
 Usage   : $sra = OPOSSUM::DBSQL::SearchRegionAdaptor->new($db_adaptor);
 Function: Construct a new SearchRegionAdaptor object
 Args    : An OPOSSUM::DBSQL::DBAdaptor object
 Returns : a new OPOSSUM::DBSQL::SearchRegionAdaptor object

=cut

sub new
{
    my ($class, @args) = @_;

    $class = ref $class || $class;

    my $self = $class->SUPER::new(@args);

    return $self;
}

=head2 fetch_ids

 Title   : fetch_ids
 Usage   : $ids = $sra->fetch_ids();
 Function: Fetch a list of search region IDs from the DB by optional where
           clause.
 Args    : Optional where clause.
 Returns : A list ref of search region IDs.

=cut

sub fetch_ids
{
    my ($self, $where) = @_;

    my $sql = qq{select id from search_regions};

    if ($where) {
        unless ($where =~ /^\s*where\s+/) {
            $where = " where $where";
        }
        $sql .= $where;
    }

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch search region IDs:\n$sql\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch search region IDs:\n$sql\n" . $self->errstr;
        return;
    }

    my @ids;
    while (my @row = $sth->fetchrow_array) {
        push @ids, $row[0];
    }

    return @ids if wantarray;

    return @ids ? \@ids : undef;
}

=head2 fetch_where

 Title   : fetch_where
 Usage   : $search_regions = $sra->fetch_where($where);
 Function: Fetch a list of search regions from the DB by optional where
           clause.
 Args    : Optional where clause.
 Returns : A list ref of OPOSSUM::SearchRegion objects.

=cut

sub fetch_where
{
    my ($self, $where) = @_;

    my $sql = qq{select id, chrom, start, end from search_regions};

    if ($where) {
        unless ($where =~ /^\s*where\s+/) {
            $where = " where $where";
        }
    }

    $sql .= $where;

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch search regions:\n$sql\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch search regions:\n$sql\n" . $self->errstr;
        return;
    }

    my @srs;
    while (my @row = $sth->fetchrow_array) {
        push @srs, OPOSSUM::SearchRegion->new(
            -id     => $row[0],
            -chrom  => $row[1],
            -start  => $row[2],
            -end    => $row[3]
        );
    }

    return @srs ? \@srs : undef;
}

=head2 fetch

 Title   : fetch
 Usage   : $search_regions = $sra->fetch(
               -ids => $ids
           );
 Function: Fetch a list of search regions from the DB by optional arguments.
 Args    : Optional named arguments
               -ids     => a search region ID or listref of IDs
 Returns : A list ref of OPOSSUM::SearchRegion objects.

=cut

sub fetch
{
    my ($self, %args) = @_;

    my $ids = $args{-ids};

    my $where;

    my $ref = ref $ids;
    if (defined $ids
        && (!$ref || ($ref eq 'ARRAY' && $ids->[0]))
    ) {
        if ($ref eq 'ARRAY') {
            $where .= " id in (";
            $where .= join ',', @$ids;
            $where .= ")";
        } else {
            $where .= " id = $ids";
        }
    }

    return $self->fetch_where($where);
}

=head2 store

 Title   : store
 Usage   : $sra->store($search_region);
 Function: Store search_region in the database.
 Args    : An OPOSSUM::SearchRegion object
 Returns : True on success, false otherwise.

=cut

sub store
{
    my ($self, $search_region) = @_;

    my $sql = qq{insert into search_regions (id, chrom, start, end)
                 values (?, ?, ?, ?)};

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing insert search region statement\n" . $self->errstr;
        return;
    }

    my $ok = 1;
    unless ($sth->execute(
        $search_region->id, $search_region->chrom, $search_region->start,
        $search_region->end
    )) {
        carp sprintf(
            "Error inserting search region %d chr%s:%d-%d\n%s\n",
            $search_region->id,
            $search_region->chrom,
            $search_region->start,
            $search_region->end,
            $self->errstr
        );
        $ok = 0;
    }

    return $ok;
}

=head2 store_list

 Title   : store_list
 Usage   : $sra->store_list($search_regions);
 Function: Store search regions in the database.
 Args    : A listref of OPOSSUM::SearchRegion objects
 Returns : True on success, false otherwise.

=cut

sub store_list
{
    my ($self, $search_regions) = @_;

    my $sql = qq{insert into search_regions (id, chrom, start, end)
                 values (?, ?, ?, ?)};

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing insert search regions statement\n"
            . $self->errstr;
        return;
    }

    my $ok = 1;
    foreach my $search_region (@$search_regions) {
        if (!$sth->execute($search_region->id, $search_region->chrom,
            $search_region->start, $search_region->end
        )) {
            carp sprintf(
                "Error inserting search region %d chr%s:%d-%d\n%s\n",
                $search_region->id,
                $search_region->chrom,
                $search_region->start,
                $search_region->end,
                $self->errstr
            );
            # keep trying to store search_regions but return error status...
            $ok = 0;
        }
    }

    return $ok;
}

1;
