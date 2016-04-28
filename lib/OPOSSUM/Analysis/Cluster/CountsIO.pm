
=head1 NAME

OPOSSUM::Analysis::Cluster::CountsIO - Object for the I/O of
OPOSSUM::Analysis::Cluster::Counts objects

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::Analysis::Cluster::CountsIO;

use strict;

use Carp;
use OPOSSUM::Analysis::Cluster::Counts;

=head2 new

 Title    : new
 Usage    : $countsIO = OPOSSUM::Analysis::Cluster::CountsIO->new(
                -file   => $in_file,
                -format => 'fisher'
            );

 Function : Create a new OPOSSUM::Analysis::Cluster::CountsIO object.
 Returns  : An OPOSSUM::Analysis::Cluster::CountsIO object.
 Args     : file    - name of a file for input/output
            fh      - a filehandle for input/output
            format  - format of the file: either 'fisher', 'zscore'
                      or 'detail'

=cut

sub new
{
    my ($class, %args) = @_;

    my $file   = $args{-file};
    my $fh     = $args{-fh};
    my $format = $args{-format};

    if (!$file && !$fh) {
        carp "must provide either a file name or a file handle";
        return;
    }

    if ($file && $fh) {
        carp "must provide either a file name or a file handle, not both";
        return;
    }

    if (!$format) {
        carp "must provide a file format";
        return;
    }

    if ($file) {
        open($fh, $file);
        if (!$fh) {
            carp "error opening $file - $!";
            return;
        }
    }

    my $self = bless {
        -file   => $file,
        -fh     => $fh,
        -format => $format
    }, ref $class || $class;

    return $self;
}

sub DESTROY
{
    my $self = shift;

   #
   # Only close if it was opened in this module (i.e. a file name was provided
   # rather than a file handle
   #
    if ($self->file) {
        $self->close;
    }
}

=head2 fh

 Title    : fh
 Usage    : $fh = $countsIO->fh() or $countsIO->fh(\*FH);
 Function : Get/set the filehandle
 Returns  : A filehandle
 Args     : Optional filehandle

=cut

sub fh
{
    my ($self, $fh) = @_;

    if ($fh) {
        $self->{-fh} = $fh;
    }
    return $self->{-fh};
}

=head2 file

 Title    : file
 Usage    : $file = $countsIO->file() or $countsIO->file($file);
 Function : Get/set the file name
 Returns  : A file name
 Args     : Optional file name

=cut

sub file
{
    my ($self, $file) = @_;

    if ($file) {
        $self->{-file} = $file;
    }
    return $self->{-file};
}

=head2 format

 Title    : format
 Usage    : $format = $countsIO->format() or $countsIO->format($format);
 Function : Get/set the file format: either 'fisher', 'zscore' or 'detail'
 Returns  : A file format
 Args     : Optional file format

=cut

sub format
{
    my ($self, $format) = @_;

    if ($format) {
        $self->{-format} = $format;
    }
    return $self->{-format};
}

=head2 close

 Title    : close
 Usage    : $countsIO->close();
 Function : Close the filehandle if it is open.
 Returns  : Nothing
 Args     : None

=cut

sub close
{
    my $self = shift;

    if ($self->fh) {
        close($self->fh);
        $self->{-fh} = undef;
    }
}

=head2 read_counts

 Title    : read_counts
 Usage    : $counts = $countsIO->read_counts();
 Function : Read counts from the open filehandle. NOTE only files of
            format 'detail' are readable.
 Returns  : An OPOSSUM::Analysis::Cluster::Counts object
 Args     : None

=cut

sub read_counts
{
    my ($self) = @_;

    my $fh = $self->fh;
    if (!$fh) {
        carp "file handle is no longer valid";
        return;
    }

    if ($self->file =~ /^>{1,2}/) {
        carp "file is not open for reading";
        return;
    }

    my $format = $self->format;
    if (!$format) {
        carp "no file format provided";
        return;
    }

    $format = lc $format;

    if ($format eq 'fisher') {
        carp "Fisher is a write-only format\n";
        return;
    } elsif ($format eq 'zscore') {
        carp "Zscore is a write-only format\n";
        return;
    } elsif ($format eq 'detail') {
        return _read_detail_counts($fh);
    } else {
        carp "unknown format $format";
    }
}

=head2 write_counts

 Title    : write_counts
 Usage    : $countsIO->write_counts($counts);
 Function : Write counts to the open filehandle
 Returns  : Nothing
 Args     : An OPOSSUM::Analysis::Cluster::Counts object

=cut

sub write_counts
{
    my ($self, $counts) = @_;

    if (!$counts || !$counts->isa("OPOSSUM::Analysis::Cluster::Counts")) {
        carp
            "no counts provided or counts is not an OPOSSUM::Analysis::Cluster::Counts"
            . " object";
        return;
    }

    my $fh = $self->fh;
    if (!$fh) {
        carp "file handle is no longer valid";
        return;
    }

    if ($self->file !~ /^>{1,2}/) {
        carp "file is not open for writing";
        return;
    }

    my $format = $self->format;
    if (!$format) {
        carp "no file format provided";
        return;
    }

    $format = lc $format;

    if ($format eq 'fisher') {
        return _write_fisher_counts($fh, $counts);
    } elsif ($format eq 'zscore') {
        return _write_zscore_counts($fh, $counts);
    } elsif ($format eq 'detail') {
        return _write_detail_counts($fh, $counts);
    } else {
        carp "unknown format $format";
    }
}

sub _read_detail_counts
{
    my ($fh) = @_;

    my @cluster_ids;
    my @seq_ids;
    my @cluster_widths;
    my @seq_cr_lengths;
    my @seq_cluster_counts;
    my $num_seqs  = 0;
    my $num_cluster   = 0;
    my $genes_read = 0;
    my $reading    = 0;
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /^>TFBS/) {
            $reading = 1;
        } elsif ($line =~ /^>Genes/) {
            $reading = 2;
        } elsif ($line =~ /^>Counts/) {
            $reading = 3;
        } else {
            if ($reading == 1) {
                if ($line =~ /^\s*(\S+)\s+(\d+)\s*$/) {
                    push @cluster_ids,      $1;
                    push @cluster_widths, $2;
                } else {
                    carp "error reading TFBSs";
                    return;
                }
            } elsif ($reading == 2) {
                if ($line =~ /^\s*(\S+)\s+(\d+)\s*$/) {
                    push @seq_ids,        $1;
                    push @seq_cr_lengths, $2;
                } else {
                    carp "error reading genes";
                    return;
                }
            } elsif ($reading == 3) {
                $num_cluster = @cluster_ids ? scalar @cluster_ids : 0;
                if (!$num_cluster) {
                    carp "no TFBSs read";
                    return;
                }
                $num_seqs = @seq_ids ? scalar @seq_ids : 0;
                if (!$num_seqs) {
                    carp "no genes read";
                    return;
                }
                my @counts = split /\t/, $line;
                if (scalar @counts != $num_cluster) {
                    carp
                        "number of counts read does not match number of TFBSs"
                        . " for gene number "
                        . $genes_read + 1 . " ID "
                        . $seq_ids[$genes_read];
                    return;
                }
                $seq_cluster_counts[$genes_read] = \@counts;
                $genes_read++;
            }
        }
    }

    if ($genes_read != $num_seqs) {
        carp "number of genes counts read does not match number of genes";
        return;
    }

    my $counts = OPOSSUM::Analysis::Cluster::Counts->new(
        -seq_ids => \@seq_ids,
        -cluster_ids   => \@cluster_ids
    );
    if (!$counts) {
        carp "error creating new OPOSSUM::Analysis::Cluster::Counts object";
        return;
    }

    my $first_seq = 1;
    my $seq_idx   = 0;
    while ($seq_idx < $num_seqs) {
        my $seq_id = $seq_ids[$seq_idx];
        $counts->seq_cr_length($seq_id, $seq_cr_lengths[$seq_idx]);

        my $cluster_idx = 0;
        while ($cluster_idx < $num_cluster) {
            my $cluster_id = $cluster_ids[$cluster_idx];
            if ($first_seq) {
                $counts->cluster_width($cluster_id, $cluster_widths[$cluster_idx]);
            }
            $counts->seq_cluster_count($seq_id, $cluster_id,
                $seq_cluster_counts[$seq_idx][$cluster_idx]);
            $cluster_idx++;
        }
        $seq_idx++;
        $first_seq = 0;
    }

    return $counts;
}

sub _write_fisher_counts
{
    my ($fh, $counts) = @_;

    my $cluster_ids = $counts->get_all_cluster_ids();
    if (!$cluster_ids) {
        carp "no TFBS IDs in counts\n";
        return 0;
    }
    my $num_seqs = $counts->num_seqs;
    if (!$num_seqs) {
        carp "number of genes in counts is 0 or undefined\n";
        return 0;
    }

    foreach my $cluster_id (@$cluster_ids) {
        my $count    = $counts->cluster_seq_count($cluster_id);
        my $no_count = $num_seqs - $count;
        print $fh "$cluster_id\t$count\t$no_count\n";
    }

    return 1;
}

sub _write_zscore_counts
{
    my ($fh, $counts) = @_;

    my $cluster_ids = $counts->get_all_cluster_ids();
    if (!$cluster_ids) {
        carp "no TFBS IDs in counts\n";
        return 0;
    }
    my $seq_ids = $counts->get_all_seq_ids();
    if (!$seq_ids) {
        carp "no gene IDs in counts\n";
        return 0;
    }

    foreach my $cluster_id (@$cluster_ids) {
        my $count  = 0;
        my $cr_len = 0;
        foreach my $seq_id (@$seq_ids) {
            $count += $counts->seq_cluster_count($seq_id, $cluster_id);
            $cr_len += $counts->seq_cr_length($seq_id);
        }
        printf $fh "%s\t%d\t%d\t%d\n",
            $cluster_id, $counts->cluster_width($cluster_id), $cr_len, $count;
    }

    return 1;
}

sub _write_detail_counts
{
    my ($fh, $counts) = @_;

    my $cluster_ids   = $counts->get_all_cluster_ids();
    my $seq_ids = $counts->get_all_seq_ids();
    return 0 if !$cluster_ids || !$seq_ids;
    print $fh '>TFBS\n';
    foreach my $cluster_id (@$cluster_ids) {
        printf $fh "%-20s\t%d\n", $cluster_id, $counts->cluster_width($cluster_id) || 0;
    }

    print $fh ">Genes\n";
    foreach my $seq_id (@$seq_ids) {
        printf $fh "%-20s\t%d\n",
            $seq_id, $counts->seq_cr_length($seq_id) || 0;
    }

    print $fh ">Counts\n";
    foreach my $seq_id (@$seq_ids) {
        my $first = 1;
        foreach my $cluster_id (@$cluster_ids) {
            if (!$first) {
                print $fh "\t";
            } else {
                $first = 0;
            }
            print $fh $counts->seq_cluster_count($seq_id, $cluster_id);
        }
        print $fh "\n";
    }

    return 1;
}

1;
