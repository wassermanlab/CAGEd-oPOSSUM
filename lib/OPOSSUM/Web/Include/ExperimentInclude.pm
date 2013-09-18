#
# This module should be included in all the oPossumGene*Web.pm modules and
# possibly the background perl scripts called by those modules. It
# contains all routines that are common to all the oPossum gene-based variants.
#

use OPOSSUM::Opt::BaseOpt;
use OPOSSUM::Opt::ExperimentOpt;
use OPOSSUM::Web::Opt::BaseOpt;

use lib OPOSSUM_LIB;

use OPOSSUM::DBSQL::DBAdaptor;

use Data::Dumper;    # for debugging only

use strict;

sub opossum_db_connect
{
    my ($self) = @_;

    my $species = $self->state->species();

    unless ($species) {
        $self->_error("Species not set");
        return;
    }

    my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);

    my $dba = OPOSSUM::DBSQL::DBAdaptor->new(
        -host     => OPOSSUM_DB_HOST,
        -dbname   => $db_name,
        -user     => OPOSSUM_DB_USER,
        -password => OPOSSUM_DB_PASS
    );

    unless ($dba) {
        $self->_error("Could not connect to oPOSSUM database $db_name");
        return;
    }

    $self->opdba($dba);
}

sub opdba
{
    my $self = shift;

    if (@_) {
        $self->{-opdba} = shift;
    }

    return $self->{-opdba};
}

sub fetch_db_info
{
    my $self = shift;

    my $opdba = $self->opdba();
    if (!$opdba) {
        $opdba = $self->opossum_db_connect();
    }

    my $dbia = $opdba->get_DBInfoAdaptor();
    if (!$dbia) {
        $self->_error("Could not get DBInfoAdaptor");
    }

    my $db_info = $dbia->fetch_db_info();
    if (!$db_info) {
        $self->_error("Could not fetch DB info");
    }

    #$self->state->db_info($db_info);

    return $db_info;
}

sub fetch_experiment_count
{
    my ($self, $where) = @_;

    my $opdba = $self->opdba();
    if (!$opdba) {
        $opdba = $self->opossum_db_connect();
    }

    my $exa = $opdba->get_ExperimentAdaptor();
    if (!$exa) {
        $self->_error("Could not get ExperimentAdaptor");
    }

    my $count = $exa->fetch_experiment_count($where);
    if (!$count) {
        $self->_error("Could not fetch experiment count");
    }

    return $count;
}

sub create_t_tss_names_file
{
    my ($self, $query, $input_method, $localpath) = @_;

    return $self->create_local_file(
        $query, 't_tss_names_text', 't_tss_names_file', $input_method, 'target',
        "TSS names", $localpath
    );
}

sub create_b_tss_names_file
{
    my ($self, $query, $input_method, $localpath) = @_;

    return $self->create_local_file(
        $query, 'b_tss_names_text', 'b_tss_names_file', $input_method,
        'background', "TSS names", $localpath
    );
}

sub create_t_bed_file
{
    my ($self, $query, $input_method, $localpath) = @_;

    return $self->create_local_file(
        $query, 't_bed_text', 't_bed_file', $input_method, 'target',
        "BED", $localpath
    );
}

sub create_b_bed_file
{
    my ($self, $query, $input_method, $localpath) = @_;

    return $self->create_local_file(
        $query, 'b_bed_text', 'b_bed_file', $input_method, 'background',
        "BED", $localpath
    );
}

sub create_t_experiment_file
{
    my ($self, $query, $input_method, $localpath) = @_;

    return $self->create_local_file(
        $query, 't_exp_text', 't_exp_file', $input_method, 'target',
        "experiment", $localpath
    );
}

sub create_b_experiment_file
{
    my ($self, $query, $input_method, $localpath) = @_;

    return $self->create_local_file(
        $query, 'b_exp_text', 'b_exp_file', $input_method, 'background',
        "experiment", $localpath
    );
}

1;
