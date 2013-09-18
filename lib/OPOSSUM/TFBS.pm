=head1 NAME

OPOSSUM::TFBS - TFBS object (tfbss DB record)

=head1 DESCRIPTION

A TFBS object models a record retrieved from the tfbss table of the oPOSSUM DB.
The TFBS object contains the start and end positions of the TFBS site well as
the PSSM score and level of conservation.

=head1 MODIFICATIONS

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut
package OPOSSUM::TFBS;

use strict;
use Carp;
use OPOSSUM::DBObject;

use vars qw(@ISA);

@ISA = qw(OPOSSUM::DBObject);


=head2 new

 Title   : new
 Usage   : $tfbs = OPOSSUM::TFBS->new(
                -tf_id              => 'MA0001.1',
                -chrom              => '1',
                -start              => 646823928,
                -end                => 646823937,
                -strand             => 1,
                -score              => 1.897,
                -rel_score          => 0.765,
                -seq                => 'CCAAGGATAG',
                -conservation_level => 1,
                -conservation       => 0.832
            );

 Function: Construct a new TFBS object
 Returns : a new OPOSSUM::TFBS object

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {
        %args
    }, ref $class || $class;

    return $self;
}

=head2 param

 Title    : param
 Usage    : $value = $ctfs->param($param)
            or $ctfs->param($param, $value);
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

=head2 tf_id

 Title   : tf_id
 Usage   : $tf_id = $ctfs->tf_id() or $ctfs->tf_id($tf_id);

 Function: Get/set the ID of the TFBS profile (matrix) associated with
           this TFBS.
 Returns : The TFBS profile ID.
 Args    : None or a new ID.

=cut

sub tf_id
{
    my ($self, $tf_id) = @_;

    if (defined $tf_id) {
        $self->{-tf_id} = $tf_id;
    }
    return $self->{-tf_id};
}

=head2 id

 Title   : id
 Usage   : $tf_id = $ctfs->id() or $ctfs->id($tf_id);

 Function: Synonymous with the 'tf_id' method.

=cut

sub id
{
    my ($self, $tf_id) = @_;

    return $self->tf_id($tf_id);
}

=head2 search_region_id

 Title   : search_region_id
 Usage   : $search_region_id = $ctfs->search_region_id()
           or $ctfs->search_region_id($search_region_id);

 Function: Get/set the ID of the search region to which this TFBS belongs
 Returns : The search region ID.
 Args    : None or a new search region ID.

=cut

sub search_region_id
{
    my ($self, $search_region_id) = @_;

    if (defined $search_region_id) {
        $self->{-search_region_id} = $search_region_id;
    }
    return $self->{-search_region_id};
}

=head2 chrom

 Title   : chrom
 Usage   : $chrom = $ctfs->chrom() or $ctfs->chrom($chrom);

 Function: Get/set the chromosome name of this TFBS
 Returns : An string.
 Args    : None or a new chromosome name.

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
 Usage   : $start = $ctfs->start() or $ctfs->start($start);

 Function: Get/set the start position of this TFBS
 Returns : An integer.
 Args    : None or a new start position.

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
 Usage   : $end = $ctfs->end() or $ctfs->end($end);

 Function: Get/set the end position of this TFBS
 Returns : An integer.
 Args    : None or a new end position.

=cut

sub end
{
    my ($self, $end) = @_;

    if ($end) {
        $self->{-end} = $end;
    }
    return $self->{-end};
}

=head2 strand

 Title   : strand
 Usage   : $strand = $ctfs->strand() or $ctfs->strand($strand);

 Function: Get/set the strand of this TFBS
 Returns : 1 or -1.
 Args    : None or a new strand.

=cut

sub strand
{
    my ($self, $strand) = @_;

    if ($strand) {
        $self->{-strand} = $strand;
    }
    return $self->{-strand};
}

=head2 seq

 Title   : seq
 Usage   : $seq = $ctfs->seq() or $ctfs->seq($seq);

 Function: Get/set the sequence of this TFBS
 Returns : A string.
 Args    : None or a new sequence.

=cut

sub seq
{
    my ($self, $seq) = @_;

    if ($seq) {
        $self->{-seq} = $seq;
    }
    return $self->{-seq};
}

=head2 score

 Title   : score
 Usage   : $score = $ctfs->score() or $ctfs->score($score);

 Function: Get/set the matrix score of this TFBS
 Returns : A real number.
 Args    : None or a new score.

=cut

sub score
{
    my ($self, $score) = @_;

    if ($score) {
        $self->{-score} = $score;
    }
    return $self->{-score};
}

=head2 rel_score

 Title   : rel_score
 Usage   : $score = $ctfs->rel_score() or $ctfs->rel_score($score);

 Function: Get/set the matrix relative score of this TFBS
 Returns : A real number.
 Args    : None or a new relative score.

=cut

sub rel_score
{
    my ($self, $score) = @_;

    if ($score) {
        $self->{-rel_score} = $score;
    }
    return $self->{-rel_score};
}

=head2 search_region

 Title   : search_region
 Usage   : $search_region = $ctfs->search_region()
           or $ctfs->search_region($search_region);

 Function: Get/set the search region which this TFBS falls into.
 Returns : An OPOSSUM::SearchRegion object.
 Args    : None or a new OPOSSUM::SearchRegion object.

=cut

sub search_region
{
    my ($self, $search_region) = @_;

    if (defined $search_region) {
        $self->{-search_region} = $search_region;
    }
    return $self->{-search_region};
}

1;
