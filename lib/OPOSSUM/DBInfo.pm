=head1 NAME

OPOSSUM::DBInfo - DBInfo object (db_info DB record)

=head1 DESCRIPTION

A DBInfo object models the (single) record contained in the db_info
table of the FANTOM5 oPOSSUM DB. The DBInfo object contains information about
how the FANTOM5 oPOSSUM database was built, including the databases and
software versions which were used.

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

package OPOSSUM::DBInfo;

use strict;
use Carp;
use OPOSSUM::DBObject;

use vars qw(@ISA);

@ISA = qw(OPOSSUM::DBObject);

=head2 new

 Title   : new
 Usage   : $db_info = OPOSSUM::DBInfo->new(
                -build_date		        => '2010/01/01 17:23:06',
                -species	            => 'mouse',
                -latin_name		        => 'mus musculus'
                -assembly		        => 'NCBI37'
                -ensembl_db	            => 'mus_musculus_core_56_37i',
                -dpi_filename           => 'mus_musculus_core_64_37 | mm9.tc.decompose_smoothing_merged.ctssMaxCounts11_ctssMaxTpm1.tpm.selected.clustername_update.desc.osc.txt',
                -min_threshold          => 0.75,
                -max_flank_size  	    => 2000,
                -tax_group              => 'vertebrates',
                -min_ic                 => 8
           );

 Function: Construct a new DBInfo object
 Returns : a new OPOSSUM::DBInfo object

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {%args}, ref $class || $class;

    return $self;
}

=head2 build_date

 Title   : build_date
 Usage   : $date = $dbbi->build_date() or $dbbi->build_date($date);

 Function: Get/set the DB build date.
 Returns : A string.
 Args    : None or a new DB build date.

=cut

sub build_date
{
    my ($self, $build_date) = @_;

    if ($build_date) {
        $self->{-build_date} = $build_date;
    }

    return $self->{-build_date};
}

=head2 species

 Title   : species
 Usage   : $species = $dbbi->species() or $dbbi->species($species);

 Function: Get/set the name of the species
 Returns : A string
 Args    : None or a new species name

=cut

sub species
{
    my ($self, $species) = @_;

    if ($species) {
        $self->{-species} = $species;
    }

    return $self->{-species};
}

=head2 latin_name

 Title   : latin_name
 Usage   : $latin_name = $dbbi->latin_name() or $dbbi->latin_name($latin_name);

 Function: Get/set the species latin name
 Returns : A string
 Args    : None or a new species latin name

=cut

sub latin_name
{
    my ($self, $latin_name) = @_;

    if ($latin_name) {
        $self->{-latin_name} = $latin_name;
    }

    return $self->{-latin_name};
}

=head2 assembly

 Title   : assembly
 Usage   : $assembly = $dbbi->assembly() or $dbbi->assembly($assembly);

 Function: Get/set the name of the genome assembly.
 Returns : A string.
 Args    : None or a new genome assembly name.

=cut

sub assembly
{
    my ($self, $assembly) = @_;

    if ($assembly) {
        $self->{-assembly} = $assembly;
    }

    return $self->{-assembly};
}

=head2 dpi_filename

 Title   : dpi_filename
 Usage   : $dpi_filename = $dbbi->dpi_filename()
           or $dbbi->dpi_filename($dpi_filename);

 Function: Get/set the name of the DPI expression file used.
 Returns : A string.
 Args    : None or a new dpi file name.

=cut

sub dpi_filename
{
    my ($self, $dpi_filename) = @_;

    if ($dpi_filename) {
        $self->{-dpi_filename} = $dpi_filename;
    }

    return $self->{-dpi_filename};
}

=head2 ensembl_db

 Title   : ensembl_db
 Usage   : $db_name = $dbbi->ensembl_db()
           or $dbbi->ensembl_db($db_name);

 Function: Get/set the name of the Ensembl species core database.
 Returns : A string.
 Args    : None or a new Ensembl species core database name.

=cut

sub ensembl_db
{
    my ($self, $db_name) = @_;

    if ($db_name) {
        $self->{-ensembl_db} = $db_name;
    }

    return $self->{-ensembl_db};
}

=head2 min_threshold

 Title   : min_threshold
 Usage   : $min_score = $dbbi->min_threshold()
           or $dbbi->min_threshold($min_score);

 Function: Get/set the minimum TFBS matrix score threshold used when building
           the database.
 Returns : A float.
 Args    : None or a new minimum score threshold.

=cut

sub min_threshold
{
    my ($self, $min_threshold) = @_;

    if (defined $min_threshold) {
        $self->{-min_threshold} = $min_threshold;
    }

    return $self->{-min_threshold};
}

sub min_tfbs_score
{
    my ($self, $min_score) = @_;

    carp "deprecated method min_tfb_score(); please use min_threshold()\n";

    return $self->min_threshold($min_score);
}

=head2 max_flank_size

 Title   : max_flank_size
 Usage   : $flank_size = $dbbi->max_flank_size()
 	       or $dbbi->max_flank_size($flank_size);

 Function: Get/set the maximum flanking bp size used in the DB.
 Returns : A string.
 Args    : None or a new max flanking bp amount.

=cut

sub max_flank_size
{
    my ($self, $flank_size) = @_;

    if ($flank_size) {
        $self->{-max_flank_size} = $flank_size;
    }

    return $self->{-max_flank_size};
}

=head2 tax_group

 Title   : tax_group
 Usage   : $tax_group = $dbbi->tax_group()
           or $dbbi->tax_group($tax_group);

 Function: Get/set the taxonomic supergroup(s) that this species belongs to.
           This could be a single tax group or a comma separated string of
           tax groups from the JASPAR CORE collection ('vertebrates',
           'plants', 'nematodes', 'fungi' etc). Note the pluralization of
           the names. 
           NOTE: For worms, this is not just one, but all metazoans.
 Returns : A tax group string.
 Args    : None or a new tax group string.

=cut

sub tax_group
{
    my ($self, $tax_group) = @_;

    if (defined $tax_group) {
        $self->{-tax_group} = $tax_group;
    }

    return $self->{-tax_group};
}

=head2 min_ic

 Title   : min_ic
 Usage   : $min_ic = $dbbi->min_ic()
           or $dbbi->min_ic($min_ic);

 Function: Get/set the TFBS profile matrix minimum information content
           used when building the database.
 Returns : An integer.
 Args    : None or a new matrix minimum information content.

=cut

sub min_ic
{
    my ($self, $min_ic) = @_;

    if (defined $min_ic) {
        $self->{-min_ic} = $min_ic;
    }

    return $self->{-min_ic};
}

sub min_pwm_ic
{
    my ($self, $min_ic) = @_;

    carp "deprecated method min_pwm_ic(); please use min_ic()\n";

    return $self->min_ic($min_ic);
}

1;
