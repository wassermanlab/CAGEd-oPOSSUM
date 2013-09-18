=head1 NAME

OPOSSUM::SearchRegion - SearchRegion object

=head1 DESCRIPTION

A SearchRegion is a computed object within the FANTOM5 oPOSSUM system.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 Child & Family Research Institute
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::SearchRegion;

use strict;

use Carp;
use OPOSSUM::DBObject;

use vars qw(@ISA);

@ISA = qw(OPOSSUM::DBObject);


=head2 new

 Title   : new
 Usage   : $search_region = OPOSSUM::SearchRegion->new(
               -id      => 1,
               -chrom   => 1,
               -start   => 63025275,
               -end     => 63025474
           );

 Function: Construct a new SearchRegion object
 Returns : a new OPOSSUM::SearchRegion object

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {
        %args
    }, ref $class || $class;

    return $self;
}

=head2 id

 Title   : id
 Usage   : $id = $search_region->id() or $search_region->id($id);

 Function: Get/set the ID of this search region
 Returns : An integer
 Args    : None or a new search region ID

=cut

sub id
{
    my ($self, $id) = @_;

    if ($id) {
        $self->{-id} = $id;
    }

    return $self->{-id};
}

=head2 parent_id

 Title   : parent_id
 Usage   : $parent_id = $search_region->parent_id()
           or $search_region->parent_id($id);

 Function: Get/set the parent ID of this search region
 Returns : An integer
 Args    : None or a new search region parent ID

=cut

sub parent_id
{
    my ($self, $id) = @_;

    if ($id) {
        $self->{-parent_id} = $id;
    }

    return $self->{-parent_id};
}

=head2 chrom

 Title   : chrom
 Usage   : $chrom = $search_region->chrom() or $search_region->chrom($chrom);

 Function: Get/set the chromosome name of this search region
 Returns : An string
 Args    : None or a new search region chromosome name

=cut

sub chrom
{
    my ($self, $chrom) = @_;

    if ($chrom) {
        $self->{-chrom} = $chrom;
    }

    return $self->{-chrom};
}

=head2 start

 Title   : start
 Usage   : $start = $search_region->start() or $search_region->start($start);

 Function: Get/set the chromosomal start position of this search region
 Returns : An integer
 Args    : None or a new search region start position 

=cut

sub start
{
    my ($self, $start) = @_;

    if ($start) {
        $self->{-start} = $start;
    }

    return $self->{-start};
}

=head2 end

 Title   : end
 Usage   : $end = $search_region->end() or $search_region->end($end);

 Function: Get/set the chromosomal end position of this search region
 Returns : An integer
 Args    : None or a new search region end position 

=cut

sub end
{
    my ($self, $end) = @_;

    if ($end) {
        $self->{-end} = $end;
    }

    return $self->{-end};
}

=head2 seq

 Title   : seq
 Usage   : $seq = $search_region->seq() or $search_region->seq($seq);

 Function: Get/set the sequence associated with this search region
 Returns : An Bio::Seq object
 Args    : None or a new search region Bio::Seq sequence 

=cut

sub seq
{
    my ($self, $seq) = @_;

    if ($seq) {
        $self->{-seq} = $seq;
    }

    return $self->{-seq};
}


=head2 length

 Title   : length
 Usage   : $length = $search_region->length()

 Function: Get the length of this search region
 Returns : An integer
 Args    : None

=cut

sub length
{
    my $self = shift;

    return $self->{-end} - $self->{-start} + 1;
}

=head2 tss

 Title   : tss
 Usage   : $tss = $search_region->tss() or $search_region->tss($tss);

 Function: Get/set the TSS objects this search region is associated with.
 Returns : A list ref of OPOSSUM::TSS objects.
 Args    : None or a single OPOSSUM::TSS object or a list ref of
           OPOSSUM::TSS objects.

=cut

sub tss
{
    my ($self, $tss) = @_;

    if ($tss) {
        if (ref $tss eq 'ARRAY') {
            $self->{-tss} = $tss;
        } else {
            $self->{-tss} = [$tss];
        }
    }

    return $self->{-tss};
}

=head2 add_tss

 Title   : add_tss
 Usage   : $search_region->add_tss($tss);

 Function: Add a new TSS object or list of TSS objects to the list of TSSs
           that this search region is associated with.
 Returns : A list ref of OPOSSUM::TSS objects.
 Args    : An single OPOSSUM::TSS or list ref of OPOSSUM::TSS objects.

=cut

sub add_tss
{
    my ($self, $tss) = @_;

    if ($tss) {
        if (ref $tss eq 'ARRAY') {
            push @{$self->{-tss}}, @$tss;
        } else {
            push @{$self->{-tss}}, $tss;
        }
    }

    return $self->{-tss};
}

=head2 fetch_tss

 Title   : fetch_tss
 Usage   : $tss = $search_region->fetch_tss()

 Function: Get the TSS objects associated with this search region.
 Returns : A list ref of OPOSSUM::TSS objects
 Args    : None

=cut

sub fetch_tss
{
    my $self = shift;

    if (!$self->adaptor()) {
        carp "No adaptor defined trying to fetch tss for this search region";
        return;
    }

    my $tssa = $self->adaptor()->db()->fetch_TSSAdaptor();
    if (!$tssa) {
        carp "Could not get TSSAdaptor";
        return;
    }

    my $tss = $tssa->fetch_by_region($self->chrom, $self->start, $self->end);

    $self->{-tss} = $tss;
}

=head2 tfbss

 Title   : tfbss
 Usage   : $tfbss = $search_region->tfbss()
           or $search_region->tfbss($tfbss);

 Function: Get/set the list of OPOSSUM::TFBS objects which are associated
           with this search region.
 Returns : A list ref of OPOSSUM::TFBS objects.
 Args    : None or a list ref of OPOSSUM::TFBS objects.

=cut

sub tfbss
{
    my ($self, $tfbss) = @_;

    if ($tfbss) {
        if (ref $tfbss eq 'ARRAY') {
            $self->{-tfbss} = $tfbss;
        } else {
            $self->{-tfbss} = [$tfbss];
        }
    }

    return $self->{-tfbss};
}

1;
