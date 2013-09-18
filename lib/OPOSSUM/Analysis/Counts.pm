=head1 NAME

OPOSSUM::Analysis::Counts - Object to store the count of TFBSs for each
sequence (gene/promoter/region) / TF combination.

=head1 SYNOPSIS

 my $aca = $db_adaptor->get_AnalysisCountsAdaptor();

 my $counts = $aca->fetch_counts(
     -conservation_level     => 2,
     -threshold_level        => 3,
     -search_region_level    => 1
 );

=head1 DESCRIPTION

This object stores a count of the number of times a binding site for each TF
profile was found on each sequence (gene/promoter/region). These counts can be
retrieved from the database by the OPOSSUM::DBSQL::Analysis::CountsAdaptor.
This object can be passed to the OPOSSUM::Analysis::Fisher and
OPOSSUM::Analysis::Zscore modules.

=head1 MODIFICATIONS

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

 Modified by Shannan Ho Sui on Dec 21, 2006 to accommodate schema changes

=head1 METHODS

=cut

package OPOSSUM::Analysis::Counts;

use strict;

use Carp;

=head2 new

 Title    : new
 Usage    : $counts = OPOSSUM::Analysis::Counts->new();
 Function : Create a new OPOSSUM::Analysis::Counts object.
 Returns  : An OPOSSUM::Analysis::Counts object.

=cut

sub new
{
    my ($class, %args) = @_;

    my $seq_ids  = $args{-seq_ids};
    my $tf_ids   = $args{-tf_ids};
    my $counts   = $args{-counts};

    if ($args{-tf_info_set}) {
        carp "Support for TFInfoSet is deprecated.\n";
    }

    my $self = bless {
        -seq_ids           => undef,
        -tf_ids            => undef,
        -seq_exists        => undef,
        -tf_exists         => undef,
        _seq_tfbs_counts   => {},
        _tfbs_seq_exists   => {},
        _params            => {}
    }, ref $class || $class;

    if ($seq_ids && $tf_ids) {
        #
        # If sequence ID and TF ID list provided, initialize counts with 0's
        #
        foreach my $seq_id (@$seq_ids) {
            foreach my $tf_id (@$tf_ids) {
                $self->seq_tfbs_count($seq_id, $tf_id, 0);
            }
        }
    }

    if ($counts) {
        if (ref $counts eq 'HASH') {
            #
            # $counts should be a hash ref of hash refs of counts, e.g.:
            # $count->{seq_id}->{tf_id} = $count;
            # and count
            #
            $self->_set_all_seq_tfbs_counts_hash($counts);
        } elsif (ref $counts eq 'ARRAY') {
            #
            # $counts should be an array ref of array containing counts
            #
            $self->_set_all_seq_tfbs_counts_array($counts);
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
 Function : Get the list of sequence IDs stored in the counts object.
 Returns  : A reference to a list of sequence IDs.
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
 Function : Get the list of sequence IDs. This is a synonym for the
            get variant of the seq_ids method.
 Returns  : A reference to a list of sequence IDs.
 Args     : None.

=cut

sub get_all_seq_ids
{
    my $self = shift;

    return $self->seq_ids();
}

=head2 tf_ids

 Title    : tf_ids
 Usage    : $tfids = $counts->tf_ids()
 Function : Get the list of TF IDs stored in the counts object.
 Returns  : A reference to a list of TF IDs.
 Args     : None.

=cut

sub tf_ids
{
    my $self = shift;

    return $self->{-tf_ids}
}

=head2 get_all_tf_ids

 Title    : get_all_tf_ids
 Usage    : $tfids = $counts->get_all_tf_ids()
 Function : Get the list of TF IDs. This is a synonym for the get
            variant of the tf_ids method.
 Returns  : A reference to a list of TF IDs.
 Args     : Optionally a reference to a list of TF IDs.

=cut

sub get_all_tf_ids
{
    my $self = shift;

    return $self->tf_ids();
}

=head2 tf_info_set

 Title    : tf_info_set
 Usage    : This method is deprecated.

=cut

sub tf_info_set
{
    carp "tf_info_set() is deprecated\n";
}

=head2 get_tf_info

 Title    : get_tf_info
 Usage    : This method is deprecated.

=cut

sub get_tf_info
{
    carp "get_tf_info() is deprecated\n";
}

=head2 num_sequences

 Title    : num_sequences
 Usage    : $num = $counts->num_sequences()
 Function : Get the number of sequences/genes/promoters/regions in the
            counts object
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

=head2 num_tfs

 Title    : num_tfs
 Usage    : $num = $counts->num_tfs()
 Function : Get the number of TFs in the counts object
 Returns  : An integer.
 Args     : None.

=cut

sub num_tfs
{
    my $self = shift;

    my $num_tfs = 0;
    if ($self->tf_ids()) {
        $num_tfs = scalar @{$self->tf_ids()};
    }

    return $num_tfs;
}

=head2 seq_exists

 Title    : seq_exists
 Usage    : $bool = $counts->seq_exists($id)
 Function : Return whether the sequence with the given ID exists in the
            counts object.
 Returns  : Boolean.
 Args     : Gene/promoter ID.

=cut

sub seq_exists
{
    my ($self, $id) = @_;

    return $self->{-seq_exists}->{$id};
}

=head2 tf_exists

 Title    : tf_exists
 Usage    : $bool = $counts->tf_exists($id)
 Function : Return whether sites for the TF with the given ID exists in
            the counts object.
 Returns  : Boolean.
 Args     : TF ID.

=cut

sub tf_exists
{
    my ($self, $id) = @_;

    return $self->{-tf_exists}->{$id};
}

=head2 exists

 Title    : exists
 Usage    : $bool = $counts->exists($seq_id, $tf_id)
 Function : Return whether the sequence/TF pair with the given
            IDs exist in the counts object.
 Returns  : Boolean.
 Args     : A sequence ID and a TF ID.

=cut

sub exists
{
    my ($self, $seq_id, $tf_id) = @_;

    return $self->seq_exists($seq_id) && $self->tf_exists($tf_id);
}

=head2 tfbs_width

 Title    : tfbs_width
 Usage    : This method is deprecated

=cut

sub tfbs_width
{
    carp "tfbs_width() is deprecated\n";
}

=head2 seq_tfbs_count

 Title    : seq_tfbs_count
 Usage    : $count = $counts->seq_tfbs_count($seq_id, $tf_id);
            $counts->seq_tfbs_count($seq_id, $tf_id, $count);
 Function : Get/set the count of the number of times sites for the given
            TF were detected for the given sequence/sequence.
 Returns  : An integer.
 Args     : A sequence ID,
            A TF ID, 
            Optionally a new count for this sequence/TF pair

=cut

sub seq_tfbs_count
{
    my ($self, $seq_id, $tf_id, $count) = @_;

    return if !defined $seq_id || !defined $tf_id;

    if (defined $count) {
        $self->_add_sequence($seq_id);
        $self->_add_tf($tf_id);

        $self->{_seq_tfbs_counts}->{$seq_id}->{$tf_id} = $count;

        if ($count > 0) {
            $self->{_tfbs_seq_exists}->{$tf_id}->{$seq_id} = 1;
        }
    }

    if ($self->{_seq_tfbs_counts}->{$seq_id}) {
        return $self->{_seq_tfbs_counts}->{$seq_id}->{$tf_id} || 0;
    }

    return 0;
}

=head2 tfbs_seq_count

 Title    : tfbs_seq_count
 Usage    : $count = $counts->tfbs_seq_count($tf_id)
 Function : Get the count of the number of sequences/genes for which
            sites for the given TF were detected.
 Returns  : An integer.
 Args     : A TF ID. 

=cut

sub tfbs_seq_count
{
    my ($self, $tf_id) = @_;

    return if !$tf_id;

    my $seq_count = 0;

    if ($self->{_tfbs_seq_exists}->{$tf_id}) {
        $seq_count = scalar(keys %{$self->{_tfbs_seq_exists}->{$tf_id}}) || 0;
    }


    return $seq_count;
}

=head2 _set_all_seq_tfbs_counts_array

 Title    : _set_all_seq_tfbs_counts_array
 Usage    : $count = $counts->_set_all_seq_tfbs_counts_array($data);
 Function : Set the count of the number of times sites for the given
            TF were detected for the given gene/sequence.
 Returns  : Nothing.
 Args     : An arrayref of arrayrefs of sequence ID, TF ID, count, e.g.
            as returned by DBI->fetchall_arrayref.

=cut

sub _set_all_seq_tfbs_counts
{
    my ($self, $counts) = @_;

    return if !defined $counts;

    foreach my $row (@$counts) {
        my $seq_id = $row->[0];
        my $tf_id   = $row->[1];
        my $count   = $row->[2];

        $self->_add_sequence($seq_id);
        $self->_add_tf($tf_id);

        $self->{_seq_tfbs_counts}->{$seq_id}->{$tf_id} = $count;

        if ($count > 0) {
            $self->{_tfbs_seq_exists}->{$tf_id}->{$seq_id} = 1;
        }
    }
}

=head2 _set_all_seq_tfbs_counts_hash

 Title    : _set_all_seq_tfbs_counts_hash
 Usage    : $count = $counts->_set_all_seq_tfbs_counts_hash($data);
 Function : Set the count of the number of times sites for the given
            TF were detected for the given gene/sequence.
 Returns  : Nothing.
 Args     : An hashref of hashrefs of sequence ID, TF ID and count, e.g.:
            $data->{seq_id}->{tf_id} = $count

=cut

sub _set_all_seq_tfbs_counts_hash
{
    my ($self, $counts) = @_;

    return if !defined $counts;

    foreach my $seq_id (keys %$counts) {
        $self->_add_sequence($seq_id);

        my $seq_counts = $counts->{$seq_id};

        foreach my $tf_id (keys %$seq_counts) {
            $self->_add_tf($tf_id);
            
            my $count = $seq_counts->{$tf_id};

            $self->{_seq_tfbs_counts}->{$seq_id}->{$tf_id} = $count;

            if ($count > 0) {
                $self->{_tfbs_seq_exists}->{$tf_id}->{$seq_id} = 1;
            }
        }
    }
}

=head2 tf_seq_ids

 Title    : tf_seq_ids
 Usage    : $ids = $counts->tf_seq_ids($tf_id)
 Function : Get the list of gene/sequence IDs for which sites for 
            the given TF were detected.
 Returns  : A ref to a list of gene/sequence IDs.
 Args     : A TF ID. 

=cut

sub tf_seq_ids
{
    my ($self, $tf_id) = @_;

    return if !$tf_id;

    my @seq_ids;
    if ($self->{_tfbs_seq_exists}->{$tf_id}) {
        @seq_ids = keys %{$self->{_tfbs_seq_exists}->{$tf_id}};
    }

    return @seq_ids ? \@seq_ids : undef;
}

=head2 tfbs_count

 Title    : tfbs_count
 Usage    : $count = $counts->tfbs_count($tf_id)
 Function : For the given TF, return the total number of TFBS which appear
            for all the genes/sequences in the counts object.
 Returns  : An integer.
 Args     : A TF ID. 

=cut

sub tfbs_count
{
    my ($self, $tf_id) = @_;

    return if !$tf_id;

    my $count = 0;
    if ($self->{_tfbs_seq_exists}->{$tf_id}) {
        my @seq_ids = keys %{$self->{_tfbs_seq_exists}->{$tf_id}};
        foreach my $seq_id (@seq_ids) {
            $count += $self->seq_tfbs_count($seq_id, $tf_id);
        }
    }

    return $count;
}

=head2 missing_seq_ids

 Title    : missing_seq_ids
 Usage    : $ids = $counts->missing_seq_ids()
 Function : Get a list of missing gene/sequence IDs. For convenience,
            the counts object allows storage of sequences which may have
            been entered for analysis but could not be found in the
            database.
 Returns  : A ref to a list of gene/sequence IDs.
 Args     : None.

=cut

sub missing_seq_ids
{
    $_[0]->{-missing_seq_ids};
}

=head2 missing_tf_ids

 Title    : missing_tf_ids
 Usage    : $ids = $counts->missing_tf_ids()
 Function : Get a list of missing TF IDs. For convenience, the counts
            object allows storage of TFs which may have been entered
            for analysis but could not be found in the database.
 Returns  : A ref to a list of TF IDs.
 Args     : None.

=cut

sub missing_tf_ids
{
    $_[0]->{-missing_tf_ids};
}

=head2 subset

 Title    : subset
 Usage    : $subset = $counts->subset(
				    -seq_ids   => $seq_ids,
				    -tf_ids     => $tf_ids
            );

            OR

            $subset = $counts->subset(
                    -seq_start => $seq_start,
                    -seq_end   => $seq_end,
                    -tf_start   => $tf_start,
                    -tf_end     => $tf_end
            );

            OR some combination of above.

 Function : Get a new counts object from the current one with only a
            subset of the TFs and/or sequences. The subset of TFs and 
            sequences may be either specified with explicit ID lists or
            by starting and/or ending IDs.
 Returns  : A new OPOSSUM::Analysis::Counts object.
 Args     : seq_ids    - optionally a list ref of sequence IDs,
            tf_ids     - optionally a list ref of TF IDs,
            seq_start  - optionally the starting sequence ID,
            seq_end    - optionally the ending sequence ID,
            tf_start   - optionally the starting TFBS ID,
            tf_end     - optionally the ending TFBS ID.

=cut

sub subset
{
    my ($self, %args) = @_;

    my $seq_start = $args{-seq_start};
    my $seq_end   = $args{-seq_end};
    my $seq_ids   = $args{-seq_ids};
    my $tf_start  = $args{-tf_start};
    my $tf_end    = $args{-tf_end};
    my $tf_ids    = $args{-tf_ids};

    my $all_seq_ids = $self->seq_ids;
    my $all_tf_ids   = $self->tf_ids;

    my $subset_seq_ids;
    my $subset_tf_ids;

    my @missing_seq_ids;
    my @missing_tf_ids;

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
                carp "warning: sequence ID $seq_id not in super set,"
                    . " omitting from subset";
                push @missing_seq_ids, $seq_id;
            }
        }
    }

    if (!defined $tf_ids) {
        if (!$tf_start && !$tf_end) {
            $subset_tf_ids = $all_tf_ids;
        } else {
            if (!$tf_start) {
                $tf_start = $all_tf_ids->[0];
            }
            if (!$tf_end) {
                $tf_end = $all_tf_ids->[scalar @$all_tf_ids - 1];
            }
            foreach my $tf_id (@$all_tf_ids) {
                if ($tf_id ge $tf_start && $tf_id le $tf_end) {
                    push @$subset_tf_ids, $tf_id;
                }
            }
        }
    } else {
        foreach my $tf_id (@$tf_ids) {
            if (grep(/^$tf_id$/, @$all_tf_ids)) {
                push @$subset_tf_ids, $tf_id;
            } else {
                carp "warning: TF ID $tf_id not in super set,"
                    . " omitting from subset";
                push @missing_tf_ids, $tf_id;
            }
        }
    }

    my $subset = OPOSSUM::Analysis::Counts->new();

    return if !$subset;

    foreach my $seq_id (@$subset_seq_ids) {
        foreach my $tf_id (@$subset_tf_ids) {
            $subset->seq_tfbs_count(
                $seq_id,
                $tf_id,
                $self->seq_tfbs_count($seq_id, $tf_id)
            );
        }
    }

    $subset->{-missing_seq_ids} =
        @missing_seq_ids ? \@missing_seq_ids : undef;
    $subset->{-missing_tf_ids} = @missing_tf_ids ? \@missing_tf_ids : undef;

    return $subset;
}

sub _add_sequence
{
    my ($self, $seq_id) = @_;
    
    return if !defined $seq_id;

    unless ($self->{-seq_exists}->{$seq_id}) {
        push @{$self->{-seq_ids}}, $seq_id;
        $self->{-seq_exists}->{$seq_id} = 1;   
    }
}

sub _add_tf
{
    my ($self, $tf_id) = @_;
    
    return if !defined $tf_id;

    unless ($self->{-tf_exists}->{$tf_id}) {
        push @{$self->{-tf_ids}}, $tf_id;
        $self->{-tf_exists}->{$tf_id} = 1;   
    }
}

1;
