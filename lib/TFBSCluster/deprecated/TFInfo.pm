=head1 NAME

TFBSCluster::TFInfo - TFInfo object (tf_info DB record)

=head1 DESCRIPTION

This represents the individual TFs that are mapped to a TFCluster

=head1 AUTHOR

 Andrew Kwon
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: tjkwon@cmmt.ubc.ca

=head1 METHODS

=cut
package TFBSCluster::TFInfo;


use strict;

use Carp;
use TFBS::Matrix;

=head2 new

 Title   : new
 Usage   : $ti = TFBSCluster::TFInfo->new(
				);

 Function: Construct a new TFInfo object
 Returns : a new TFBSCluster::TFInfo object

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

 Title	: id
 Usage	: $id = $tc->id() or $tc->id($id);
 Function: Get/set the ID of the TFInfo object.  This should be a unique 
 	identifier for this object within the implementation.
 Returns: An Integer
 Args	: None or an id integer
=cut

sub id
{
	my ($self, $id) = @_;

	if (defined $id) {
		$self->{-tf_id} = $id;
	}
	return $self->{-tf_id};
}

=head2 tf_id

 Title	: tf_id
 Usage	: $id = $tc->tf_id() or $tc->tf_id($id);
 Function: Get/set the ID of the TFInfo object.  This should be a unique 
 	identifier for this object within the implementation. Synonym for id()
 Returns: An Integer
 Args	: None or an id integer
=cut

sub tf_id
{
	my ($self, $id) = @_;

	if (defined $id) {
		$self->{-tf_id} = $id;
	}
	return $self->{-tf_id};
}

=head2 name

 Title   : name
 Usage   : $name = $ti->name() or $ti->name($name);

 Function: Get/set the name of the TFBS profile.
 Returns : A string
 Args	: None or an id string

=cut

sub name
{
	my ($self, $name) = @_;

	if (defined $name) {
	$self->{-name} = $name;
	}
	return $self->{-name};
}

=head2 external_id

 Title   : external_id
 Usage   : $id = $ti->external_id() or $ti->external_id($id);

 Function: Get/set the external ID of the TFBS profile. Within the context
 	   of the oTFBSCluster database this is the unique ID of this profile
	   in the originating DB (i.e. JASPAR2).
 Returns : An external ID string
 Args	: None or an ID string

=cut

sub external_id
{
	my ($self, $external_id) = @_;

	if (defined $external_id) {
	$self->{-external_id} = $external_id;
	}
	return $self->{-external_id};
}

=head2 source

 Title   : source
 Usage   : $db = $ti->source() or $ti->source($db);

 Function: Get/set the external DB name of the TFBS profile
	   (i.e. JASPAR_CORE).
 Returns : A DB name
 Args	: None or a DB name

=cut

sub source
{
	my ($self, $db_name) = @_;

	if (defined $db_name) {
	$self->{-source} = $db_name;
	}
	return $self->{-source};
}

=head2 collection

 Title   : collection
 Usage   : $col = $ti->collection() or $ti->collection($col);

 Function: Get/set the external DB collection of the TFBS profile
	   (i.e. CORE in JASPAR).
 Returns : A DB collection name
 Args	: None or a DB collection name

=cut

sub collection
{
	my ($self, $col_name) = @_;

	if (defined $col_name) {
	$self->{-collection} = $col_name;
	}
	return $self->{-collection};
}
=head2 class

 Title   : class
 Usage   : $class = $ti->class() or $ti->class($class);

 Function: Get/set the class of the TFBS profile.
 Returns : A string
 Args	: None or a string

=cut

sub class
{
	my ($self, $class) = @_;

	if (defined $class) {
	$self->{-class} = $class;
	}
	return $self->{-class};
}

=head2 family

 Title   : family
 Usage   : $family = $ti->family() or $ti->family($family);

 Function: Get/set the family of the TFBS profile.
 Returns : A string
 Args	: None or a string

=cut

sub family
{
	my ($self, $family) = @_;

	if (defined $family) {
	$self->{-family} = $family;
	}
	return $self->{-family};
}

=head2 tax_group

 Title   : tax_group
 Usage   : $tax_group = $ti->tax_group() or $ti->tax_group($tax_group);

 Function: Get/set the tax_group of the TFBS profile. This might be more
 	   accurately called taxonomic supergroup.
 Returns : A string
 Args	: None or a string

=cut

sub tax_group
{
	my ($self, $tax_group) = @_;

	if (defined $tax_group) {
	$self->{-tax_group} = $tax_group;
	}
	return $self->{-tax_group};
}

=head2 width

 Title   : width
 Usage   : $width = $ti->width() or $ti->width($width);

 Function: Get/set the width of the TFBS profile in nucleotides.
 Returns : An integer
 Args	: None or an integer

=cut

sub width
{
	my ($self, $width) = @_;

	if (defined $width) {
	$self->{-width} = $width;
	}
	return $self->{-width};
}

=head2 ic

 Title   : ic
 Usage   : $ic = $ti->ic() or $ti->ic($ic);

 Function: Get/set the information content of the TFBS profile. This is also
 	   known as specificity.
 Returns : A float
 Args	: None or a float

=cut

sub ic
{
	my ($self, $ic) = @_;

	if (defined $ic) {
	$self->{-ic} = $ic;
	}
	return $self->{-ic};
}

=head2 matrix

 Title	: matrix
 Usage	: $tf = $ti->matrix() or $ti->matrix($matrix);
 Function: Optionally get/sets the TFBS::Matrix object for this TF.
 Returns: A TFBS::Matrix object
 Args	: None or an TFBS::Matrix object
 
=cut

sub matrix
{
	my ($self, $matrix) = @_;

    if (ref $matrix && !$matrix->isa("TFBS::Matrix")) {
        carp "tf_matrix() argument is not a TFBS::Matrix object";
        return;
    }
	
	if (defined $matrix) {
		$self->{-matrix} = $matrix;
	}
	
	return $self->{-matrix};
	
}

1;
