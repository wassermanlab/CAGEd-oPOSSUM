#
# oPOSSUM DB Access
#
# The species name is dynamically appended to OPOSSUM_DB_NAME for full
# oPOSSUM DB name, e.g. oPOSSUM3_human
#
use constant OPOSSUM_DB_HOST    => 'fantom.cmmt.ubc.ca';
use constant OPOSSUM_DB_NAME    => 'FANTOM5_oPOSSUM';
use constant OPOSSUM_DB_USER    => 'opossum_r';
use constant OPOSSUM_DB_PASS    => '';

#
# XXX
# Below commented out did not get included properly! No idea why. Defined
# these explicityl in the modules which use them.
#
# Used by OPOSSUM::Tools::SearchRegionTool to run BedTools
#
# BedTools executables
#
#use constant BT_MERGE_EXEC      => 'mergeBed';
#use constant BT_INTERSECT_EXEC  => 'intersectBed';
#
# Reference whole genome fasta files used to extract sequences based on
# regions defined in BED files.
#
#use constant HUMAN_REF_FASTA    => '/space/data/resources/fasta/hg19/hg19.fa';
#use constant MOUSE_REF_FASTA    => '/space/data/resources/fasta/mm9/mm9.fa';

#
# Used by OPOSSUM::Tools::BiasAway
#
#use constant BA_EXEC        => 'python2.7 /apps/BiasAway/BiasAway.py g';
#use constant BA_DFLT_FOLD   => 1;

#
# NOTE: The actual Ensembl species DB name is stored in the db_info record
# of the specific FANTOM5-oPOSSUM species DB. The Ensembl lib version has to
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
#
use constant RAND_BG_TSS_FOLD    => 10;

#
# Form selection values and default settings. These may need to be overriden 
# by specific oPOSSUM variants.
#
use constant DFLT_JASPAR_COLLECTION => 'CORE';
use constant DFLT_MIN_IC            => '8';
use constant DFLT_TFBS_THRESHOLD    => '85';
use constant DFLT_UPSTREAM_BP       => '1500';
use constant DFLT_DOWNSTREAM_BP     => '500';
use constant DFLT_RESULT_SORT_BY    => 'zscore';

#
# Gene ID types used in the tss_genes table. These should probably be defined
# in a table in the DB itself as in the standard oPOSSUM system...
#
use constant ENTREZ_GENE_ID_TYPE    => 1;
use constant UNIPROT_GENE_ID_TYPE   => 2;
use constant HGNC_GENE_ID_TYPE      => 3;

1;
