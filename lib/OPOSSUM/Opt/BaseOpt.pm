#
# CAGEd-oPOSSUM DB Access
#
# NOTE: When either human or mouse analysis is chosen, the software
# automatically appends species name to the OPOSSUM_DB_NAME to dynamically
# generate the actual CAGEd-oPOSSUM DB name, e.g. CAGEd_oPOSSUM_human
#
use constant OPOSSUM_DB_HOST    => 'cagedop.cmmt.ubc.ca';
use constant OPOSSUM_DB_NAME    => 'CAGEd_oPOSSUM';
use constant OPOSSUM_DB_USER    => 'opossum_r';
use constant OPOSSUM_DB_PASS    => '';
use constant TFBS_CLUSTER_DB_NAME      => 'TFBS_cluster';

#
# XXX
# The definitions commented out below were not getting included properly!
# No idea why. So defined these explicitly in the modules which use them,
# e.g. lib/OPOSSUM/Tools/SearchRegionTool.pm. Please update these paths in
# those modules to your local paths where these are installed.
# This is not really ideal...
# XXX
#
# Used by OPOSSUM::Tools::SearchRegionTool to run BedTools
#
# BedTools executables
#
#use constant BT_MERGE_EXEC      => '/usr/local/bin/mergeBed';
#use constant BT_INTERSECT_EXEC  => '/usr/local/bin/intersectBed';
#use constant BT_GETFASTA_EXEC   => '/usr/local/bin/bedtools getfasta';
#
# Reference whole genome fasta files used to extract sequences based on
# regions defined in BED files.
#
#use constant HUMAN_REF_FASTA    => '/space/data/CAGEd_oPOSSUM/resources/fasta/hg19/hg19.fa';
#use constant MOUSE_REF_FASTA    => '/space/data/CAGEd_oPOSSUM/resources/fasta/mm9/mm9.fa';
#
#
# Used by OPOSSUM::Tools::BiasAway
#
#use constant BA_EXEC        => 'python2.7 /apps/BiasAway/BiasAway.py g';
#use constant BA_DFLT_FOLD   => 1;
#

use constant HUMAN_ASSEMBLY     => 'hg19';
use constant MOUSE_ASSEMBLY     => 'mm9';

#
# HOMER Settings
#
use constant HOMER_BIN_PATH     => '/apps/Homer/bin/';
#
# Files containing the permissive CAGE peak data, used by HOMER
# preparseGeneome.pl in creating background regions.
#
use constant HOMER_HUMAN_CAGE_PEAK_FILE =>
    '/devel/CAGEd_oPOSSUM/data/hg19.cage_peak_coord_permissive.txt';
use constant HOMER_MOUSE_CAGE_PEAK_FILE =>
    '/devel/CAGEd_oPOSSUM/data/mm9.cage_peak_coord_permissive.txt';
use constant HOMER_VERTEBRATES_KNOWN_MOTIFS_FILE => '/apps/Homer/data/knownTFs/vertebrates/known.motifs';

#
# NOTE: The actual Ensembl species DB name is stored in the db_info record
# of the specific CAGEd-oPOSSUM species DB. The Ensembl lib version has to
# be in sync with this Ensembl DB.
#
use constant ENSEMBL_LIB_PATH   => '/usr/local/src/ensembl-64/ensembl/modules';

use constant ENSEMBL_DB_HOST    => 'vm2.cmmt.ubc.ca';
use constant ENSEMBL_DB_USER    => 'ensembl_r';
use constant ENSEMBL_DB_PASS    => undef;


use constant MAX_TARGET_TSS     => 20000;
use constant MAX_BACKGROUND_TSS => 20000;

#
# For random background generation set the number of background CAGE peaks
# selected is equal to the number target CAGE peaks multiplied by this number.
# Currently this is not used
use constant RAND_BG_TSS_FOLD    => 10;

#
# Form selection values and default settings. These may need to be overriden 
# by specific oPOSSUM variants.
#
use constant DFLT_JASPAR_COLLECTION => 'CORE';
use constant DFLT_MIN_IC            => '8';
use constant DFLT_TFBS_THRESHOLD    => '85';
use constant DFLT_UPSTREAM_BP       => '500';
use constant DFLT_DOWNSTREAM_BP     => '500';
use constant DFLT_RESULT_SORT_BY    => 'fisher_p_value';

#
# Gene ID types used in the tss_genes table. These should probably be defined
# in a table in the DB itself as in the standard oPOSSUM system...
#
use constant ENTREZ_GENE_ID_TYPE    => 1;
use constant UNIPROT_GENE_ID_TYPE   => 2;
use constant HGNC_GENE_ID_TYPE      => 3;

1;
