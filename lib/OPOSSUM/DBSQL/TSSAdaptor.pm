=head1 NAME

OPOSSUM::DBSQL::TSSAdaptor - Adaptor for MySQL queries to retrieve
and store TSS objects.

=head1 SYNOPSIS

$tssa = $db_adaptor->get_TSSAdaptor();

=head1 DESCRIPTION

The tss table contains records which store TSS tag cluster information.
This table stores the id, name, chromosomal coordinate information, max.
tag count and tpm values for these TSSs.

NOTE: The tss_extra table contains the short_description, description and
transcript association of the TSSs and the tss_genes table contains the genes
associated with the TSSs.

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut

package OPOSSUM::DBSQL::TSSAdaptor;

use strict;

use Carp;

use OPOSSUM::DBSQL::BaseAdaptor;
use OPOSSUM::TSS;

use vars '@ISA';
@ISA = qw(OPOSSUM::DBSQL::BaseAdaptor);

sub new
{
    my ($class, @args) = @_;

    $class = ref $class || $class;

    my $self = $class->SUPER::new(@args);

    return $self;
}

=head2 fetch_where

 Title    : fetch_where
 Usage    : $tss = $tssa->fetch_where($ids);
 Function : Fetch TSS(s) using optional where clause
 Returns  : A list ref of OPOSSUM::TSS objects.
 Args	  : Optionally, a where clause

=cut

sub fetch_where
{
    my ($self, $where) = @_;

    #
    # XXX
    # Note: not all columns retrieved by default
    #
    my $sql = qq{
        select distinct id, search_region_id, name, chrom, start, end, strand
        from tss
    };

    if ($where) {
        unless ($where =~ /^\*where\s+/) {
            $where = " where $where";
        }
        $sql .= " $where";
    }

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch TSSs:\n$sql\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch TSSs\n$sql\n" . $self->errstr;
        return;
    }

    my @tss;
    while (my @row = $sth->fetchrow_array) {
        push @tss, OPOSSUM::TSS->new(
            -id                             => $row[0],
            -search_region_id               => $row[1],
            -name                           => $row[2],
            -chrom                          => $row[3],
            -start                          => $row[4],
            -end                            => $row[5],
            -strand                         => $row[6],

            #
            # XXX
            # Don't fetch all columns
            #
            #-is_tss                         => $row[7],
            #-max_tag_count                  => $row[8],
            #-max_tpm                        => $row[9],
            #

            #
            # These fields are no longer stored in the tss table. They have
            # been separated out into tss_extra table.
            #
            #-short_description              => $row[10],
            #-description                    => $row[11],
            #-association_with_transcript    => $row[12]
            #
        );
    }

    return @tss ? \@tss : undef;
}

=head2 fetch_ids_where

 Title    : fetch_ids_where
 Usage    : $ids = $tssa->fetch_ids_where($where_clause);
 Function : Fetch a list of the TSS IDs in the database optionally using
            a where clause.
 Returns  : A list ref of integer TSS IDs.
 Args	  : Optionally an SQL where clause.

=cut

sub fetch_ids_where
{
    my ($self, $where_clause) = @_;

    my $sql = "select distinct id from tss";
    if ($where_clause) {
        $sql .= " where $where_clause";
    }

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch TSS IDs\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch TSS IDs\n" . $self->errstr;
        return;
    }

    my @ids;
    while (my ($id) = $sth->fetchrow_array) {
        push @ids, $id;
    }
    $sth->finish;

    return @ids if wantarray;

    return @ids ? \@ids : undef;
}

=head2 fetch_by_ids

 Title    : fetch_by_ids
 Usage    : $tss = $tssa->fetch_by_ids($ids);
 Function : Fetch TSS(s) by their associated ID(s).
 Returns  : A list ref of OPOSSUM::TSS objects.
 Args	  : Optionally, a TSS ID or list ref of TSS IDs.

=cut

sub fetch_by_ids
{
    my ($self, $tss_ids) = @_;

    my $where;

    if (defined $tss_ids) {
        my $ref = ref $tss_ids;
        if ($ref eq 'ARRAY' && $tss_ids->[0]) {
            if (scalar @$tss_ids > 1) {
                $where .= " id in (";
                $where .= join ",", @$tss_ids;
                $where .= ")";
            } else {
                $where .= sprintf(" id = %d", $tss_ids->[0]);
            }
        } else {
            $where .= " id = $tss_ids";
        }
    }

    return $self->fetch_where($where);
}

=head2 fetch_by_names

 Title    : fetch_by_names
 Usage    : $tss = $tssa->fetch_by_names($names);
 Function : Fetch TSS(s) by their associated name(s).
 Returns  : A list ref of OPOSSUM::TSS objects.
 Args	  : Optionally, a TSS name or list ref of TSS names.

=cut

sub fetch_by_names
{
    my ($self, $names) = @_;

    my $where;

    if (defined $names) {
        my $ref = ref $names;
        if ($ref eq 'ARRAY' && $names->[0]) {
            if (scalar @$names > 1) {
                $where .= " name in ('";
                $where .= join "','", @$names;
                $where .= "')";
            } else {
                $where .= sprintf(" name = '%s'", $names->[0]);
            }
        } else {
            $where .= " name = $names";
        }
    }

    return $self->fetch_where($where);
}

=head2 fetch_by_region

 Title    : fetch_by_region
 Usage    : $tss = $tssa->fetch_by_region($chrom, $start, $end);
 Function : Fetch TSS(s) by their chromosomal region
 Returns  : A list ref of OPOSSUM::TSS objects.
 Args	  : A chromosome name, start and end position.

=cut

sub fetch_by_region
{
    my ($self, $chrom, $start, $end) = @_;

    my $where;
    if ($chrom) {
        $where .= " chrom = '$chrom'";
    }

    #
    # XXX
    # Strictly within search region.
    # Should we just require overlapping?
    #
    if ($start) {
        $where .= " and" if $where;
        $where .= " start >= $start";
    }

    if ($end) {
        $where .= " and" if $where;
        $where .= " end <= $end";
    }

    return $self->fetch_where($where);
}

=head2 fetch

 Title    : fetch
 Usage    : $tss = $tssa->fetch
                -is_tss             => $is_tss,
                -names              => $names,
                -gene_ids           => $gene_ids,
                -experiment_ids     => $experiment_ids,
                -min_tag_count      => $min_tag_count,
                -min_tpm            => $min_tpm,
                -max_tag_count      => $max_tag_count,
                -max_tpm            => $max_tpm,
                -is_tss             => $is_tss,
                -search_region_ids  => $search_region_ids,
                -search_region_map  => $search_region_map
            );
 Function : Fetch a list of OPOSSUM::TSSs for the given experiment
            IDs, where the TSS counts and/or TPM values are above or below
            the given score thresholds, and optionally associated with a
            list of gene.
 Returns  : A list ref of OPOSSUM::TSS objects.
 Args     : 
            -is_tss             => OPTIONAL only fetch tag clusters which
                                   are flagged as TSSs
            -names              => OPTIONAL tag cluster name or list ref
                                   of names
            -gene_ids           => OPTIONAL gene ID or list ref of gene IDs.
                                   These must be either UniProt or
                                   EntrezGene (or HGNC for human) IDs.
            -experiment_ids     => OPTIONAL experiment ID or list ref of
                                   experiment IDs.
            -min_tag_count      => OPTIONAL minimum tag count of experiments
                                   associated with the TSSs to retrieve
            -min_tpm            => OPTIONAL minimum tags per million (TPM)
                                   of experiments associated with the TSSs
                                   to retrieve
            -max_tag_count      => OPTIONAL maximum tag count of experiments
                                   associated with the TSSs to retrieve
            -max_tpm            => OPTIONAL maximum tags per million (TPM)
                                   of experiments associated with the TSSs
                                   to retrieve
            -search_region_ids  => OPTIONAL search region ID or list ref
                                   of search region IDs. The search region
                                   IDs should be the IDs of the pre-computed
                                   search region and are essentially "bins"
                                   which allow for MUCH faster retrieval of
                                   TFBSs than using search region postions.
            -search_region_map  => OPTIONAL hash which maps the actual search
                                   regions to the pre-computed search region
                                   IDs, i.e. the hash keys are the
                                   pre-computed search region IDs
                                   and the elements are listrefs of
                                   OPOSSUM::SearchRegion objects.

=cut

sub fetch
{
    my ($self, %args) = @_;

    my $is_tss        = $args{-is_tss};
    my $names         = $args{-names};
    my $gene_ids      = $args{-gene_ids};
    my $exp_ids       = $args{-experiment_ids};
    my $min_tag_count = $args{-min_tag_count};
    my $min_tpm       = $args{-min_tpm};
    my $max_tag_count = $args{-max_tag_count};
    my $max_tpm       = $args{-max_tpm};
    my $pc_sr_ids     = $args{-search_region_ids};
    my $sr_map        = $args{-search_region_map};

    my $sql = qq{
        select distinct t.id, t.search_region_id, t.name, t.chrom,
        t.start, t.end, t.strand from tss t
    };

    my $join;
    my $where;

    if (
        defined $exp_ids || defined $min_tag_count || defined $min_tpm
        || defined $max_tag_count || defined $max_tpm
    ) {
        $sql .= ", expression x";
        $join .= " and " if $join;
        $join .= "t.id = x.tss_id";
    }

    if ($is_tss) {
        $where .= " and " if $where;
        $where .= "t.is_tss = 1";
    }

    if (defined $min_tag_count) {
        $where .= " and " if $where;
        $where .= "x.tag_count >= $min_tag_count";
    }

    if (defined $min_tpm) {
        $where .= " and " if $where;
        $where .= "x.tpm >= $min_tpm";
    }

    if (defined $max_tag_count) {
        $where .= " and " if $where;
        $where .= "x.tag_count <= $max_tag_count";
    }

    if (defined $max_tpm) {
        $where .= " and " if $where;
        $where .= "x.tpm <= $max_tpm";
    }

    if (defined $names) {
        my $ref = ref $names;

        if ($ref) {
            if ($ref eq 'ARRAY' && $names->[0]) {
                $where .= " and " if $where;

                if (scalar @$names > 1) {
                    $where .= "t.name in ('";
                    $where .= join "','", @$names;
                    $where .= "')";
                } else {
                    $where .= sprintf(" t.name = '%s'", $names->[0]);
                }
            }
        } else {
            $where .= " and " if $where;
            $where .= "t.name = '$names'";
        }
    }

    if (defined $gene_ids) {
        my $ref = ref $gene_ids;

         if ($ref) {
            if ($ref eq 'ARRAY' && defined $gene_ids->[0]) {
                $sql .= ", tss_genes tg";
                $join .= " and " if $join;
                $join .= "t.id = tg.tss_id";
                $where .= " and " if $where;

                if (scalar @$gene_ids > 1) {
                    $where .= "tg.gene_id in ('";
                    $where .= join "','", @$gene_ids;
                    $where .= "')";
                } else {
                    $where .= sprintf("tg.gene_id = '%s'", $gene_ids->[0]);
                }
            }
        } else {
            $sql .= ", tss_genes tg";
            $join .= " and " if $join;
            $join .= "t.id = tg.tss_id";
            $where .= " and " if $where;
            $where .= "tg.gene_id = '$gene_ids'";
        }
    }

    if (defined $exp_ids) {
        my $ref = ref $exp_ids;

        if ($ref) {
            if ($ref eq 'ARRAY' && defined $exp_ids->[0]) {
                $where .= " and " if $where;

                if (scalar @$exp_ids > 1) {
                    $where .= "x.experiment_id in (";
                    $where .= join ",", @$exp_ids;
                    $where .= ")";
                } else {
                    $where .= sprintf(" x.experiment_id = %d", $exp_ids->[0]);
                }
            }
        } else {
            $where .= " and " if $where;
            $where .= "x.experiment_id = $exp_ids";
        }
    }

    if (defined $pc_sr_ids) {
        my $ref = ref $pc_sr_ids;
        
        if ($ref) {
            if ($ref eq 'ARRAY' && $pc_sr_ids->[0]) {
                $where .= " and " if $where;

                if (scalar @$pc_sr_ids > 1) {
                    $where .= "t.search_region_id in (";
                    $where .= join ",", @$pc_sr_ids;
                    $where .= ")";
                } else {
                    $where .= sprintf(
                        "t.search_region_id = '%d'", $pc_sr_ids->[0]
                    );
                }
            }
        } else {
            $where .= " and " if $where;
            $where .= "t.search_region_id = $pc_sr_ids";
        }
    }

    $sql .= " where " if $join || $where;
    $sql .= "$join" if $join;
    if ($where) {
        $sql .= " and " if $join;
        $sql .= "$where";
    }

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch TSSs:\n$sql\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch TSSs:\n$sql\n" . $self->errstr;
        return;
    }

    my @tss;
    while (my @row = $sth->fetchrow_array) {
        push @tss, OPOSSUM::TSS->new(
            -id                             => $row[0],
            -search_region_id               => $row[1],
            -name                           => $row[2],
            -chrom                          => $row[3],
            -start                          => $row[4],
            -end                            => $row[5],
            -strand                         => $row[6]
        );
    }

    return @tss ? \@tss : undef;
}

1;
