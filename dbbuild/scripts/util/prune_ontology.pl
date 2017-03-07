#!/usr/bin/env perl

=head1 SYNOPSIS

  prune_ontology.pl -s <species> -f input_obo_file -h out_ontology.html
    [-m missing_ontology.txt]

=head1 DESCRIPTION

 
  Parse the input FANTOM5 Sample Ontology. Build a pruned tree which only
  includes nodes starting at the level below "FF:0000102 - sample by type"
  (i.e. "FF:0000004 - tissue sample", "FF:0000003 - cell line sample" and
  "FF:0000002 - in vivo cell sample") and with all branches removed with
  leaf terms which are NOT in the FANTOM5 oPOSSUM DB for the given species.
 
  Output the pruned ontology tree in HTML format for use in the FANTOM5-oPOSSUM
  web application (which is loaded by jstree).
 
  Update 2014/12/1
  Latest OBO file used was ff-phase2-140729.obo.txt (29-Jul-2014)
  downloaded from http://fantom.gsc.riken.jp/5/datafiles/latest/extra/Ontology
 
  The file was edited to add a default-namespace line as the Bio::OntologyIO
  module threw an exception with this missing (it doesn't seem to matter what
  value this is set to).
 
  The file was also edited the change the name of the top level FANTOM5 term
  (FF:0000001) from just 'sample' to 'FANTOM5 Sample'. Actually this wasn't
  necessary as the script overrides and ouputs 'FANTOM5 Sample Ontology'
  as the name of this term. See comment in the code below.
 
  Command(s):
 
  Human
    prune_ontology.pl
        -s human
        -f ../../data/20141021/ontology/ff-phase2-140729.obo.txt
        -h sample_ontology_human.html
        -m sample_ontology_human.missing.txt
 
  Mouse
    prune_ontology.pl
        -s mouse
        -f ../../data/20141021/ontology/ff-phase2-140729.obo.txt
        -h sample_ontology_mouse.html
        -m sample_ontology_mouse.missing.txt
 
  These were manually post-processed to remove the leading 'FF:' from the
  ontology IDs.
 
  These files were renamed/copied under /devel/FANTOM5_oPOSSUM/htdocs/templates
  as sample_ontology_human.html and sample_ontology_mosue.html.

=head1 AUTHOR

David Arenillas
Wasserman Lab
Centre for Molecular Medicine and Therapeutics
University of British Columbia

E-mail: dave@cmmt.ubc.ca

=cut


use strict;
use warnings;

use lib '/apps/CAGEd_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Bio::OntologyIO;
use OPOSSUM::Include::ExperimentInclude;

my $f5_sstar_base_url = 'http://fantom.gsc.riken.jp/5/sstar/';

my $species;
my $obo_file;
#my $out_file;
my $html_file;
my $missing_file;
GetOptions(
    's=s'   => \$species,
    'f=s'   => \$obo_file,
    #'o=s'   => \$out_file,
    'h=s'   => \$html_file,
    'm=s'   => \$missing_file
);

unless ($species) {
    pod2usage(
        -msg        => "No species specified\n",
        -verbose    => 1 
    );
}

unless ($obo_file) {
    pod2usage(
        -msg        => "No input OBO file specified\n",
        -verbose    => 1 
    );
}

#unless ($out_file) {
#    pod2usage(
#        -msg        => "No output ontology tree file specified\n",
#        -verbose    => 1 
#    );
#}

my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);

my $opdba = opossum_db_connect($species)
    || die "Could not connect to FANTOM5 oPOSSUM database $db_name\n";

my $expa = $opdba->get_ExperimentAdaptor
    || die "Could not get ExperimentAdaptor\n";

#my $ff_ids = ['FF:11850-124I5','FF:11851-124I6','FF:11853-124I8'];
#my $ff_ids = ['FF:11851-124I6'];
my $ff_ids = $expa->fetch_ff_ids;
unless ($ff_ids) {
    die "Error fetching FF Ontology IDs from FANTOM5 oPOSSUM DB\n";
}

my %ff_id_key;
foreach my $ff_id (@$ff_ids) {
    $ff_id_key{"FF:$ff_id"} = 1;
}

my $ontIO = Bio::OntologyIO->new(
    -format     => "obo",
    -file       => "$obo_file"
);

unless ($ontIO) {
    die "Error opening FANTOM5 OBO file $obo_file\n";
}

my $IS_A = Bio::Ontology::RelationshipType->get_instance("IS_A");

my @leaf_terms;
my $sbt_tree;
my $ems_tree;
while (my $ont = $ontIO->next_ontology()) {
    my $ont_name = $ont->name();
    #print "\nOntology name: $ont_name\n";

    #
    # Was this a manual edit I made to the previous ontology file?
    # 2014/12/1 DJA
    #
    #if ($ont_name eq /FANTOM5/) {
    if ($ont_name =~ /^FANTOM/) {
        my @terms = $ont->get_root_terms();
        #@leaf_terms = $ont->get_leaf_terms();

        foreach my $term (@terms) {
            #
            # XXX
            # NOTE: the original root FANTOM5 ontology term (FF:0000001) in
            # the original file is 'sample'. I manually edited the file and
            # changed it to 'FANTOM5 Sample'. ALSO changed the is_a terms
            # for FF:0000102 ('sample by type') and FF:0000350 ('experimentally
            # modified') in a similar manner (although these phrases after the
            # '!' are probably just comments and not used by the parser.
            # Previously I called this 'FANTOM5 Sample Ontology'
            #
            # UPDATE: Actually none of this is necessary as in the output
            # section the name is overridden and 'FANTOM5 Sample Ontology'
            # is explicitly written.
            #
            # 2014/12/1 DJA
            #
            #if ($term->name eq 'FANTOM5 Sample Ontology') {
            #if ($term->name =~ /^FANTOM5 Sample/) {
            if ($term->name eq 'sample') {
                my @f5_terms = $ont->get_child_terms($term, $IS_A);
                foreach my $f5_term (@f5_terms) {
                    if ($f5_term->name eq 'sample by type') {
                        $sbt_tree = create_node($ont, $f5_term);
                    }
                    elsif ($f5_term->name eq 'experimentally modified sample')
                    {
                        $ems_tree = create_node($ont, $f5_term);
                    }
                }
            }
        }
    }
}

my $ont_tree = {
    -id     => 'FF:0000001',
    -name   => 'FANTOM5 Sample Ontology',
    -child  => {
        $sbt_tree->{-id} => $sbt_tree,
        $ems_tree->{-id} => $ems_tree
    }
};

#open(OFH, ">$out_file")
#    || die "Error opening output ontology tree file $out_file\n";

#print OFH "Ontology tree:\n\n";
#write_ontology_tree(\*OFH, $ont_tree);

#my $leaves = get_all_leaf_nodes($ont_tree);
#print OFH "\n\nLeaves:\n\n";
#write_leaves(\*OFH, $leaves);

prune_tree($ont_tree, \%ff_id_key);
#print OFH "\n\nPruned tree:\n\n";
#write_ontology_tree(\*OFH, $ont_tree);

#my $pruned_leaves = get_all_leaf_nodes($ont_tree);
#print OFH "\n\nRemaining leaves:\n\n";
#write_leaves(\*OFH, $pruned_leaves);

#write_missing_ids($missing_file, $ff_ids, $pruned_leaves);

if ($html_file) {
    open(HFH, ">$html_file")
        || die "Error opening output ontology tree HTML file $html_file\n";
    write_ontology_tree_html(\*HFH, $ont_tree);
    close(HFH);
}

close(OFH);

exit;

sub create_node
{
    my ($ont, $term) = @_;

    return unless $term;

    my $node = {
        -id         => $term->identifier,
        -name       => $term->name,
        -parent     => undef,
        -child      => undef
    };

    my @child_terms = $ont->get_child_terms($term, $IS_A);

    if (@child_terms) {
        foreach my $cterm (@child_terms) {
            my $cnode = create_node($ont, $cterm);
            $cnode->{-parent} = $node;
            $node->{-child}->{$cnode->{-id}} = $cnode;
        }
    }

    return $node;
}

sub write_ontology_tree
{
    my ($fh, $tree) = @_;
    
    write_node($fh, $tree, "");
}

sub write_node
{
    my ($fh, $node, $prefix) = @_;

    return unless $node;

    printf $fh "$prefix%s => %s\n", $node->{-id}, $node->{-name};

    my $cnode = $node->{-child};

    return unless $cnode;

    foreach my $cid (
        sort {uc $cnode->{$a}->{-name} cmp uc $cnode->{$b}->{-name}}
        keys %$cnode
    ) {
        write_node($fh, $cnode->{$cid}, $prefix . "\t");
    }
}

sub write_leaves
{
    my ($fh, $leaves) = @_;

    foreach my $leaf (@$leaves) {
        printf $fh "%s - %s\n", $leaf->{-id}, $leaf->{-name};
    }
}

sub prune_tree
{
    my ($tree, $ff_id_key) = @_;

    my $leaves = get_all_leaf_nodes($tree);

    foreach my $leaf (@$leaves) {
        unless ($ff_id_key->{$leaf->{-id}}) {
            prune_node($leaf);
        }
    }
}

sub prune_node
{
    my ($node) = @_;

    return unless $node;

    my $node_id   = $node->{-id};
    my $node_name = $node->{-name};
    my $parent    = $node->{-parent};

    printf "Pruning node %s - %s\n", $node_id, $node_name;

    if ($parent) {
        $node->{-parent} = undef;

        #
        # Delete this node from the children of it's parent
        #
        my $children = $parent->{-child};
        my $child = $children->{$node_id} if $children;

        if ($children && $children->{$node_id}) {
            delete $children->{$node_id};
            undef $node;
        } else {
            #
            # Sanity check. Since this node has a parent the parent must
            # explicitly refer to this child.
            #
            die(
                sprintf(
                      "Error: parent node %s - %s of node %s - %s missing"
                    . " child reference to this node!\n",
                    $parent->{-id},
                    $parent->{-name},
                    $node_id,
                    $node_name
                )
            );
        }

        my $num_child = scalar keys %$children;
        unless ($num_child) {
            #
            # No more children. Prune the parent.
            #
            #$parent->{-child} = undef;
            prune_node($parent);
        }
    } else {
        #
        # This node doesn't have a parent, so just delete this node. This
        # should only happen if we've reached the root node which means we've
        # effectively deleted the entire tree.
        #
        undef $node;
    }
}

sub get_all_leaf_nodes
{
    my ($tree) = @_;

    my @leaf_nodes;
    
    get_leaf_node(\@leaf_nodes, $tree); 

    return \@leaf_nodes;
}

sub get_leaf_node
{
    my ($leaf_nodes, $node) = @_;

    my $children = $node->{-child};

    if ($children) {
        foreach my $cid (keys %$children) {
            my $cnode = $children->{$cid};
            get_leaf_node($leaf_nodes, $cnode); 
        }
    } else {
        push @$leaf_nodes, $node;
    }
}

sub write_missing_ids
{
    my ($missing_file, $ff_ids, $leaf_terms) = @_;

    open(MFH, ">$missing_file")
        || die "Error opening missing FF ontology term file $missing_file\n";

    printf MFH "Ontology leaf terms: %d\tDB FF ontology IDs: %d\n\n",
        scalar @$leaf_terms,
        scalar @$ff_ids;

    foreach my $ff_id (@$ff_ids) {
        my $found = 0;
        foreach my $leaf (@$leaf_terms) {
            if ($leaf->{-id} eq 'FF:' . $ff_id) {
                $found = 1;
                last;
            }
        }

        unless ($found) {
            printf MFH "DB FF ID $ff_id missing from ontology\n";
        }
    }

    print MFH "\n";

    foreach my $leaf (@$leaf_terms) {
        my $found = 0;
        foreach my $ff_id (@$ff_ids) {
            if ($leaf->{-id} eq 'FF:' . $ff_id) {
                $found = 1;
                last;
            }
        }

        unless ($found) {
            printf MFH "Ontology term %s missing from DB\n", $leaf->{-id};
        }
    }
    close(MFH);
}

sub write_ontology_tree_html
{
    my ($fh, $tree) = @_;
    
    my $prefix = "  ";

    print $fh '<ul>';
    write_node_html($fh, $tree, $prefix);
    print $fh "\n</ul>\n";
}

sub write_node_html
{
    my ($fh, $node, $prefix) = @_;

    return unless $node;

    my $ff_id = $node->{-id};

    #printf $fh "\n$prefix<li id=\"%s\"><a href=\"#\">%s</a>", $node->{-id}, $node->{-name};

    #
    # Added the URL to the FANTOM5 SSTAR page for this experiment
    # DJA 2015/01/27
    #
    my $url = $f5_sstar_base_url . $ff_id;
    printf $fh "\n$prefix<li id=\"%s\"><a href=\"$url\" target=\"_blank\">%s</a>", $ff_id, $node->{-name};

    my $cnode = $node->{-child};

    unless ($cnode) {
        print $fh '</li>';
        return;
    }

    my $prefix2 = $prefix . "  ";

    print $fh "\n$prefix2<ul>";
    foreach my $cid (
        sort {uc $cnode->{$a}->{-name} cmp uc $cnode->{$b}->{-name}}
        keys %$cnode)
    {
        write_node_html($fh, $cnode->{$cid}, $prefix2);
    }
    print $fh "\n$prefix2</ul>";
    print $fh "\n$prefix</li>";
}
