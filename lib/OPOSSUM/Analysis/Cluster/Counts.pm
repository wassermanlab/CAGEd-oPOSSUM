=head1 NAME

OPOSSUM::Analysis::Cluster::Counts - Object to store the count of cluster cluster
hits on the gene sequences

=head1 SYNOPSIS

 my $aca = $db_adaptor->get_AnalysisClusterCountsAdaptor();

 my $counts = $aca->fetch_counts(
     -conservation_level     => 2,
     -threshold_level        => 3,
     -search_region_level    => 1
 );

=head1 DESCRIPTION

This object stores a count of the number of times each Cluster cluster was
found on each gene. These counts can be retrieved from the database
by the OPOSSUM::DBSQL::Analysis::Cluster::CountsAdaptor. This object can be
passed to the OPOSSUM::Analysis::Cluster::Fisher and
OPOSSUM::Analysis::Cluster::Zscore modules.

Note: for cluster analysis, simply counting hits is not enough.
One must make sure that overlapping cluster belonging to the same cluster should not be
read more than once - so have a separate tfbs_cluster_counts table

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

 Modified by Shannan Ho Sui on Dec 21, 2006 to accommodate schema changes

=head1 METHODS

=cut

package OPOSSUM::Analysis::Cluster::Counts;

use strict;

use Carp;

=head2 new

 Title    : new
 Usage    : $counts = OPOSSUM::Analysis::Cluster::Counts->new();
 Function : Create a new OPOSSUM::Analysis::Cluster::Counts object.
 Returns  : An OPOSSUM::Analysis::Cluster::Counts object.

=cut

sub new
{
    my ($class, %args) = @_;

    my $cluster_ids     = $args{-cluster_ids};
    my $seq_cluster_map = $args{-seq_cluster_map};

    unless ($cluster_ids) {
        carp "No TF cluster IDs provided\n";
        return;
    }

    unless ($seq_cluster_map) {
        carp "No sequence TFBS cluster map provided\n";
        return;
    }

    my @seq_ids = sort keys %$seq_cluster_map;

    unless (@seq_ids) {
        carp "No region/sequence/gene IDs retrieved from seq./TFBS cluster map\n";
        return;
    }


    my $self = bless {
        -seq_ids            => \@seq_ids,
        -cluster_ids        => $cluster_ids,
        -seq_exists         => undef,
        -cluster_exists     => undef,
        _seq_cluster_counts => {},
		_seq_cluster_lengths=> {},
        _cluster_seq_exists => {},
        _params             => {}
    }, ref $class || $class;

    foreach my $seq_id (@seq_ids) {
        $self->{-seq_exists}->{$seq_id} = 1;
        foreach my $cl_id (@$cluster_ids) {
            $self->{-cluster_exists}->{$cl_id} = 1;

            my $count = 0;
            my $length = 0;
            my $sites = $seq_cluster_map->{$seq_id}->{$cl_id};
            if ($sites && $sites->[0]) {
                $count = scalar @$sites;

                foreach my $site (@$sites) {
                    $length += length($site->seq);
                }
            }
            $self->seq_cluster_count($seq_id, $cl_id, $count);
            $self->seq_cluster_length($seq_id, $cl_id, $length);
        }
    }

    return $self;
}

=head2 param

 Title    : param
 Usage    : $val = $counts->param($param)
	        or $counts->param($param, $value);
 Function : Get/set a value of a counts parameter.
 Returns  : The value of the names parameter.
 Args     : The name of the parameter to get/set.
            optionally the value of the parameter.

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

=head2 seq_ids

 Title    : seq_ids
 Usage    : $gids = $counts->seq_ids()
 Function : Get the list of gene IDs stored in the counts object.
 Returns  : A reference to a list of gene IDs.
 Args     : None.

=cut

sub seq_ids
{
    my $self = shift;

    return $self->{-seq_ids};
}

=head2 get_all_seq_ids

 Title    : get_all_seq_ids
 Usage    : $gids = $counts->get_all_seq_ids()
 Function : Get the list of gene IDs. This is a synonym for the
            get variant of the seq_ids method.
 Returns  : A reference to a list of gene IDs.
 Args     : None.

=cut

sub get_all_seq_ids
{
    my $self = shift;

    return $self->seq_ids();
}

=head2 cluster_ids

 Title    : cluster_ids
 Usage    : $cids = $counts->cluster_ids()
 Function : Get the list of Cluster IDs stored in the counts object.
 Returns  : A reference to a list of Cluster IDs.
 Args     : None.

=cut

sub cluster_ids
{
    my $self = shift;

    return $self->{-cluster_ids}
}

=head2 get_all_cluster_ids

 Title    : get_all_cluster_ids
 Usage    : $tfids = $counts->get_all_cluster_ids()
 Function : Get the list of Cluster IDs. This is a synonym for the get
            variant of the cluster_ids method.
 Returns  : A reference to a list of Cluster IDs.
 Args     : Optionally a reference to a list of Cluster IDs.

=cut

sub get_all_cluster_ids
{
    my $self = shift;

    return $self->cluster_ids();
}

=head2 conserved_region_length_set

 Title    : conserved_region_length_set
 Usage    : This method is deprecated.

=cut

sub conserved_region_length_set
{
    carp "conserved_region_length_set() is deprecated\n";
}

=head2 get_conserved_region_length

 Title    : get_conserved_region_length
 Usage    : This method is deprecated.

=cut

sub get_conserved_region_length
{
    carp "get_conserved_region_length() is deprecated\n";
}

=head2 num_seqs

 Title    : num_seqs
 Usage    : $num = $counts->num_seqs()
 Function : Get the number of genes/promoters in the counts object
 Returns  : An integer.
 Args     : None.

=cut

sub num_seqs
{
    my $self = shift;

    my $num_seqs = 0;
    if ($self->seq_ids()) {
        $num_seqs = scalar @{$self->seq_ids()};
    }

    return $num_seqs;
}

=head2 num_clusters

 Title    : num_clusters
 Usage    : $num = $counts->num_clusters()
 Function : Get the number of Clusters in the counts object
 Returns  : An integer.
 Args     : None.

=cut

sub num_clusters
{
    my $self = shift;

    my $num_tfs = 0;
    if ($self->cluster_ids()) {
        $num_tfs = scalar @{$self->cluster_ids()};
    }

    return $num_tfs;
}

=head2 seq_exists

 Title    : seq_exists
 Usage    : $bool = $counts->seq_exists($id)
 Function : Return whether the gene with the given ID exists in the
            counts object.
 Returns  : Boolean.
 Args     : Gene/promoter ID.

=cut

sub seq_exists
{
    my ($self, $id) = @_;

    return $self->{-seq_exists}->{$id};
}

=head2 cluster_exists

 Title    : cluster_exists
 Usage    : $bool = $counts->cluster_exists($id)
 Function : Return whether sites for the Cluster with the given ID exists in
            the counts object.
 Returns  : Boolean.
 Args     : Cluster ID.

=cut

sub cluster_exists
{
    my ($self, $id) = @_;

    return $self->{-cluster_exists}->{$id};
}

=head2 exists

 Title    : exists
 Usage    : $bool = $counts->exists($seq_id, $cluster_id)
 Function : Return whether the gene/Cluster pair with the given
            IDs exist in the counts object.
 Returns  : Boolean.
 Args     : A gene ID and a Cluster ID.

=cut

sub exists
{
    my ($self, $seq_id, $cluster_id) = @_;

    return $self->seq_exists($seq_id) && $self->cluster_exists($cluster_id);
}

=head2 total_cr_length

 Title    : total_cr_length
 Usage    : This method is deprecated

=cut

sub total_cr_length
{
    carp "total_cr_length() is deprecated\n";
}

=head2 seq_cluster_count

 Title    : seq_cluster_count
 Usage    : $count = $counts->seq_cluster_count($seq_id, $cluster_id);
            $counts->seq_cluster_count($seq_id, $cluster_id, $count);
 Function : Get/set the count of the number of times sites for the given
            Cluster were detected for the given gene/sequence.
 Returns  : An integer.
 Args     : A gene/sequence ID,
            A Cluster ID, 
            Optionally a new count for this gene/Cluster pair and the sum of
			the lengths covered by the cluster sites

=cut

sub seq_cluster_count
{
    my ($self, $seq_id, $cluster_id, $count) = @_;

    return if !defined $seq_id || !defined $cluster_id;

    if (defined $count) {
        $self->{_seq_cluster_counts}->{$seq_id}->{$cluster_id} = $count;

        if ($count > 0) {
            $self->{_cluster_seq_exists}->{$cluster_id}->{$seq_id} = 1;
        }

        unless ($self->seq_exists($seq_id)) {
            $self->_add_seq($seq_id);
        }

        unless ($self->cluster_exists($cluster_id)) {
            $self->_add_cluster($cluster_id);
        }
    }

    if ($self->{_seq_cluster_counts}->{$seq_id}) {
        return $self->{_seq_cluster_counts}->{$seq_id}->{$cluster_id} || 0;
    }

    return 0;
}

=head2 seq_cluster_length

 Title    : seq_cluster_length
 Usage    : $length = $counts->seq_cluster_length($seq_id, $cluster_id);
            $counts->seq_cluster_length($seq_id, $cluster_id, $length);
 Function : Get/set the length covered by the given cluster sites for the given
			gene/sequence. 
 Returns  : An integer.
 Args     : A gene/sequence ID,
            A Cluster ID, 
            Optionally a new length for this gene/Cluster and the sum of
			the lengths covered by the cluster sites

=cut

sub seq_cluster_length
{
    my ($self, $seq_id, $cluster_id, $length) = @_;

    return if !defined $seq_id || !defined $cluster_id;

	if (!$self->seq_exists($seq_id)) {
		carp "Gene $seq_id must first be defined with an appropriate count\n";
		return;
	}
	
	if (!$self->cluster_exists($cluster_id)) {
		carp "Cluster $cluster_id must first be defined\n";
		return;
	}
	
    if (defined $length) {
		$self->{_seq_cluster_lengths}->{$seq_id}->{$cluster_id} = $length;
    }

    if ($self->{_seq_cluster_lengths}->{$seq_id}) {
        return $self->{_seq_cluster_lengths}->{$seq_id}->{$cluster_id} || 0;
    }

    return 0;
}

=head2 cluster_seq_count

 Title    : cluster_seq_count
 Usage    : $count = $counts->cluster_seq_count($cluster_id)
 Function : Get the count of the number of sequences/genes for which
            sites for the given Cluster were detected.
 Returns  : An integer.
 Args     : A Cluster ID. 

=cut

sub cluster_seq_count
{
    my ($self, $cluster_id) = @_;

    return if !$cluster_id;

    my $seq_count = 0;

    if ($self->{_cluster_seq_exists}->{$cluster_id}) {
        $seq_count = scalar(keys %{$self->{_cluster_seq_exists}->{$cluster_id}}) || 0;
    }


    return $seq_count;
}

=head2 cluster_seq_ids

 Title    : cluster_seq_ids
 Usage    : $ids = $counts->cluster_seq_ids($cluster_id)
 Function : Get the list of gene/sequence IDs for which sites for 
            the given Cluster were detected.
 Returns  : A ref to a list of gene/sequence IDs.
 Args     : A Cluster ID. 

=cut

sub cluster_seq_ids
{
    my ($self, $cluster_id) = @_;

    return if !$cluster_id;

    my @seq_ids;
    if ($self->{_cluster_seq_exists}->{$cluster_id}) {
        @seq_ids = keys %{$self->{_cluster_seq_exists}->{$cluster_id}};
    }

    return @seq_ids ? \@seq_ids : undef;
}

=head2 cluster_count

 Title    : cluster_count
 Usage    : $count = $counts->cluster_count($cluster_id)
 Function : For the given Cluster, return the total number of cluster which appear
            for all the genes/sequences in the counts object.
 Returns  : An integer.
 Args     : A Cluster ID. 

=cut

sub cluster_count
{
    my ($self, $cluster_id) = @_;

    return if !$cluster_id;

    my $count = 0;
    if ($self->{_cluster_seq_exists}->{$cluster_id}) {
        my @seq_ids = keys %{$self->{_cluster_seq_exists}->{$cluster_id}};
        foreach my $seq_id (@seq_ids) {
            $count += $self->seq_cluster_count($seq_id, $cluster_id);
        }
    }

    return $count;
}

=head2 cluster_length

 Title    : cluster_length
 Usage    : $length = $counts->cluster_length($cluster_id)
 Function : For the given Cluster, return the total length of the cluster sites
			which appear on all the genes/sequences in the counts object.
 Returns  : An integer.
 Args     : A Cluster ID. 

=cut

sub cluster_length
{
    my ($self, $cluster_id) = @_;

    return if !$cluster_id;

    my $length = 0;
    if ($self->{_cluster_seq_exists}->{$cluster_id}) {
        my @seq_ids = keys %{$self->{_cluster_seq_exists}->{$cluster_id}};
        foreach my $seq_id (@seq_ids) {
            $length += $self->seq_cluster_length($seq_id, $cluster_id);
        }
    }

    return $length;
}

=head2 missing_seq_ids

 Title    : missing_seq_ids
 Usage    : $ids = $counts->missing_seq_ids()
 Function : Get a list of missing gene/sequence IDs. For convenience,
            the counts object allows storage of genes which may have
            been entered for analysis but could not be found in the
            database.
 Returns  : A ref to a list of gene/sequence IDs.
 Args     : None.

=cut

sub missing_seq_ids
{
    $_[0]->{-missing_seq_ids};
}

=head2 missing_cluster_ids

 Title    : missing_cluster_ids
 Usage    : $ids = $counts->missing_cluster_ids()
 Function : Get a list of missing Cluster IDs. For convenience, the counts
            object allows storage of Clusters which may have been entered
            for analysis but could not be found in the database.
 Returns  : A ref to a list of Cluster IDs.
 Args     : None.

=cut

sub missing_cluster_ids
{
    $_[0]->{-missing_cluster_ids};
}

=head2 subset

 Title    : subset
 Usage    : $subset = $counts->subset(
				    -seq_ids   => $seq_ids,
				    -cluster_ids     => $cluster_ids
            );

            OR

            $subset = $counts->subset(
                    -seq_start => $seq_start,
                    -seq_end   => $seq_end,
                    -cluster_start   => $tf_start,
                    -cluster_end     => $tf_end
            );

            OR some combination of above.

 Function : Get a new counts object from the current one with only a
            subset of the Clusters and/or genes. The subset of Clusters and 
            genes may be either specified with explicit ID lists or by
            starting and/or ending IDs.
 Returns  : A new OPOSSUM::Analysis::Cluster::Counts object.
 Args     : seq_ids    - optionally a list ref of gene IDs,
            cluster_ids      - optionally a list ref of Cluster IDs,
            seq_start  - optionally the starting gene ID,
            seq_end    - optionally the ending gene ID,
            cluster_start    - optionally the starting cluster ID,
            cluster_end      - optionally the ending cluster ID.

=cut

sub subset
{
    my ($self, %args) = @_;

    my $seq_start = $args{-seq_start};
    my $seq_end   = $args{-seq_end};
    my $seq_ids   = $args{-seq_ids};
    my $cl_start   = $args{-cluster_start};
    my $cl_end     = $args{-cluster_end};
    my $cluster_ids     = $args{-cluster_ids};

    my $all_seq_ids = $self->seq_ids;
    my $all_cluster_ids   = $self->cluster_ids;

    my $subset_seq_ids;
    my $subset_cluster_ids;

    my @missing_seq_ids;
    my @missing_cluster_ids;

    if (!defined $seq_ids) {
        if (!$seq_start && !$seq_end) {
            $subset_seq_ids = $all_seq_ids;
        } else {
            if (!$seq_start) {
                $seq_start = $all_seq_ids->[0];
            }
            if (!$seq_end) {
                $seq_end = $all_seq_ids->[scalar @$all_seq_ids - 1];
            }
            foreach my $seq_id (@$all_seq_ids) {
                if ($seq_id ge $seq_start && $seq_id le $seq_end) {
                    push @$subset_seq_ids, $seq_id;
                }
            }
        }
    } else {
        foreach my $seq_id (@$seq_ids) {
            if (grep(/^$seq_id$/, @$all_seq_ids)) {
                push @$subset_seq_ids, $seq_id;
            } else {
                carp "warning: gene ID $seq_id not in super set,"
                    . " omitting from subset";
                push @missing_seq_ids, $seq_id;
            }
        }
    }

    if (!defined $cluster_ids) {
        if (!$cl_start && !$cl_end) {
            $subset_cluster_ids = $all_cluster_ids;
        } else {
            if (!$cl_start) {
                $cl_start = $all_cluster_ids->[0];
            }
            if (!$cl_end) {
                $cl_end = $all_cluster_ids->[scalar @$all_cluster_ids - 1];
            }
            foreach my $cluster_id (@$all_cluster_ids) {
                if ($cluster_id ge $cl_start && $cluster_id le $cl_end) {
                    push @$subset_cluster_ids, $cluster_id;
                }
            }
        }
    } else {
        foreach my $cluster_id (@$cluster_ids) {
            if (grep(/^$cluster_id$/, @$all_cluster_ids)) {
                push @$subset_cluster_ids, $cluster_id;
            } else {
                carp "warning: Cluster ID $cluster_id not in super set,"
                    . " omitting from subset";
                push @missing_cluster_ids, $cluster_id;
            }
        }
    }

    my $subset = OPOSSUM::Analysis::Cluster::Counts->new();

    return if !$subset;

    foreach my $seq_id (@$subset_seq_ids) {
        foreach my $cluster_id (@$subset_cluster_ids) {
            $subset->seq_cluster_count(
                $seq_id,
                $cluster_id,
                $self->seq_cluster_count($seq_id, $cluster_id)
            );
			$subset->seq_cluster_length(
				$seq_id,
				$cluster_id,
				$self->seq_cluster_length($seq_id, $cluster_id)
			);
        }
    }

    $subset->{-missing_seq_ids} =
        @missing_seq_ids ? \@missing_seq_ids : undef;
    $subset->{-missing_cluster_ids} = @missing_cluster_ids ? \@missing_cluster_ids : undef;

    return $subset;
}

sub _add_seq
{
    my ($self, $seq_id) = @_;
    
    return if !defined $seq_id;

    unless ($self->{-seq_exists}->{$seq_id}) {
        push @{$self->{-seq_ids}}, $seq_id;
        $self->{-seq_exists}->{$seq_id} = 1;   
    }
}

sub _add_cluster
{
    my ($self, $cluster_id) = @_;
    
    return if !defined $cluster_id;

    unless ($self->{-cluster_exists}->{$cluster_id}) {
        push @{$self->{-cluster_ids}}, $cluster_id;
        $self->{-cluster_exists}->{$cluster_id} = 1;   
    }
}

1;
