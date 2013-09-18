
=head1 NAME

OPOSSUM::Analysis::CountsIO - Object for the I/O of OPOSSUM::Analysis::Counts
objects

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::Analysis::CountsIO;

use strict;

use Carp;
use OPOSSUM::Analysis::Counts;

=head2 new

 Title    : new
 Usage    : $countsIO = OPOSSUM::Analysis::CountsIO->new(
                -file   => $in_file,
                -format => 'fisher'
            );

 Function : Create a new OPOSSUM::Analysis::CountsIO object.
 Returns  : An OPOSSUM::Analysis::CountsIO object.
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
 Returns  : An OPOSSUM::Analysis::Counts object
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
 Args     : An OPOSSUM::Analysis::Counts object

=cut

sub write_counts
{
    my ($self, $counts) = @_;

    if (!$counts || !$counts->isa("OPOSSUM::Analysis::Counts")) {
        carp
            "no counts provided or counts is not an OPOSSUM::Analysis::Counts"
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

    my @tf_ids;
    my @seq_ids;
    my @tfbs_widths;
    my @seq_cr_lengths;
    my @seq_tfbs_counts;
    my $num_seqs  = 0;
    my $num_tfbs   = 0;
    my $seqsread = 0;
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
                    push @tf_ids,      $1;
                    push @tfbs_widths, $2;
                } else {
                    carp "error reading TFBSs";
                    return;
                }
            } elsif ($reading == 2) {
                if ($line =~ /^\s*(\S+)\s+(\d+)\s*$/) {
                    push @seq_ids,        $1;
                    push @seq_cr_lengths, $2;
                } else {
                    carp "error reading sequences";
                    return;
                }
            } elsif ($reading == 3) {
                $num_tfbs = @tf_ids ? scalar @tf_ids : 0;
                if (!$num_tfbs) {
                    carp "no TFBSs read";
                    return;
                }
                $num_seqs = @seq_ids ? scalar @seq_ids : 0;
                if (!$num_seqs) {
                    carp "no sequences read";
                    return;
                }
                my @counts = split /\t/, $line;
                if (scalar @counts != $num_tfbs) {
                    carp
                        "number of counts read does not match number of TFBSs"
                        . " for sequence number "
                        . $seqsread + 1 . " ID "
                        . $seq_ids[$seqsread];
                    return;
                }
                $seq_tfbs_counts[$seqsread] = \@counts;
                $seqsread++;
            }
        }
    }

    if ($seqsread != $num_seqs) {
        carp "number of sequence counts read does not match number of"
            . " sequences";
        return;
    }

    my $counts = OPOSSUM::Analysis::Counts->new(
        -seq_ids    => \@seq_ids,
        -tf_ids     => \@tf_ids
    );
    if (!$counts) {
        carp "error creating new OPOSSUM::Analysis::Counts object";
        return;
    }

    my $first_seq = 1;
    my $seq_idx   = 0;
    while ($seq_idx < $num_seqs) {
        my $seq_id = $seq_ids[$seq_idx];
        $counts->seq_cr_length($seq_id, $seq_cr_lengths[$seq_idx]);

        my $tfbs_idx = 0;
        while ($tfbs_idx < $num_tfbs) {
            my $tf_id = $tf_ids[$tfbs_idx];
            if ($first_seq) {
                $counts->tfbs_width($tf_id, $tfbs_widths[$tfbs_idx]);
            }
            $counts->seq_tfbs_count($seq_id, $tf_id,
                $seq_tfbs_counts[$seq_idx][$tfbs_idx]);
            $tfbs_idx++;
        }
        $seq_idx++;
        $first_seq = 0;
    }

    return $counts;
}

sub _write_fisher_counts
{
    my ($fh, $counts) = @_;

    my @tf_ids = sort @{$counts->tf_ids()};
    if (!@tf_ids) {
        carp "no TFBS IDs in counts\n";
        return 0;
    }

    my $num_seqs = $counts->num_seqs();
    if (!$num_seqs) {
        carp "number of sequences in counts is 0 or undefined\n";
        return 0;
    }

    foreach my $tf_id (@tf_ids) {
        my $count    = $counts->tfbs_seq_count($tf_id);
        my $no_count = $num_seqs - $count;
        print $fh "$tf_id\t$count\t$no_count\n";
    }

    return 1;
}

sub _write_zscore_counts
{
    my ($fh, $counts) = @_;

    my @tf_ids = sort @{$counts->tf_ids()};
    if (!@tf_ids) {
        carp "no TFBS IDs in counts\n";
        return 0;
    }
    my $seq_ids = $counts->get_all_seq_ids();
    if (!$seq_ids) {
        carp "no sequence IDs in counts\n";
        return 0;
    }

    foreach my $tf_id (@tf_ids) {
        my $count  = 0;
        my $cr_len = 0;
        foreach my $seq_id (@$seq_ids) {
            $count += $counts->seq_tfbs_count($seq_id, $tf_id);
            $cr_len += $counts->seq_cr_length($seq_id);
        }
        printf $fh "%s\t%d\t%d\t%d\n",
            $tf_id, $counts->tfbs_width($tf_id), $cr_len, $count;
    }

    return 1;
}

sub _write_detail_counts
{
    my ($fh, $counts) = @_;

    my $tf_ids  = $counts->tf_ids();
    my $seq_ids = $counts->seq_ids();
    return 0 if !$tf_ids || !$seq_ids;
    print $fh '>TFBS\n';
    foreach my $tf_id (@$tf_ids) {
        printf $fh "%-20s\t%d\n", $tf_id, $counts->tfbs_width($tf_id) || 0;
    }

    print $fh ">Genes\n";
    foreach my $seq_id (@$seq_ids) {
        printf $fh "%-20s\t%d\n",
            $seq_id, $counts->seq_cr_length($seq_id) || 0;
    }

    print $fh ">Counts\n";
    foreach my $seq_id (@$seq_ids) {
        my $first = 1;
        foreach my $tf_id (@$tf_ids) {
            if (!$first) {
                print $fh "\t";
            } else {
                $first = 0;
            }
            print $fh $counts->seq_tfbs_count($seq_id, $tf_id);
        }
        print $fh "\n";
    }

    return 1;
}

1;
