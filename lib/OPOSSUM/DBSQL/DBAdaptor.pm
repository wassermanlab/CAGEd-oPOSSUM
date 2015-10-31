=head1 NAME

0POSSUM::DBSQL::DBAdaptor

=head1 DESCRIPTION

This object represents a database. Once created you can retrieve database
adaptors specific to various database objects that allow the retrieval and
creation of objects from the database.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=cut

package OPOSSUM::DBSQL::DBAdaptor;

use strict;

use Carp;
use OPOSSUM::DBSQL::DBConnection;

=head2 new

 Title    : new
 Usage    : $db_adaptor = OPOSSUM::DBSQL::DBAdaptor->new(
                -dbconn => $dbc
            );

            OR

            $db_adaptor = OPOSSUM::DBSQL::DBAdaptor->new(
                -user	=> 'opossum_r',
                -host	=> 'localhost',
                -dbname	=> 'oPOSSUM'
            );

 Function : Construct a new DBAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::DBAdaptor object
 Args	  : Either a DBConnection or args for a DBConnection (passed through)

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {}, ref $class || $class;

    my $con = $args{-dbconn};
    if (defined $con) {
        $self->dbc($con);
    } else {
        $self->dbc(OPOSSUM::DBSQL::DBConnection->new(%args));
    }

    return $self;
}

=head2 dbc

  Title     : dbc
  Usage     : $dbc = $dba->dbc();
  Function  : Get/set DBConnection.
  Returns   : An OPOSSUM::DBSQL::DBConnection
  Args      : Optional Bio::EnsEMBL::DBSQL::DBConnection

=cut

sub dbc
{
  my $self = shift;

    if (@_) {
        my $arg = shift;

        if (defined($arg)) {
            if (!$arg->isa('OPOSSUM::DBSQL::DBConnection')) {
                carp "not a DBConnection\n";
            }
        }

        $self->{_dbc} = $arg;
    }

    return $self->{_dbc};
}

=head2 get_ExperimentAdaptor

 Title    : get_ExperimentAdaptor
 Usage    : $gpa = $db_adaptor->get_ExperimentAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::ExperimentAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::ExperimentAdaptor object
 Args	  : None.

=cut

sub get_ExperimentAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::ExperimentAdaptor");
}

=head2 get_TSSAdaptor

 Title    : get_TSSAdaptor
 Usage    : $gpa = $db_adaptor->get_TSSAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::TSSAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::TSSAdaptor object
 Args	  : None.

=cut

sub get_TSSAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::TSSAdaptor");
}

=head2 get_ExpressionAdaptor

 Title    : get_ExpressionAdaptor
 Usage    : $gpa = $db_adaptor->get_ExpressionAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::ExpressionAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::ExpressionAdaptor object
 Args	  : None.

=cut

sub get_ExpressionAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::ExpressionAdaptor");
}

=head2 get_SearchRegionAdaptor

 Title    : get_SearchRegionAdaptor
 Usage    : $sa = $db_adaptor->get_SearchRegionAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::SearchRegionAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::SearchRegionAdaptor object
 Args	  : None.

=cut

sub get_SearchRegionAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::SearchRegionAdaptor");
}

=head2 get_TFBSAdaptor

 Title    : get_TFBSAdaptor
 Usage    : $ctfsa = $db_adaptor->get_TFBSAdaptor();
 Function : TFBSAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::TFBSAdaptor object
 Args	  : None.

=cut

sub get_TFBSAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::TFBSAdaptor");
}

=head2 get_DBInfoAdaptor

 Title    : get_DBInfoAdaptor
 Usage    : $dbia = $db_adaptor->get_DBInfoAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::DBInfoAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::DBInfoAdaptor object
 Args	  : None.

=cut

sub get_DBInfoAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::DBInfoAdaptor");
}

=head2 get_TFBSCountAdaptor

 Title    : get_TFBSCountAdaptor
 Usage    : $tca = $db_adaptor->get_TFBSCountAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::TFBSCountAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::TFBSCountAdaptor object
 Args	  : None.

=cut

sub get_TFBSCountAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::TFBSCountAdaptor");
}

=head2 get_AnalysisCountsAdaptor

 Title    : get_AnalysisCountsAdaptor
 Usage    : $aca = $db_adaptor->get_AnalysisCountsAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::Analysis::CountsAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::Analysis::CountsAdaptor object
 Args	  : None.

=cut

sub get_AnalysisCountsAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::Analysis::CountsAdaptor");
}

=head2 get_AnalysisClusterCountsAdaptor

 Title    : get_AnalysisClusterCountsAdaptor
 Usage    : $aca = $db_adaptor->get_AnalysisClusterCountsAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::Analysis::Cluster::CountsAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::Analysis::Cluster::CountsAdaptor object
 Args	  : None.

=cut

sub get_AnalysisClusterCountsAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::Analysis::Cluster::CountsAdaptor");
}

=head2 get_SearchRegionLevelAdaptor

 Title    : get_SearchRegionLevelAdaptor
 Usage    : $srla = $db_adaptor->get_SearchRegionLevelAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::SearchRegionLevelAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::SearchRegionLevelAdaptor object
 Args	  : None.

=cut

sub get_SearchRegionLevelAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::SearchRegionLevelAdaptor");
}

=head2 get_ThresholdLevelAdaptor

 Title    : get_ThresholdLevelAdaptor
 Usage    : $tla = $db_adaptor->get_ThresholdLevelAdaptor();
 Function : Construct a new OPOSSUM::DBSQL::ThresholdLevelAdaptor object.
 Returns  : A new OPOSSUM::DBSQL::ThresholdLevelAdaptor object
 Args	  : None.

=cut

sub get_ThresholdLevelAdaptor
{
    my ($self) = @_;
    
    return $self->_get_adaptor("OPOSSUM::DBSQL::ThresholdLevelAdaptor");
}

=head2 _get_adaptor

 Title    : _get_adaptor
 Usage    : $adpator = $self->_get_adaptor("full::adaptor::name");
 Function : Used by subclasses to obtain adaptor objects from this
            database adaptor using the fully qualified module name
            of the adaptor. If the adaptor has not been retrieved before
            it is created, otherwise it is retrieved from the adaptor
            cache.
 Returns  : Adaptor object.
 Args	  : Fully qualified adaptor module name,
            optional arguments to be passed to the adaptor constructor.

=cut

sub _get_adaptor
{
    my ($self, $module) = @_;

    my ($adaptor, $internal_name);
  
    #Create a private member variable name for the adaptor by replacing
    #:: with _
  
    $internal_name = $module;

    $internal_name =~ s/::/_/g;

    unless (defined $self->{'_adaptors'}{$internal_name}) {
        eval "require $module";
        
        if ($@) {
            carp "$module cannot be found.\nException $@\n";
            return undef;
        }
          
        $adaptor = "$module"->new($self);

        $self->{'_adaptors'}{$internal_name} = $adaptor;
    }

    return $self->{'_adaptors'}{$internal_name};
}

1;
