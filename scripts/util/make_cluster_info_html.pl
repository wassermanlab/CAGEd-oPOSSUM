#!/usr/bin/env perl5.14

use strict;
use warnings;

use lib '/devel/CAGEd_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Carp;

use Template;
use Log::Log4perl qw(get_logger :levels);
use Data::Dumper;

use TFBS::DB::JASPAR5;

#use TFBSCluster::DBSQL::DBAdaptor;
use OPOSSUM::Include::TCAInclude;
use OPOSSUM::Include::BaseInclude;

use constant DEBUG          => 0;
use constant HEADING        => 'TFBS Cluster Information';
use constant TITLE          => 'TFBS Cluster Information';
use constant BG_COLOR_CLASS => 'bgc_f5_exp';

my $results_dir;
my $tf_db;
my $cl_db;
my $log_file;
GetOptions(
    'd=s'       => \$results_dir,
    'tdb=s'     => \$tf_db,
    'cdb=s'     => \$cl_db,
    'l=s'       => \$log_file
);

die "No results directory specified\n" unless $results_dir;

$tf_db = JASPAR_DB_NAME if !$tf_db;
$cl_db = TFBS_CLUSTER_DB_NAME if !$cl_db;

#
# Connect to JASPAR and TFBS cluster databases
#
my $jdb = jaspar_db_connect($tf_db);
die "Could not connect to JASPAR database $tf_db\n" unless $jdb;

my $cldba = tfbs_cluster_db_connect();
die "Could not connect to TFBS cluster database $cl_db\n" unless $cldba;

my $tf_cluster_set = fetch_tf_cluster_set($cldba);
die "Could not fetch TF cluster set\n" unless $tf_cluster_set;

my $cluster_ids = $tf_cluster_set->ids();

foreach my $clid (@$cluster_ids) {
    my $cluster = $tf_cluster_set->get_tf_cluster($clid);

    write_tfbs_cluster_info_html($cluster);
}

exit;

sub write_tfbs_cluster_info_html
{
    my $tfc = shift;
	
	my $cid = $tfc->id;
	
	my @tfc_tfs;
	my %collections;
	my %tax_groups;
	my %classes;
	my %families;
	my %tf_ic;
	foreach my $tfid (@{$tfc->tf_ids}) {
		my $tf = $jdb->get_Matrix_by_ID($tfid);

        $tf = stringify_tf_attribute($tf, 'class');
        $tf = stringify_tf_attribute($tf, 'family');

		push @tfc_tfs, $tf;

		$collections{$tf->ID} = $tf->tag('collection');
		$tax_groups{$tf->ID} = $tf->tag('tax_group');
		$classes{$tf->ID} = $tf->class;
		$families{$tf->ID} = $tf->tag('family');

		$tf_ic{$tf->ID} = sprintf "%.2f", $tf->to_ICM->total_ic;
	}
	
	my $filename = $results_dir . "/c$cid" . "_info.html";
	open (FH, ">$filename") || fatal(
		"Could not create TFBS cluster info HTML file $filename"
	);
	
    my $vars = {
        abs_htdocs_path    => ABS_HTDOCS_PATH,
        rel_htdocs_path    => REL_HTDOCS_PATH,
        abs_cgi_bin_path   => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path   => REL_CGI_BIN_PATH,
        bg_color_class     => BG_COLOR_CLASS,
        title              => TITLE,
        heading            => HEADING,
        #section            => 'TFBS Cluster Information',
        version            => VERSION,
        devel_version      => DEVEL_VERSION,
		jaspar_url         => JASPAR_URL,
		tf_cluster         => $tfc,
		cluster_tfs        => \@tfc_tfs,
		collections        => \%collections,
		tax_groups         => \%tax_groups,
		classes            => \%classes,
		families           => \%families,
		tf_ic              => \%tf_ic,
        var_template       => "tfbs_cluster_info.html"
    };

    my $output = process_template('master.html', $vars);

    print FH $output;
	
	close (FH);
}
