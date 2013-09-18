=head1 NAME

OPOSSUM::Experiment - Experiment object (experiments DB record)

=head1 DESCRIPTION

A Experiment object models a record retrieved from the experiments table of
the FANTOM5 oPOSSUM DB.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::Experiment;

use strict;

use Carp;
use OPOSSUM::DBObject;

use vars qw(@ISA);

@ISA = qw(OPOSSUM::DBObject);

=head2 new

 Title   : new
 Usage   : $exp = OPOSSUM::Experiment->new(
			    -id	        => 1,
                -FF_id      => '12158-128G7',
                -CNhs_id    => 12533,
                -type       => 'primary_cell',
                -method     => 'LQhCAGE'
			    -name	    =>
                    'Atoh1+ Inner ear hair cells - organ of corti, pool1'
            );

 Function: Construct a new Experiment object
 Returns : a new OPOSSUM::Experiment object

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {%args}, ref $class || $class;

    return $self;
}

=head2 id

 Title   : id
 Usage   : $id = $exp->id() or $exp->id(99);

 Function: Get/set the ID of the Experiment. This should be a unique
           identifier for this object within the implementation. If
           the Experiment object was read from the oPOSSUM database,
           this should be set to the value in the id column.
 Returns : A numeric ID
 Args    : None or a numeric ID

=cut

sub id
{
    my ($self, $id) = @_;

    if ($id) {
        $self->{-id} = $id;
    }

    return $self->{-id};
}

#
# Synonym for id method
#
sub experiment_id
{
    my ($self, $id) = @_;

    return $self->id($id);
}

=head2 FF_id

 Title   : FF_id
 Usage   : $id = $exp->FF_id() or $exp->FF_id('12158-128G7');

 Function: Get/set the FANTOM5 ID of the Experiment. This is the FF
           ontology ID of the experiment.
 Returns : A FANTOM5 ontology (FF) ID
 Args    : None or a new FANTOM5 ontology (FF) ID

=cut

sub FF_id
{
    my ($self, $id) = @_;

    if ($id) {
        $self->{-FF_id} = $id;
    }

    return $self->{-FF_id};
}

=head2 CNhs_id

 Title   : CNhs_id
 Usage   : $id = $exp->CNhs_id() or $exp->CNhs_id(12533);

 Function: Get/set the CNhs (library) ID of the Experiment.
 Returns : A FANTOM5 ontology ID
 Args    : None or a new FANTOM5 ontology ID

=cut

sub CNhs_id
{
    my ($self, $id) = @_;

    if ($id) {
        $self->{-CNhs_id} = $id;
    }

    return $self->{-CNhs_id};
}

=head2 name

 Title   : name
 Usage   : $name = $exp->name() or $exp->name(
                'Atoh1+ Inner ear hair cells - organ of corti, pool1'
           );

 Function: Get/set the name of the Experiment.
 Returns : A string
 Args    : None or a string

=cut

sub name
{
    my ($self, $name) = @_;

    if ($name) {
        $self->{-name} = $name;
    }

    return $self->{-name};
}

=head2 type

 Title   : type
 Usage   : $type = $exp->type() or $exp->type($type);

 Function: Get/set the Experiment type
           (e.g. 'tissue', 'timecourse', 'primary_cell')
 Returns : A string
 Args    : None or a string

=cut

sub type
{
    my ($self, $type) = @_;

    if ($type) {
        $self->{-type} = $type;
    }

    return $self->{-type};
}

=head2 method

 Title   : method
 Usage   : $method = $exp->method() or $exp->method($method);

 Function: Get/set the Experiment method (e.g. 'hCAGE', 'LQhCAGE')
 Returns : A string
 Args    : None or a string

=cut

sub method
{
    my ($self, $method) = @_;

    if ($method) {
        $self->{-method} = $method;
    }

    return $self->{-method};
}
