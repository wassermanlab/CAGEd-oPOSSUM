#!/usr/bin/env perl

use lib '/devel/FANTOM5_oPOSSUM/lib';

use Getopt::Long;
use Pod::Usage;
use Bio::OntologyIO;
use Data::Dumper;

my $obo_file;
my $out_file;
GetOptions(
    'f=s'   => \$obo_file,
    'o=s'   => \$out_file,
);

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

my $db_name = sprintf("%s_%s", OPOSSUM_DB_NAME, $species);

my $ontIO = Bio::OntologyIO->new(
    -format     => "obo",
    -file       => "$obo_file"
);

unless ($ontIO) {
    die "Error opening FANTOM5 OBO file $obo_file\n";
}

my $IS_A = Bio::Ontology::RelationshipType->get_instance("IS_A");

open(OFH, ">$out_file")
    || die "Error opening output ontology tree dump file $out_file\n";

while (my $ont = $ontIO->next_ontology()) {
    my $ont_name = $ont->name();
    #print "\nOntology name: $ont_name\n";

    if ($ont_name eq 'FANTOM5') {
        printf OFH "FANTOM5 Ontology Dump:\n%s\n", Data::Dumper::Dumper($ont);
    }
}
close(OFH);

exit;
