=head1 NAME

OPOSSUM::DBSQL::TFBSAdaptor - Adaptor for MySQL queries to retrieve
and store TFBSs and TFBS counts.

=head1 SYNOPSIS

 $tfbsa = $db_adaptor->get_TFBSAdaptor();

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

package OPOSSUM::DBSQL::TFBSAdaptor;

use strict;

use Carp;

use OPOSSUM::DBSQL::BaseAdaptor;
#use OPOSSUM::TFBSCount;
use OPOSSUM::TFBS;
use OPOSSUM::Analysis::Counts;
use Bio::SeqFeature::Generic;
use Bio::SeqFeature::FeaturePair;
use TFBS::Site;
use TFBS::SiteSet;

use vars '@ISA';
@ISA = qw(OPOSSUM::DBSQL::BaseAdaptor);

=head2 new

 Title    : new
 Usage    : $tfbsa = OPOSSUM::DBSQL::TFBSAdaptor->new(@args);
 Function : Create a new TFBSAdaptor.
 Returns  : A new OPOSSUM::DBSQL::TFBSAdaptor object.
 Args	  : An OPOSSUM::DBSQL::DBConnection object.

=cut

sub new
{
    my ($class, @args) = @_;

    $class = ref $class || $class;

    my $self = $class->SUPER::new(@args);

    return $self;
}

=head2 fetch_tf_ids

 Title    : fetch_tf_ids
 Usage    : $ids = $tfbsa->fetch_tf_ids();
 Function : Fetch a list of all the distinct TF IDs for all the TFBSs in
            the current DB.
 Returns  : A list ref of integer TF IDs.
 Args	  : None.

=cut

sub fetch_tf_ids
{
    my ($self) = @_;

    my $sql = qq{select distinct tf_id from tfbss};

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "error fetching TF IDs\n" . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "error fetching TF IDs\n" . $self->errstr;
        return;
    }

    my @ids;
    while (my ($id) = $sth->fetchrow_array) {
        push @ids, $id;
    }

    return @ids if wantarray;

    return @ids ? \@ids : undef;
}

# DJA 2016/04/06
=head2 fetch_search_region_tfbs_map

 Title    : fetch_search_region_tfbs_map

 Usage    : $sr_tfbs_map = $tfbsa->fetch_search_region_tfbs_map(
                -tf_ids             => $tf_ids,
                -tf_set             => $tf_set,
                -threshold          => $threshold,
                -search_region_map  => $search_region_map,
                -logger             => $logger
            );

 Function : Fetch all the TFBS for the given search resgions based on the
            provided TFBS search criteria and build a heirarchical data
            structure which captures the relationship of the TFBSs to the
            search regions, i.e. a mapping of the search regions to the
            TFBSs they contain.

 Returns  : A listref of OPOSSUM::TFBSCount objects.

 Args	  : -tf_ids             => OPTIONAL TF ID or list ref of TF IDs.
            -tf_set             => OPTIONAL OPOSSUM::TFSet object (TF IDs
                                   take precedent over TF set).
            -threshold          => OPTIONAL TFBS score threshold
                                   (range 0.0 - 1.0).
            -search_region_map  => A hash which maps the actual search
                                   regions to the pre-computed search region
                                   IDs, i.e. the hash keys are the
                                   pre-computed search region IDs
                                   and the elements are listrefs of
                                   OPOSSUM::SearchRegion objects.
            -results_dir        => OPTIONAL directory path into which are
                                   written the TFBS details in a data format
                                   which is specific to the Template Toolkit
                                   Datafile plugin
                                   (see Template::Manual::Plugins). These
                                   datafile may be used later to format
                                   the TFBS details in both simple text and
                                   HTML format. This functionality also
                                   requires specific TFs to be passed either
                                   by the -tf_set or -tf_ids arguments.
            -logger             => OPTIONAL for debugging purposes. If a 
                                   Log::Log4perl logger object is provided,
                                   log DEBUG/INFO messages.

 This is adapted from fetch_tfbs_counts(). Instead of just finding the
 TFBS, printing the search regions / TFBSs to file and returning only the
 TFBS counts, build the data structure relating the TFBS to their search
 regions and return it. This is much more modular. The reason for
 fetch_tfbs_counts being so "un"-modular was for memory efficiency (no need
 to store the individaul TFBS data structures.

 The motivation for this routine is that we now may have to compute TFBS
 clusters so we really want to return the actual TFBSs (and their search
 region relationship) and not just their counts. If we try to compute the
 clusters counts within this routine we we will end up with an even more
 unweildy and un-modular routine!!!

 The SQL query execution has also been modified to include the specific start
 and end constraints within each search region rather than fetching all TFBS
 in a pre-computed region and checking the starts and ends in the perl code.

=cut

sub fetch_search_region_tfbs_map
{
    my ($self, %args) = @_;

    my $tf_set              = $args{-tf_set};
    my $tf_ids              = $args{-tf_ids};
    my $threshold           = $args{-threshold};
    my $search_region_map   = $args{-search_region_map};
    #my $logger              = $args{-logger};

    unless ($search_region_map) {
        carp "No search region map provided\n";
        return;
    }

    my @pc_sr_ids = keys %$search_region_map;
    unless (@pc_sr_ids && $pc_sr_ids[0]) {
        carp "Search region map is empty\n";
        return;
    }

    #
    # Build the SQL query
    #
    my $sql = "select search_region_id, tf_id, chrom, start, end, strand,"
            . " score, rel_score, seq from tfbss";

    my $where = "search_region_id = ? and start >= ? and end <= ?";

    my $tf_ids_passed = 0;
    my @passed_tf_ids;
    if ($tf_ids) {
        my $ref = ref $tf_ids;
        if ($ref eq 'ARRAY') {
            # -tf_ids value is an array ref of TF ID
            if ($tf_ids->[0]) {
                $where .= " and" if $where;
                $where .= " tf_id in ('";
                $where .= join("','", @$tf_ids);
                $where .= "')";

                # Also store TF IDs in a definitive array context
                $tf_ids_passed = 1;
                @passed_tf_ids = @$tf_ids;
            }
        } else {
            # -tf_ids value is actually a (scalar) single TF ID
            $where .= " and" if $where;
            $where .= " tf_id = '$tf_ids'";

            # Also store TF IDs in a definitive array context
            $tf_ids_passed = 1;
            push @passed_tf_ids, $tf_ids;
        }
    } elsif ($tf_set) {
        my $tf_set_ids = $tf_set->ids;
        if ($tf_set_ids->[0]) {
            $where .= " and" if $where;
            $where .= " tf_id in ('";
            $where .= join("','", @$tf_set_ids);
            $where .= "')";

            # Also store TF IDs in a definitive array context
            $tf_ids_passed = 1;
            @passed_tf_ids = @$tf_set_ids;
        }
    }

    if ($threshold) {
        $where .= " and" if $where;

        if ($threshold =~ /(.+)%$/) {
            $threshold = $1 / 100;
        }
            
        $where .= " rel_score >= $threshold";
    }

    $sql .= " where $where" if $where;

    my $sth = $self->prepare($sql);

    unless ($sth) {
        carp "Error preparing fetch TFBSs with:\n$sql\n" . $self->errstr . "\n";
        return;
    }

    my %sr_tfbs_map;
    my %tf_hit_lines;
    my %found_tf_ids_hash;
    foreach my $pc_sr_id (@pc_sr_ids) {
        #
        # Get actual search regions corresponding to this pre-computed search
        # region ID.
        #
        my $search_regions = $search_region_map->{$pc_sr_id};

        #
        # Execute SQL for each of the search regions.
        #
        foreach my $sr (@$search_regions) {
            unless ($sth->execute($pc_sr_id, $sr->start, $sr->end)) {
                my $sql_err = $sql;
                $sql_err =~ s/\?/%s/g;

                carp sprintf(
                    "Error executing fetch TFBSs with SQL:\n$sql_err\n%s\n",
                    $pc_sr_id, $sr->start, $sr->end, $self->errstr
                );

                return;
            }

            while (my @row = $sth->fetchrow_array) {
                my $tf_id = $row[1];

                #
                # Add TFBS to search regions TFBS map.
                #
                push @{$sr_tfbs_map{$sr->id}->{$tf_id}},
                            OPOSSUM::TFBS->new(
                                -tf_id      => $tf_id,
                                -chrom      => $row[2],
                                -start      => $row[3],
                                -end        => $row[4],
                                -strand     => $row[5],
                                -score      => $row[6],
                                -rel_score  => $row[7],
                                -seq        => $row[8]
                            );
            }
        }
    }

    return %sr_tfbs_map ? \%sr_tfbs_map : undef;
}

=head2 fetch_tfbs_counts

 Title    : fetch_tfbs_counts
 Usage    : $counts = $tfbsa->fetch_tfbs_counts(
                -tf_ids             => $tf_ids,
                -tf_set             => $tf_set,
                -threshold          => $threshold,
                -search_region_map  => $search_region_map,
                -results_dir        => $results_dir,
                -logger             => $logger
            );
 Function : Fetch counts of the number of binding sites. Optionally limit
            to a given set of TFs, TFBS score threshold and search regions.
 Returns  : A listref of OPOSSUM::TFBSCount objects.
 Args	  : -tf_ids             => OPTIONAL TF ID or list ref of TF IDs.
            -tf_set             => OPTIONAL OPOSSUM::TFSet object (TF IDs
                                   take precedent over TF set).
            -threshold          => OPTIONAL TFBS score threshold
                                   (range 0.0 - 1.0).
            -search_region_map  => A hash which maps the actual search
                                   regions to the pre-computed search region
                                   IDs, i.e. the hash keys are the
                                   pre-computed search region IDs
                                   and the elements are listrefs of
                                   OPOSSUM::SearchRegion objects.
            -results_dir        => OPTIONAL directory path into which are
                                   written the TFBS details in a data format
                                   which is specific to the Template Toolkit
                                   Datafile plugin
                                   (see Template::Manual::Plugins). These
                                   datafile may be used later to format
                                   the TFBS details in both simple text and
                                   HTML format. This functionality also
                                   requires specific TFs to be passed either
                                   by the -tf_set or -tf_ids arguments.
            -logger             => OPTIONAL for debugging purposes. If a 
                                   Log::Log4perl logger object is provided,
                                   log DEBUG/INFO messages.

 This is the version of fetch_tfbs_counts after the SQL query was split up
 to use multiple queries (one for each pre-computed search region) rather
 then using a giant 'in' clause to search for all regions simultaneously,
 modified from what is now renamed fetch_tfbs_counts_old. In testing,
 splitting into multiple SQL statements based on pre-computed search regions
 versus a single SQL with an in clause showed this version to be much faster
 (~10 secs vs. ~50 secs for ~1300 search regions).
 
 Other modifications were made to better keep track of whether and how TF IDs
 were passed in and how this affects initialization and storage of the search
 regions / TFBS binding site counts.

=cut

sub fetch_tfbs_counts
{
    my ($self, %args) = @_;

    my $tf_set              = $args{-tf_set};
    my $tf_ids              = $args{-tf_ids};
    my $threshold           = $args{-threshold};
    my $search_region_map   = $args{-search_region_map};
    my $results_dir         = $args{-results_dir};
    #my $logger              = $args{-logger};

    unless ($search_region_map) {
        carp "No search region map provided\n";
        return;
    }

    my @pc_sr_ids = keys %$search_region_map;
    unless (@pc_sr_ids && $pc_sr_ids[0]) {
        carp "Search region map is empty\n";
        return;
    }

    my @sr_ids;
    foreach my $pc_sr_id (@pc_sr_ids) {
        foreach my $sr (@{$search_region_map->{$pc_sr_id}}) {
            if ($sr) {
                push @sr_ids, $sr->id;
            }
        }
    }

    #
    # Build the SQL query
    #
    my $sql = "select search_region_id, tf_id, chrom, start, end, strand,"
            . " score, rel_score, seq from tfbss";

    my $where = " search_region_id = ?";

    my $tf_ids_passed = 0;
    my @passed_tf_ids;
    if ($tf_ids) {
        my $ref = ref $tf_ids;
        if ($ref eq 'ARRAY') {
            # -tf_ids value is an array ref of TF ID
            if ($tf_ids->[0]) {
                $where .= " and" if $where;
                $where .= " tf_id in ('";
                $where .= join("','", @$tf_ids);
                $where .= "')";

                # Also store TF IDs in a definitive array context
                $tf_ids_passed = 1;
                @passed_tf_ids = @$tf_ids;
            }
        } else {
            # -tf_ids value is actually a (scalar) single TF ID
            $where .= " and" if $where;
            $where .= " tf_id = '$tf_ids'";

            # Also store TF IDs in a definitive array context
            $tf_ids_passed = 1;
            push @passed_tf_ids, $tf_ids;
        }
    } elsif ($tf_set) {
        my $tf_set_ids = $tf_set->ids;
        if ($tf_set_ids->[0]) {
            $where .= " and" if $where;
            $where .= " tf_id in ('";
            $where .= join("','", @$tf_set_ids);
            $where .= "')";

            # Also store TF IDs in a definitive array context
            $tf_ids_passed = 1;
            @passed_tf_ids = @$tf_set_ids;
        }
    }

    if ($threshold) {
        $where .= " and" if $where;

        if ($threshold =~ /(.+)%$/) {
            $threshold = $1 / 100;
        }
            
        $where .= " rel_score >= $threshold";
    }

    $sql .= " where $where" if $where;

    #$logger->info("fetch_tfbs_counts SQL:\n$sql\n");

    #
    # Don't use extra memory/time sorting in SQL as chromosome sorting is
    # not correct and we need to resort anyway.
    #
    #$sql .= " order by chrom, start, end";

    my $sth = $self->prepare($sql);
    unless ($sth) {
        carp "Error preparing fetch TFBSs with:\n$sql\n"
            . $self->errstr . "\n";
        return;
    }

    #
    # XXX
    # If the actual TF IDs were passed in via either the -tf_ids or the -tf_set
    # arguments then initialize the counts for all the search region / TF
    # combinations to 0 as we want to report the 0 counts in the final results.
    # Howerer if we don't have these (fetching binding site counts for all TFs)
    # we will only initialize / store counts when there is at least 1
    # binding site for a given TF in a given search region. So we will lose the
    # 0 counts in the final results, but perhaps this is not such an issue?
    # XXX
    #
    my %sr_tfbs_count;
    if ($tf_ids_passed) {
        foreach my $sr_id (@sr_ids) {
            foreach my $tf_id (@passed_tf_ids) {
                $sr_tfbs_count{$sr_id}->{$tf_id} = 0;
            }
        }
    }

    my %tf_hit_lines;
    my %found_tf_ids_hash;
    foreach my $pc_sr_id (@pc_sr_ids) {
        unless ($sth->execute($pc_sr_id)) {
            carp "Error executing fetch TFBSs with:\n$sql\n"
                ."pre-computed search region id = $pc_sr_id\n"
                . $self->errstr . "\n";
            return;
        }

        #
        # Get actual search regions corresponding to this pre-computed search
        # region ID.
        #
        my $search_regions = $search_region_map->{$pc_sr_id};

        while (my @row = $sth->fetchrow_array) {
            my $tf_id = $row[1];
            my $tfbs_start = $row[3];
            my $tfbs_end   = $row[4];

            #
            # Loop through actual search regions to see which one the TFBS
            # falls into.
            #
            foreach my $sr (@$search_regions) {
                if ($tfbs_start >= $sr->start && $tfbs_end <= $sr->end) {
                    #
                    # Increment count for this TF in this search region.
                    #
                    $sr_tfbs_count{$sr->id}->{$tf_id}++;

                    #
                    # Keep track of all (unique) TF IDs actually found
                    # within at least one of the search region.
                    #
                    $found_tf_ids_hash{$tf_id} = 1;

                    #
                    # Write binding site details to file
                    #
                    # Actually, don't write. Store lines by TF for sorting
                    # before writing out to file.
                    #
                    if ($results_dir) {
                        my $region_str = sprintf "chr%s:%d-%d",
                            $sr->chrom,
                            $sr->start,
                            $sr->end;

                        push @{$tf_hit_lines{$tf_id}},
                            sprintf(
                                "$region_str|%s|%d|%d|%s|%.3f|%.1f|%s",
                                $row[2],
                                $row[3],
                                $row[4],
                                $row[5],
                                $row[6],
                                $row[7] * 100,
                                $row[8]
                            );
                    }

                    last;
                }
            }
        }
    }

    if ($results_dir) {
        #
        # Loop through the actual TF IDs fetched as we have not necessarily
        # passed in any TF IDs or a TF Set and even if so, the TFs retrieved
        # may be fewer than the number queried.
        #
        foreach my $tf_id (keys %found_tf_ids_hash) {
            my $hit_lines = $tf_hit_lines{$tf_id};

            if ($hit_lines) {
                my $fname = $tf_id;
                $fname =~ s/\//_/g;

                my $data_file = "$results_dir/$fname.data";

                if (open(FH, ">$data_file")) {
                    #
                    # Specific header format recognized by Datafile plugin
                    # of the Template Toolkit.
                    #
                    print FH
                        "region|chr|start|end|strand|score|rel_score|seq\n";

                    if ($hit_lines) {
                        @$hit_lines = sort _sort_hit_line @$hit_lines;

                        foreach my $hit_line (@$hit_lines) {
                            printf FH "$hit_line\n";
                        }
                    }

                    close FH;
                } else {
                    carp  "Error opening output TFBS details data file"
                        . " $data_file - $!\n";
                }
            }
        }
    }

    my $counts;
    if ($tf_ids_passed) {
        $counts = OPOSSUM::Analysis::Counts->new(
            -seq_ids    => [sort keys %sr_tfbs_count],
            -tf_ids     => \@passed_tf_ids,
            -counts     => \%sr_tfbs_count
        );
    } else {
        $counts = OPOSSUM::Analysis::Counts->new(
            -seq_ids    => [sort keys %sr_tfbs_count],
            -tf_ids     => [sort keys %found_tf_ids_hash],
            -counts     => \%sr_tfbs_count
        );
    }

    return $counts;
}

=head2 fetch_tfbss

 Title    : fetch_tfbss
 Usage    : $tfbss = $tfbsa->fetch_tfbss(
                -tf_ids             => $tf_ids,
                -threshold          => $threshold,
                -search_region_ids  => $sr_ids,
                -search_regions     => $search_regions
            );
 Function : Fetch TFBSs. Optionally limit to a given set of TFs, TFBS score
            threshold, search regions and/or search region IDs.
 Returns  : A listref of OPOSSUM::TFBS objects.
 Args	  : Optional named arguments:
            -tf_ids             => OPTIONAL TF ID or list ref of TF IDs
            -threshold          => OPTIONAL TFBS score threshold
                                   (range 0.0 - 1.0)
            -search_region_ids  => OPTIONAL search region ID or list ref
                                   of search region IDs. The search region
                                   IDs are essentially "bins" which allow
                                   for MUCH faster retrieval than just
                                   using search regions.
            -search_regions     => OPTIONAL OPOSSUM::SearchRegion or list
                                   ref of OPOSSUM::SearchRegion objects.
                                   Just using search regions is extremely
                                   slow. It is a good idea to use search
                                   region IDs of the precomputed search
                                   regions to rapidly retrieve TFBSs and
                                   then the actual search regions just
                                   further refine the search.

=cut

sub fetch_tfbss
{
    my ($self, %args) = @_;

    my $tf_ids          = $args{-tf_ids};
    my $threshold       = $args{-threshold};
    my $sr_ids          = $args{-search_region_ids};
    my $search_regions  = $args{-search_regions};

    my $sql = "select search_region_id, tf_id, chrom, start, end, strand,"
            . " score, rel_score, seq from tfbss";

    my $where;

    my $ref = ref $tf_ids;
    if (defined $tf_ids
        && (!$ref || ($ref eq 'ARRAY' && $tf_ids->[0]))
    ) {
        if ($ref eq 'ARRAY') {
            if ($tf_ids->[0]) {
                $where .= " tf_id in ('";
                $where .= join("','", @$tf_ids);
                $where .= "')";
            }
        } else {
            $where .= " tf_id = '$tf_ids'";
        }
    }

    if ($threshold) {
        $where .= " and" if $where;
        if ($threshold =~ /(.+)%$/) {
            $threshold = $1 / 100;
        }
            
        $where .= " rel_score >= $threshold";
    }

    $ref = ref $sr_ids;
    if (defined $sr_ids
        && (!$ref || ($ref eq 'ARRAY' && $sr_ids->[0]))
    ) {
        $where .= " and" if $where;

        if ($ref eq 'ARRAY') {
            if ($sr_ids->[0]) {
                $where .= " search_region_id in (";
                $where .= join ',', @$sr_ids;
                $where .= ")";
            }
        } else {
            $where .= " search_region_id = $sr_ids";
        }
    }

    $ref = ref $search_regions;
    if (defined $search_regions
        && (!$ref || ($ref eq 'ARRAY' && $search_regions->[0]))
    ) {
        $where .= " and" if $where;

        if ($ref eq 'ARRAY') {
            if ($search_regions->[0]) {
                my $first_sr = 1;
                foreach my $sr (@$search_regions) {
                    my $sr_chrom = $sr->chrom;
                    my $sr_start = $sr->start;
                    my $sr_end   = $sr->end;
                    if ($first_sr) {
                        #
                        # TFBS must be completely contained in search region
                        # (not just overlapping)
                        #
                        $where .= " ((chrom = '$sr_chrom'"
                                . " and start >= $sr_start"
                                . " and end <= $sr_end)";
                        $first_sr = 0;
                    } else {
                        $where .= " or (chrom = '$sr_chrom'"
                                . " and start >= $sr_start"
                                . " and end <= $sr_end)";
                    }
                }

                unless ($first_sr) {
                    $where .= ")";
                }
            }
        } else {
            my $sr_chrom = $search_regions->chrom;
            my $sr_start = $search_regions->start;
            my $sr_end   = $search_regions->end;
            $where .= " (chrom = '$sr_chrom' and start >= $sr_start"
                    . " and end <= $sr_end)";
        }
    }

    $sql .= " where $where" if $where;

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch TFBSs with:\n$sql\n"
            . $self->errstr . "\n";
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch TFBSs with:\n$sql\n"
            . $self->errstr . "\n";
        return;
    }

    my @tfbss;
    while (my @row = $sth->fetchrow_array) {
        push @tfbss, OPOSSUM::TFBS->new(
            -search_region_id   => $row[0],
            -tf_id              => $row[1],
            -chrom              => $row[2],
            -start              => $row[3],
            -end                => $row[4],
            -strand             => $row[5],
            -score              => $row[6],
            -rel_score          => $row[7],
            -seq                => $row[8]
        );
    }


    return @tfbss ? \@tfbss : undef;
}

=head2 fetch_tfbs_counts_old

 This is the version of fetch_tfbs_counts before the SQL query was split up
 to use multiple queries (one for each pre-computed search region) rather
 then using a giant 'in' clause to search for all regions simultaneously.
 Testing, the 'in' clause query this was much slower (~50 secs vs. ~10 secs
 for ~1300 search regions).

 Title    : fetch_tfbs_counts_old
 Usage    : $counts = $tfbsa->fetch_tfbs_counts_old(
                -tf_ids             => $tf_ids,
                -tf_set             => $tf_set,
                -threshold          => $threshold,
                -search_region_ids  => $sr_ids,
                -search_region_map  => $search_region_map,
                -results_dir        => $results_dir,
                -logger             => $logger
            );
 Function : Fetch counts of the number of binding sites. Optionally limit
            to a given set of TFs, TFBS score threshold and search regions.
 Returns  : A listref of OPOSSUM::TFBSCount objects.
 Args	  : -tf_ids             => OPTIONAL TF ID or list ref of TF IDs.
            -tf_set             => OPTIONAL OPOSSUM::TFSet object (TF IDs
                                   take precedent over TF set).
            -threshold          => OPTIONAL TFBS score threshold
                                   (range 0.0 - 1.0).
            -search_region_ids  => OPTIONAL search region ID or list ref
                                   of search region IDs. The search region
                                   IDs should be the IDs of the pre-computed
                                   search region and are essentially "bins"
                                   which allow for MUCH faster retrieval of
                                   TFBSs than using search region postions.
            -search_region_map  => A hash which maps the actual search
                                   regions to the pre-computed search region
                                   IDs, i.e. the hash keys are the
                                   pre-computed search region IDs
                                   and the elements are listrefs of
                                   OPOSSUM::SearchRegion objects.
            -results_dir        => OPTIONAL directory path into which are
                                   written the TFBS details in a data format
                                   which is specific to the Template Toolkit
                                   Datafile plugin
                                   (see Template::Manual::Plugins). These
                                   datafile may be used later to format
                                   the TFBS details in both simple text and
                                   HTML format. This functionality also
                                   requires specific TFs to be passed either
                                   by the -tf_set or -tf_ids arguments.
            -logger             => OPTIONAL for debugging purposes. If a 
                                   Log::Log4perl logger object is provided,
                                   log DEBUG/INFO messages.

=cut

sub fetch_tfbs_counts_old
{
    my ($self, %args) = @_;

    my $tf_set              = $args{-tf_set};
    my $tf_ids              = $args{-tf_ids};
    my $threshold           = $args{-threshold};
    my $pc_sr_ids           = $args{-search_region_ids};
    my $search_region_map   = $args{-search_region_map};
    my $results_dir         = $args{-results_dir};
    #my $logger              = $args{-logger};

    unless ($search_region_map) {
        carp "No search region map provided\n";
        return;
    }

    unless ($tf_ids) {
        $tf_ids = $tf_set->ids if $tf_set;
    }

    my $sql = "select search_region_id, tf_id, chrom, start, end, strand,"
            . " score, rel_score, seq from tfbss";

    my $where;

    if ($threshold) {
        $where .= " and" if $where;

        if ($threshold =~ /(.+)%$/) {
            $threshold = $1 / 100;
        }
            
        $where .= " rel_score >= $threshold";
    }

    my $ref = ref $pc_sr_ids;
    if (defined $pc_sr_ids
        && (!$ref || ($ref eq 'ARRAY' && $pc_sr_ids->[0]))
    ) {
        $where .= " and" if $where;

        if ($ref eq 'ARRAY') {
            if ($pc_sr_ids->[0]) {
                $where .= " search_region_id in (";
                $where .= join ',', @$pc_sr_ids;
                $where .= ")";
            }
        } else {
            $where .= " search_region_id = $pc_sr_ids";
        }
    }

    $ref = ref $tf_ids;
    if (defined $tf_ids
        && (!$ref || ($ref eq 'ARRAY' && $tf_ids->[0]))
    ) {
        $where .= " and" if $where;

        if ($ref eq 'ARRAY') {
            if ($tf_ids->[0]) {
                $where .= " tf_id in ('";
                $where .= join("','", @$tf_ids);
                $where .= "')";
            }
        } else {
            $where .= " tf_id = '$tf_ids'";
        }
    }

    $sql .= " where $where" if $where;

    #$logger->info("fetch_tfbs_counts SQL:\n$sql\n");

    #
    # Don't use extra memory/time sorting in SQL as chromosome sorting is
    # not correct and we need to resort anyway.
    #
    #$sql .= " order by chrom, start, end";

    my $sth = $self->prepare($sql);
    unless ($sth) {
        carp "Error preparing fetch TFBSs with:\n$sql\n"
            . $self->errstr . "\n";
        return;
    }

    unless ($sth->execute) {
        carp "Error executing fetch TFBSs with:\n$sql\n"
            . $self->errstr . "\n";
        return;
    }

    my %sr_tfbs_count;
    my %tf_hit_lines;
    while (my @row = $sth->fetchrow_array) {
        #
        # Get actual search regions corresponding to this pre-computed search
        # region ID.
        #
        my $search_regions = $search_region_map->{$row[0]};

        #
        # Loop through actual search regions to see which one the TFBS
        # falls into.
        #
        foreach my $sr (@$search_regions) {
            if ($row[3] >= $sr->start && $row[4] <= $sr->end) {
                #
                # Increment count for this TF in this search region.
                #
                $sr_tfbs_count{$sr->id}->{$row[1]}++;

                #
                # Write binding site details to file
                #
                # Actually, don't write. Store lines by TF for sorting
                # before writing out to file.
                #
                if ($results_dir) {
                    my $region_str = sprintf "chr%s:%d-%d",
                        $sr->chrom,
                        $sr->start,
                        $sr->end;

                    push @{$tf_hit_lines{$row[1]}},
                        sprintf(
                            "$region_str|%s|%d|%d|%s|%.3f|%.1f|%s",
                            $row[2],
                            $row[3],
                            $row[4],
                            $row[5],
                            $row[6],
                            $row[7] * 100,
                            $row[8]
                        );
                }

                last;
            }
        }
    }

    if ($results_dir) {
        foreach my $tf_id (@$tf_ids) {
            my $fname = $tf_id;
            $fname =~ s/\//_/g;

            my $data_file = "$results_dir/$fname.data";

            if (open(FH, ">$data_file")) {
                #
                # Specific header format recognized by Datafile plugin of the
                # Template Toolkit.
                #
                print FH "region|chr|start|end|strand|score|rel_score|seq\n";

                my $hit_lines = $tf_hit_lines{$tf_id};

                if ($hit_lines) {
                    @$hit_lines = sort _sort_hit_line @$hit_lines;

                    foreach my $hit_line (@$hit_lines) {
                        printf FH "$hit_line\n";
                    }
                }

                close FH;
            } else {
                carp  "Error opening output TFBS details data file"
                    . " $data_file - $!\n";
            }
        }
    }

    my $counts = OPOSSUM::Analysis::Counts->new(
        -seq_ids    => [sort keys %sr_tfbs_count],
        -tf_ids     => $tf_ids,
        -counts     => \%sr_tfbs_count
    );

    return $counts;
}

sub fetch_tfbs_counts_older
{
    my ($self, %args) = @_;

    my $tf_ids          = $args{-tf_ids};
    my $threshold       = $args{-threshold};
    my $sr_ids          = $args{-search_region_ids};
    my $search_regions  = $args{-search_regions};

    unless ($search_regions) {
        carp "No search regions provided to fetch_tfbs_counts\n";
        return;
    }

    my $sql = "select tf_id, chrom, start, end from tfbss";

    my $where;

    my $ref = ref $tf_ids;
    if (defined $tf_ids
        && (!$ref || ($ref eq 'ARRAY' && $tf_ids->[0]))
    ) {
        if ($ref eq 'ARRAY') {
            if ($tf_ids->[0]) {
                $where .= " tf_id in ('";
                $where .= join("','", @$tf_ids);
                $where .= "')";
            }
        } else {
            $where .= " tf_id = '$tf_ids'";
        }
    }

    if ($threshold) {
        $where .= " and" if $where;
        if ($threshold =~ /(.+)%$/) {
            $threshold = $1 / 100;
        }
            
        $where .= " rel_score >= $threshold";
    }

    $ref = ref $sr_ids;
    if (defined $sr_ids
        && (!$ref || ($ref eq 'ARRAY' && $sr_ids->[0]))
    ) {
        $where .= " and" if $where;

        if ($ref eq 'ARRAY') {
            if ($sr_ids->[0]) {
                $where .= " search_region_id in (";
                $where .= join ',', @$sr_ids;
                $where .= ")";
            }
        } else {
            $where .= " search_region_id = $sr_ids";
        }
    }

    $sql .= " where $where";

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing fetch TF site count with:\n$sql\n"
            . $self->errstr;
        return;
    }

    if (!$sth->execute) {
        carp "Error executing fetch TF site counts with:\n$sql\n"
            . $self->errstr;
        return;
    }

    my %chrom_search_regions;
    if (ref $search_regions eq 'ARRAY') {
        foreach my $sr (@$search_regions) {
            push @{$chrom_search_regions{$sr->chrom}}, $sr;
        }
    } else {
        push @{$chrom_search_regions{$search_regions->chrom}},
            $search_regions;
    }

    my %sr_tfbs_count;
    while (my @row = $sth->fetchrow_array) {
        my $tf_id = $row[0];
        my $chrom = $row[1];
        my $start = $row[2];
        my $end   = $row[3];

        my $chrom_srs = $chrom_search_regions{$chrom};
        foreach my $sr (@$chrom_srs) {
            if ($start >= $sr->start && $end <= $sr->end) {
                $sr_tfbs_count{$sr->id}->{$tf_id}++;
                last;
            }
        }
    }

    my $counts = OPOSSUM::Analysis::Counts->new();
    foreach my $sr_id (keys %sr_tfbs_count) {
        foreach my $tf_id (keys %{$sr_tfbs_count{$sr_id}}) {
            $counts->seq_tfbs_count(
                $sr_id, $tf_id, $sr_tfbs_count{$sr_id}->{$tf_id}
            );
        }
    }

    return $counts;
}

=head2 store

 Title   : store
 Usage   : $tfbsa->store($tfbs);
 Function: Store TFBS in the database.
 Args    : An OPOSSUM::TFBS object
 Returns : True on success, false otherwise.

=cut

sub store
{
    my ($self, $tfbs) = @_;

    return if !$tfbs;

    if (!ref $tfbs || !$tfbs->isa("OPOSSUM::TFBS")) {
        carp "Not an OPOSSUM::TFBS object\n";
        return;
    }

    my $sql = qq{
        insert into tfbss (
		    tf_id,
            search_region_id,
            chrom,
		    start,
		    end,
		    strand,
		    score,
		    rel_score,
		    seq)
		values (?,?,?,?,?,?,?,?,?)
    };

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing insert TFBS statement\n"
            . $self->errstr . "\n";
        return;
    }

    if (
        !$sth->execute(
            $tfbs->id,
            $tfbs->search_region_id,
            $tfbs->chrom,
            $tfbs->start,
            $tfbs->end,
            $tfbs->strand,
            $tfbs->score,
            $tfbs->rel_score,
            $tfbs->seq
        )
    ) {
        carp "Error inserting TFBS\n";
        return 0;
    }

    return 1;
}

=head2 store_list

 Title   : store_list
 Usage   : $tfbsa->store_list($tfbss);
 Function: Store TFBSs in the database.
 Args    : A listref of OPOSSUM::TFBS objects
 Returns : True on success, false otherwise.

=cut

sub store_list
{
    my ($self, $tfbss) = @_;

    return if !$tfbss || !$tfbss->[0];

    my $sql = qq{insert into tfbss (
		    tf_id,
		    search_region_id,
            chrom,
		    start,
		    end,
		    strand,
		    score,
		    rel_score,
		    seq)
		values (?,?,?,?,?,?,?,?,?)};

    my $sth = $self->prepare($sql);
    if (!$sth) {
        carp "Error preparing insert TFBS statement\n"
            . $self->errstr . "\n";
        return;
    }

    my $ok = 1;
    foreach my $tfbs (@$tfbss) {
        if (
            !$sth->execute(
                $tfbs->id,
                $tfbs->search_region_id,
                $tfbs->chrom,
                $tfbs->start,
                $tfbs->end,
                $tfbs->strand,
                $tfbs->score,
                $tfbs->rel_score,
                $tfbs->seq
            )
        ) {
            carp "Error inserting TFBS\n";
            # keep trying to store TFBSs but return error status...
            $ok = 0;
        }
    }

    return $ok;
}

sub _sort_hit_line
{
    my ($chr1, $s1) = $a =~ /chr(\w+):(\d+)-\d+/;
    my ($chr2, $s2) = $b =~ /chr(\w+):(\d+)-\d+/;

    $chr1 = sprintf("%02d", $chr1) if $chr1 =~ /\d+/;
    $chr2 = sprintf("%02d", $chr2) if $chr2 =~ /\d+/;

    return $chr1 cmp $chr2 || $s1 <=> $s2;
}

1;
