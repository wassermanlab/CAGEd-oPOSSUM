=head1 NAME

OPOSSUM::DBSQL::DBInfoAdaptor - Adaptor for MySQL queries to retrieve and
store global DB information.

=head1 SYNOPSIS

$cla = $db_adaptor->get_DBInfoAdaptor();

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

package OPOSSUM::DBSQL::DBInfoAdaptor;

use strict;

use Carp;

use OPOSSUM::DBSQL::BaseAdaptor;
use OPOSSUM::DBInfo;

use vars qw(@ISA);
@ISA = qw(OPOSSUM::DBSQL::BaseAdaptor);

=head2 new

 Title    : new
 Usage    : $dbbia = OPOSSUM::DBSQL::DBInfoAdaptor->new(@args);
 Function : Create a new DBInfoAdaptor.
 Returns  : A new OPOSSUM::DBSQL::DBInfoAdaptor object.
 Args	  : An OPOSSUM::DBSQL::DBConnection object.

=cut

sub new
{
    my ($class, @args) = @_;

    $class = ref $class || $class;

    my $self = $class->SUPER::new(@args);

    return $self;
}

=head2 fetch_db_info

 Title    : fetch_db_info
 Usage    : $db_info = $cla->fetch_db_info();
 Function : Fetch the global database information.
 Returns  : An OPOSSUM::DBInfo object.
 Args	  : None.

=cut

sub fetch_db_info
{
    my $self = shift;

    my $sql = qq{
        select date_format(build_date, '%Y/%m/%d %T'),
			species,
			latin_name,
			assembly,
			ensembl_db,
			dpi_filename,
			min_threshold,
			max_flank_size,
			tax_group,
			min_ic
        from db_info
    };

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "error reading OPOSSUM DB info\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "error reading OPOSSUM DB info\n" . $self->errstr;
        return;
    }
    my @row = $sth->fetchrow_array;
    $sth->finish;
    if (!@row) {
        carp "error reading OPOSSUM DB info\n" . $self->errstr;
        return;
    }

    my $db_info = OPOSSUM::DBInfo->new(
        -build_date       => $row[0],
        -species          => $row[1],
        -latin_name       => $row[2],
        -assembly         => $row[3],
        -ensembl_db       => $row[4],
        -dpi_filename     => $row[5],
        -min_threshold    => $row[6],
        -max_flank_size   => $row[7],
		-tax_group        => $row[8],
        -min_ic           => $row[9],
    );

    return $db_info;
}

=head2 store

 Title    : store
 Usage    : $cla->store($db_info);
 Function : Store the global database information.
 Returns  : TRUE on success, FALSE otherwise
 Args     : An OPOSSUM::DBInfo object.

=cut

sub store
{
    my ($self, $db_info) = @_;

    if (!ref $db_info || !$db_info->isa('OPOSSUM::DBInfo')) {
        carp "Not an OPOSSUM::DBInfo object";
        return 0;
    }

    my $sql = qq{
        insert into db_info (build_date, species, latin_name, assembly,
            ensembl_db, dpi_filename, min_threshold, max_flank_size,
            tax_group, min_ic)
        values (now(),?,?,?,?,?,?,?,?,?)
    };

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing insert db_info statement\n" . $self->errstr;
        return 0;
    }

    #
    # Using built-in MySQL now() function in SQL statement above.
    #
    #my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    #
    #$year += 1900;  # localtime returns year as years since 1900
    #$mon += 1;      # localtime returns month in range 0-11

    # Standard MySQL datetime string format
    #my $datestr = "$year-$mon-$mday $hour:$min:$sec";

    my $ok = $sth->execute(
        #$datestr,
        $db_info->species(),
        $db_info->latin_name(),
        $db_info->assembly(),
        $db_info->ensembl_db(),
        $db_info->dpi_filename(),
        $db_info->min_threshold(),
        $db_info->max_flank_size(),
		$db_info->tax_group(),
        $db_info->min_ic()
    );
    
    unless ($ok) {
        carp "Error inserting db_info\n" . $self->errstr();
    }

    $sth->finish;

    return $ok;
}

1;
