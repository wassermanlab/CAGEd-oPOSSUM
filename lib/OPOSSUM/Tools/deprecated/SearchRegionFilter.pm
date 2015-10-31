=head1 NAME

OPOSSUM::Tools::SearchRegionFilter - quick and dirty class to perform
search region filtering (intersections) using BEDTools.
package intersectBed tool

=head1 DESCRIPTION

=head1 MODIFICATIONS

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 Child & Family Research Institute
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::Tools::SearchRegionFilter;

use strict;

use Readonly;
use Carp;
use File::Temp qw{tempfile};
use OPOSSUM::SearchRegion;

Readonly::Scalar my $EXECUTABLE => "intersectBed";

=head2 new

 Title   : new
 Usage   : $intersector = OPOSSUM::Tools::SearchRegionFilter->new();

 Function: Construct a new OPOSSUM::Tools::SearchRegionFilter object
 Returns : A new OPOSSUM::Tools::SearchRegionFilter object

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {%args}, ref $class || $class;

    return $self;
}

=head2 filter_search_regions

 Title   : filter_search_regions
 Usage   : my $result_regions = $intersector->filter_search_regions(
                -search_regions         => $search_regions,
                -filter_regions         => $filter_regions
           );

 Function: Run the BedTools intersectBED on the input search regions and
           filter regions which returns the intersection of the two sets
           of regions. If the input search regions have the -parent_id
           attribute set, this is stored in the name field of the temporary
           BED file which is created and read back from the output
           (intersectBED preserves the name field of the first BED file).
 Returns : An array ref of OPOSSUM::SearchRegion objects.
 Args    : -search_regions
                An array ref of OPOSSUM::SearchRegion objects,
           -filter_regions
                An array ref of OPOSSUM::SearchRegion objects

=cut

sub filter_search_regions
{
    my ($self, %args) = @_;

    my $sr = $args{-search_regions};
    unless ($sr) {
        carp "No search regions passed\n";
    }

    my $fr = $args{-filter_regions};
    unless ($fr) {
        carp "No filtering regions passed\n";
    }

    my $sr_file = $self->_write_search_regions_to_file($sr);
    unless ($sr_file) {
        carp "Error creating temporary search regions file $sr_file\n";
        $self->_cleanup();
        return;
    }
    $self->{-search_regions_file} = $sr_file;

    my $fr_file = $self->_write_search_regions_to_file($fr);
    unless ($fr_file) {
        carp "Error creating temporary filter regions file $fr_file\n";
        $self->_cleanup();
        return;
    }
    $self->{-filter_regions_file} = $fr_file;

    my $cmd = "$EXECUTABLE -a $sr_file -b $fr_file";

    my $out = `exec 2>&1; $cmd`;

    my @search_regions;

    my @lines = split "\n", $out;
    foreach my $line (@lines) {
        chomp $line;

        if ($line =~ /^(\w+)\s+(\d+)\s+(\d+)\s+(\w+)/) {
            my $chrom     = $1;
            my $start     = $2;
            my $end       = $3;
            my $parent_id = $4;

            $chrom =~ s/^chr//;

            #
            # For search regions derived from TSSs stored in the database,
            # we set the parent ID to the ID of the pre-computed search region
            # that contains this search region and use the name field of the
            # BED file (column 4) to store this parent ID.
            #
            push @search_regions, OPOSSUM::SearchRegion->new(
                -chrom      => $chrom,
                -start      => $start,
                -end        => $end,
                -parent_id  => $parent_id
            );
        } elsif ($line =~ /^(\w+)\s+(\d+)\s+(\d+)/) {
            my $chrom = $1;
            my $start = $2;
            my $end   = $3;

            $chrom =~ s/^chr//;

            #
            # For custom CAGE search regions we do not have a parent
            # (pre-computed) search region and thus no parent ID stored in
            # the name field of the BED file.
            #
            push @search_regions, OPOSSUM::SearchRegion->new(
                -chrom      => $chrom,
                -start      => $start,
                -end        => $end
            );
        } else {
            carp "$EXECUTABLE returned $line\n";
            $self->_cleanup();
            return;
        }
    }

    $self->_cleanup();

    return @search_regions ? \@search_regions : undef;
}

sub _write_search_regions_to_file
{
    my ($self, $search_regions) = @_;

    return unless $search_regions;

    my ($fh, $filename) = tempfile('sr_XXXXXX', SUFFIX => '.bed', TMPDIR => 1);
    unless ($fh) {
        carp "Could not create temporary search regions file\n";
        return;
    }

    foreach my $sr (@$search_regions) {
        my $chrom = $sr->chrom;
        unless ($chrom =~ /^chr/) {
            $chrom = "chr$chrom";
        }

        printf $fh "%s\t%d\t%d",
            $chrom,
            $sr->start,
            $sr->end;

        #
        # Note using the BED file name field (column 4) to store the parent ID
        #
        if (defined $sr->parent_id) {
            printf $fh "\t%d", $sr->parent_id;
        }

        printf $fh "\n";
    }

    close($fh);

    return $filename;
}

sub _cleanup
{
    my ($self) = @_;

    if ($self->{-search_regions_file}) {
        unlink $self->{-search_regions_file};
    }

    if ($self->{-filter_regions_file}) {
        unlink $self->{-filter_regions_file};
    }

    return;
}
