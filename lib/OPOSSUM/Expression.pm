=head1 NAME

OPOSSUM::Expression - Expression object (expression DB record)

=head1 DESCRIPTION

A Expression object models a record retrieved from the expression table of
the FANTOM5 oPOSSUM DB.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::Expression;

use strict;

use Carp;
use OPOSSUM::DBObject;

use vars qw(@ISA);

@ISA = qw(OPOSSUM::DBObject);


=head2 new

 Title   : new
 Usage   : $expression = OPOSSUM::Expression->new(
                -experiment_id  => 89,
                -tss_id		    => 75,
                -tag_count		=> 100,
                -tpm			=> 0.075726193333184
           );

 Function: Construct a new Expression object
 Returns : a new OPOSSUM::Expression object

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {%args}, ref $class || $class;

    return $self;
}

=head2 experiment_id

 Title   : experiment_id
 Usage   : $exp_id = $expression->experiment_id()
           or $expression->experiment_id($exp_id);

 Function: Get/set the ID of the experiment associated with this
           Expression object.
 Returns : A numeric experiment ID
 Args    : None or a experiment ID

=cut

sub experiment_id
{
    my ($self, $id) = @_;

    if ($id) {
        $self->{-experiment_id} = $id;
    }

    return $self->{-experiment_id};
}

=head2 tss_id

 Title   : tss_id
 Usage   : $tss_id = $expression->tss_id()
           or $expression->tss_id($tss_id);

 Function: Get/set the ID of the TSS associated with this
           Expression object.
 Returns : A numeric TSS ID
 Args    : None or a TSS ID

=cut

sub tss_id
{
    my ($self, $id) = @_;

    if ($id) {
        $self->{-tss_id} = $id;
    }

    return $self->{-tss_id};
}

=head2 tag_count

 Title   : tag_count
 Usage   : $count = $expression->tag_count()
           or $expression->tag_count($count);

 Function: Get/set the tag count of the Expression object.
 Returns : A numeric tag count value
 Args    : None or a new tag count value

=cut

sub tag_count
{
    my ($self, $count) = @_;

    if (defined $count) {
        $self->{-tag_count} = $count;
    }

    return $self->{-tag_count};
}

=head2 tpm

 Title   : tpm
 Usage   : $tpm = $expression->tpm() or $expression->tpm($tpm);

 Function: Get/set the tags per million (TPM) of the Expression
           object.
 Returns : A numeric TPM value
 Args    : None or a new TPM value

=cut

sub tpm
{
    my ($self, $tpm) = @_;

    if (defined $tpm) {
        $self->{-tpm} = $tpm;
    }

    return $self->{-tpm};
}

1;
