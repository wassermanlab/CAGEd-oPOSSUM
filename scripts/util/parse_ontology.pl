#!/usr/bin/env perl

use lib '/devel/FANTOM5_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Bio::OntologyIO;
use OPOSSUM::Include::ExperimentInclude;

my $species;
my $obo_file;
my $out_file;
my $missing_file;
GetOptions(
    's=s'   => \$species,
    'f=s'   => \$obo_file,
    'o=s'   => \$out_file,
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

unless ($out_file) {
    pod2usage(
        -msg        => "No output ontology tree file specified\n",
        -verbose    => 1 
    );
}

unless ($missing_file) {
    pod2usage(
        -msg        => "No missing FF ontology term file specified\n",
        -verbose    => 1 
    );
}

my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);

my $opdba = opossum_db_connect($species)
    || die "Could not connect to FANTOM5 oPOSSUM database $db_name\n";

my $expa = $opdba->get_ExperimentAdaptor
    || die "Could not get ExperimentAdaptor\n";

my $ff_ids = $expa->fetch_ff_ids;
unless ($ff_ids) {
    die "Error fetching FF Ontology IDs from FANTOM5 oPOSSUM DB\n";
}

my $ontIO = Bio::OntologyIO->new(
    -format     => "obo",
    -file       => "$obo_file"
);

unless ($ontIO) {
    die "Error opening FANTOM5 OBO file $obo_file\n";
}

my $IS_A = Bio::Ontology::RelationshipType->get_instance("IS_A");

open(OFH, ">$out_file")
    || die "Error opening output ontology tree file $out_file\n";

my @leaf_terms;
while (my $ont = $ontIO->next_ontology()) {
    my $ont_name = $ont->name();
    #print "\nOntology name: $ont_name\n";

    if ($ont_name eq 'FANTOM5') {
        my @terms = $ont->get_root_terms();
        @leaf_terms = $ont->get_leaf_terms();

        foreach my $term (@terms) {
            if ($term->name eq 'FANTOM5 Sample Ontology') {
                my @f5_terms = $ont->get_child_terms($term, $IS_A);
                foreach my $f5_term (@f5_terms) {
                    if ($f5_term->name eq 'sample by type') {
                        my @sbt_terms = $ont->get_child_terms($f5_term, $IS_A);
                        foreach my $sbt_term (@sbt_terms) {
                            print_child_terms($ont, $sbt_term, "");
                        }
                    }
                }
            }
        }
    }
}
close(OFH);

write_missing_ids($missing_file, $ff_ids, \@leaf_terms);

exit;

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
            if ($leaf->identifier eq 'FF:' . $ff_id) {
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
            if ($leaf->identifier eq 'FF:' . $ff_id) {
                $found = 1;
                last;
            }
        }

        unless ($found) {
            printf MFH "Ontology term %s missing from DB\n", $leaf->identifier;
        }
    }
    close(MFH);
}

sub print_child_terms
{
    my ($ont, $term, $prefix) = @_;

    return unless $term;

    printf OFH "%s%s: %s\n", $prefix, $term->identifier, $term->name;

    my @child_terms = $ont->get_child_terms($term, $IS_A);

    return unless @child_terms;

    foreach my $ct (@child_terms) {
        print_child_terms($ont, $ct, $prefix . "\t");
    }
}
