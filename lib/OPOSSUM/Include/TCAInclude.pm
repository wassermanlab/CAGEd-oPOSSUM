=head1 NAME

 OPOSSUM::Include::TCAInclude.pm

=head1 SYNOPSIS


=head1 DESCRIPTION

  Contains all options and routines that are common to all the TFBS Cluster
  type scripts and modules.

=head1 AUTHOR

  Andrew Kwon
  Wasserman Lab
  Centre for Molecular Medicine and Therapeutics
  University of British Columbia

  E-mail: tjkwon@cmmt.ubc.ca

=cut

use strict;

use OPOSSUM::Opt::TCAOpt;
use OPOSSUM::Web::Opt::BaseOpt;

use lib TFBS_CLUSTER_LIB_PATH;

use TFBSCluster::DBSQL::DBAdaptor;


sub tfbs_cluster_db_connect
{
	my ($cl_db) = @_;
	
    my $dbh = TFBSCluster::DBSQL::DBAdaptor->new(
        -host     => TFBS_CLUSTER_DB_HOST,
        -dbname   => $cl_db || TFBS_CLUSTER_DB_NAME,
        -user     => TFBS_CLUSTER_DB_USER,
        -password => TFBS_CLUSTER_DB_PASS
    );

    return $dbh;
}

#
# Added options to select only those clusters / TFs with given TF IDs, min. IC
# DJA 2016/4/13
#
sub fetch_tf_cluster_set
{
    my ($cdb, $job_args) = @_;

    my $tfca = $cdb->get_TFClusterAdaptor;
    return undef unless $tfca;

    my %matrix_args;
    if ($job_args) {
        # Set cluster / TF fetch criteria from job args 
        # DJA 2016/4/13
        $matrix_args{-tf_ids} = $job_args->{-tf_ids} if $job_args->{-tf_ids};
        $matrix_args{-min_ic} = $job_args->{-min_ic} if $job_args->{-min_ic};

        # Currently clusters are not pre-grouped by class family so these
        # aren't used.
        # DJA 2016/4/13
        $matrix_args{-classes}  = $job_args->{-classes}
                if $job_args->{-classes};
        $matrix_args{-families} = $job_args->{-families}
                if $job_args->{-families};
    }

    #
    # This is not used for fetching clusters!
    # DJA 2016/4/13
    #unless ($matrix_args{-matrixtype}) {
    #    $matrix_args{-matrixtype} = 'PFM';
    #}
    
    my $clusters = $tfca->fetch(\%matrix_args);

    #print STDERR "# clusters = " . scalar(@$clusters) . "\n";
    my $cluster_set = TFBSCluster::TFClusterSet->new();
    $cluster_set->add_tf_cluster_list($clusters);

    return $cluster_set;
}

#
# Given a search region to individual TFBS mapping structure, create the
# corresponding search region to TFBS cluster mapping.
#
sub create_search_region_tfbs_cluster_map
{
    my ($sr_tfbs_map, $tf_cluster_set) = @_;

    my @sr_ids = keys %$sr_tfbs_map,

    my $cluster_ids = $tf_cluster_set->ids();

    my %sr_cluster_map;

    foreach my $sr_id (@sr_ids) {
        foreach my $cl_id (@$cluster_ids) {
            my $cluster = $tf_cluster_set->get_tf_cluster($cl_id);
            my $cluster_tf_ids = $cluster->tf_ids();

            #my $cluster_siteset = TFBS::SiteSet->new();
            my @sr_cluster_tfbs;
            foreach my $tf_id (@$cluster_tf_ids) {
                my $sr_tfbs = $sr_tfbs_map->{$sr_id}->{$tf_id};

                if ($sr_tfbs && $sr_tfbs->[0]) {
                    push @sr_cluster_tfbs, @$sr_tfbs;
                }
            }

            # XXX check, do we need to set the TFBS ID to the cluster ID
            # or is this done by the merge_cluster_ctfbs_sites routine?
            my $merged_tfbs;
            if (@sr_cluster_tfbs && $sr_cluster_tfbs[0]) {
                $merged_tfbs = merge_cluster_ctfbs_sites(
                    \@sr_cluster_tfbs, $cl_id
                );
            }

            if ($merged_tfbs and scalar(@$merged_tfbs) > 0) {
                # XXX
                # Note the sr_id and cl_id keys are in the opposite order
                # from what was previously done in the oPOSSUM3
                # tf_cluster_set_search_seqs routine to be consistent with
                # the sr_tfbs_map.
                $sr_cluster_map{$sr_id}->{$cl_id} = $merged_tfbs;
            }
        }
    }

    return %sr_cluster_map ? \%sr_cluster_map : undef;
}


# tfsites belong to 1 cluster only
# returns listref of OPOSSUM::ConservedTFBS objects
sub merge_cluster_ctfbs_sites
{
    my ($ctfbss, $cluster_id) = @_;
    
    return if !$ctfbss or @$ctfbss == 0;

    #
    # The code below will only work if the incoming TFBSs are not already sorted
    # DJA 2012/11/01
    #
    @$ctfbss = sort {$a->start <=> $b->start} @$ctfbss;

	my $prev_site = $ctfbss->[0];
    $prev_site->id($cluster_id);
    
    #
    # Let's not mess around setting and resetting strand info. Strand is
    # meaningless for clusters. Just keep everything on the +ve strand.
    # DJA 2012/11/02
    #
    if ($prev_site->strand == -1) {
        $prev_site->strand(1);
        $prev_site->seq(revcom($prev_site->seq));
    }

    my @merged_sites;
	push @merged_sites, $prev_site;
    
	for (my $i = 0; $i < scalar @$ctfbss; $i++) {
		my $curr_site = $ctfbss->[$i];

        $curr_site->id($cluster_id);

        if ($curr_site->strand == -1) {
            $curr_site->strand(1);
            $curr_site->seq(revcom($curr_site->seq));
        }

        my $prev_site = $merged_sites[$#merged_sites];
        
        # if overlap (or adjacent - DJA), keep the max score
        # merge the two sites
		if (overlap($prev_site, $curr_site, 1)) {
			if ($prev_site->end < $curr_site->end) {
                # merge the sequences
				my $ext_seq = substr(
                    $curr_site->seq, $prev_site->end - $curr_site->start + 1
                );
				
                if ($ext_seq) {
                    $prev_site->seq($prev_site->seq . $ext_seq);
                }

				$prev_site->end($curr_site->end);
            }

			if ($curr_site->score > $prev_site->score) {
				$prev_site->score($curr_site->score);
			}

			if ($curr_site->rel_score > $prev_site->rel_score) {
				$prev_site->rel_score($curr_site->rel_score);
			}

        } else {
            $curr_site->id($cluster_id);
			push @merged_sites, $curr_site;
        }
    }
    
	return @merged_sites ? \@merged_sites : undef;
}


# tfsites belong to 1 cluster only
sub merge_cluster_tfbs_siteset
{
    my ($tfsiteset, $cluster_id, $seq_id) = @_;
    
    return if !$tfsiteset or $tfsiteset->size == 0;
	
	my @sites = $tfsiteset->all_sites;
	my $ctfbss = tfbss_to_conserved_tfbss(\@sites, $cluster_id, $seq_id);

	return merge_cluster_ctfbs_sites($ctfbss, $cluster_id);
}

#
# Re-wrote this to simplify and also check for adjacent sites (we want to
# merge adjacent sites in clusters).
# DJA 2012/11/02
#
sub overlap
{
    my ($tf1, $tf2, $adjacent_ok) = @_;
    
    if ($adjacent_ok) {
        #
        # Sites can also be directly adjacent to one another
        #
        if ($tf1->start <= ($tf2->end + 1) && $tf1->end >= ($tf2->start - 1)) {
            return 1;
        }
    } else {
        #
        # The sites must overlap by at least 1 bp
        #
        if ($tf1->start <= $tf2->end && $tf1->end >= $tf2->start) {
            return 1;
        }
    }

    return 0;
}

#
# From the search region to TFBS cluster map count the number binding site
# clusters and store them in an OPOSSUM::Analysis::Cluster::Counts object.
#
sub compute_counts_from_search_region_tfbs_cluster_map
{
    my ($sr_tf_cluster_map, $tf_cluster_set) = @_;

    my $cl_ids = $tf_cluster_set->ids();
    my @sr_ids = sort keys %$sr_tf_cluster_map;

    #
    # Set the search regions TFBS cluster counts. The search region TFBS
    # clustermap may not contain any TFBS clusters for a given TF so this
    # also makes sure these are set (to 0), i.e. the counts for a given TF
    # cluster ID are set based on what was searched (the TF cluster set) rather
    # than what was found (the search regions to TFBS cluster map).
    #
    my %sr_tf_cluster_count;
    my %sr_tf_cluster_length;
    foreach my $sr_id (@sr_ids) {
        foreach my $cl_id (@$cl_ids) {
            my $sites = $sr_tf_cluster_map->{$sr_id}->{$cl_id};

            if ($sites) {
                $sr_tf_cluster_count{$sr_id}->{$cl_id} = scalar @$sites;

                my $length = 0;
                foreach my $site (@$sites) {
                    $length += length($site->seq);
                }
                $sr_tf_cluster_length{$sr_id}->{$cl_id} = $length;
            } else {
                $sr_tf_cluster_count{$sr_id}->{$cl_id} = 0;
                $sr_tf_cluster_length{$sr_id}->{$cl_id} = 0;
            }
        }
    }

    my $counts = OPOSSUM::Analysis::Cluster::Counts->new(
        -seq_ids        => \@sr_ids,
        -cluster_ids    => $cl_ids,
        -counts         => \%sr_tf_cluster_count,
        -lengths        => \%sr_tf_cluster_length
    );

    return $counts;
}


1;
