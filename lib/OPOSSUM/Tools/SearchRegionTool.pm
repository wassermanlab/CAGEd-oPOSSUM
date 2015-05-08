=head1 NAME

OPOSSUM::Tools::SearchRegionTool - quick and dirty class to perform
search region merging and filtering (intersections) using bedools.

=head1 DESCRIPTION

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

package OPOSSUM::Tools::SearchRegionTool;

use strict;

use Carp;
use FileHandle;
use File::Temp qw/ tempfile /;
use File::Spec::Functions qw/ catfile /;
use Readonly;
use Bio::SeqIO;

use OPOSSUM::SearchRegion;

Readonly::Scalar my $DEBUG  => 1;

#
# XXX
# These were originally defined in OPOSSUM::Opt::BaseOpt but there seemed
# to be a problem with this file getting included properly. Perhaps it
# makes more sense to include these here as this could be a standalone tool
# although it is nicer to have all FANTOM5-oPOSSUM settings in one file.
# XXX
#
Readonly::Scalar my $BT_MERGE_EXEC      => '/usr/local/bin/mergeBed';
Readonly::Scalar my $BT_INTERSECT_EXEC  => '/usr/local/bin/intersectBed';
Readonly::Scalar my $BT_GETFASTA_EXEC   => '/usr/local/bin/bedtools getfasta';

Readonly::Scalar my $SPECIES_ASSEMBLY   => {
    'human' => 'hg19',
    'mouse' => 'mm9'
};

Readonly::Scalar my $ASSEMBLY_FASTA  => {
    'hg19'  => '/space/data/resources/fasta/hg19/hg19.fa',
    'mm9'   => '/space/data/resources/fasta/mm9/mm9.fa'
};

Readonly::Scalar my $ASSEMBLY_CHROM_LENGTH  => {
    'hg19' => {
        '1'  => 249250621,
        '2'  => 243199373,
        '3'  => 198022430,
        '4'  => 191154276,
        '5'  => 180915260,
        '6'  => 171115067,
        '7'  => 159138663,
        '8'  => 146364022,
        '9'  => 141213431,
        '10' => 135534747,
        '11' => 135006516,
        '12' => 133851895,
        '13' => 115169878,
        '14' => 107349540,
        '15' => 102531392,
        '16' => 90354753,
        '17' => 81195210,
        '18' => 78077248,
        '19' => 59128983,
        '20' => 63025520,
        '21' => 48129895,
        '22' => 51304566,
        'X'  => 155270560,
        'Y'  => 59373566,
        'M'  => 16571
    },
    'mm9'  => {
        '1'	 => 197195432,
        '2'	 => 181748087,
        '3'	 => 159599783,
        '4'  => 155630120,
        '5'  => 152537259,
        '6'  => 149517037,
        '7'  => 152524553,
        '8'  => 131738871,
        '9'  => 124076172,
        '10' => 129993255,
        '11' => 121843856,
        '12' => 121257530,
        '13' => 120284312,
        '14' => 125194864,
        '15' => 103494974,
        '16' => 98319150,
        '17' => 95272651,
        '18' => 90772031,
        '19' => 61342430,
        'X'  => 166650296,
        'Y'  => 15902555,
        'M'  => 16299
    }
};

=head2 new

 Title   : new
 Usage   : $srt = OPOSSUM::Tools::SearchRegionTool->new(
                -dir                => $directory,
                -species            => $species,
                -t_or_b             => $t_or_b
            );

 Function: Construct a new OPOSSUM::Tools::SearchRegionTool object with
           the given search regions and region type.
 Args    : -t_or_b
                String identifying data as belonging to 'target' or
                'background' set. It is used to prefix the various BED file
                names created with 't_' or 'b_' if explicit file names or
                file handles are not provided. Useful for debugging.
           -species
                String specifying the species, either 'human' or 'mouse'.
                This is required to determine the correct fasta reference
                sequence file to use.
           -dir
                OPTIONAL. If provided, uses this directory to create the
                working BED files. Otherwise TMPDIR is used.

 Returns : A new OPOSSUM::Tools::SearchRegionFilter object

=cut

sub new
{
    my ($class, %args) = @_;

    my $t_or_b = $args{-t_or_b};
    unless ($t_or_b) {
        carp "SearchRegionTool: 'target' or 'background' not specified!\n";
        return undef;
    }

    unless ($t_or_b eq 'target' || $t_or_b eq 'background') {
        carp "SearchRegionTool: -t_or_b should be 'target' or 'background'\n";
        return undef;
    }

    my $species = $args{-species};
    unless ($species) {
        carp "SearchRegionTool: -species not provided!\n";
        return undef;
    }

    unless ($species eq 'human' || $species eq 'mouse') {
        carp "SearchRegionTool: -species must be 'human' or 'mouse'\n";
        return undef;
    }

    my $self = bless {
        %args
    }, ref $class || $class;

    return $self;
}

=head2 compute_tss_search_regions

 Title   : compute_tss_search_regions
 Usage   : $srt = OPOSSUM::Tools::SearchRegionTool->compute_tss_search_regions(
                -tss                    => $tss_list,
                -upstream_bp            => $upstream_bp,
                -downstream_bp          => $downstream_bp,
                -filtering_regions_file => $filtering_regions_file
            );

 Function: Compute a list of search regions from a list of TSSs by applying
           the provided upstream/downstream flanks, merging any overlapping
           regions and filtering these regions by an optionally provided
           set of filtering regions. 

 Args    : -tss
                A list of OPOSSUM::TSS objects defining the CAGE peaks
                which are used to compute the search regions.
           -upstream_bp
                Amount of upstream flanking seuquence to apply to the CAGE
                peaks.
           -downstream_bp
                Amount of downstream flanking seuquence to apply to the CAGE
                peaks.
           -filtering_regions_file
                OPTIONAL. The name of a BED file file containing regions
                used to filter (intersect) with the search regions computed
                from the CAGE peaks.

 Returns : A new OPOSSUM::Tools::SearchRegionFilter object

=cut

sub compute_tss_search_regions
{
    my ($self, %args) = @_;

    my $tss_list                = $args{-tss};
    my $upstream_bp             = $args{-upstream_bp};
    my $downstream_bp           = $args{-downstream_bp};
    my $filtering_regions_file  = $args{-filtering_regions_file};

    my $t_or_b = $self->t_or_b();
    my $dir = $self->dir();

    unless ($tss_list && $tss_list->[0]) {
        carp "No $t_or_b TSSs passed to compute_tss_search_regions\n";
        return undef;
    }

    #
    # Set file prefix to 't' or 'b' depending on whether we are working
    # with target or background region files.
    #
    my $prefix = substr($t_or_b, 0, 1);

    my $initial_regions_file = catfile($dir, $prefix . '_initial_regions.bed');

    my $ok = $self->create_initial_tss_search_regions(
        -tss            => $tss_list,
        -upstream_bp    => $upstream_bp,
        -downstream_bp  => $downstream_bp,
        -filename       => $initial_regions_file
    );

    unless ($ok) {
        carp "Could not create $t_or_b initial search regions from TSSs\n";
        return undef;
    }

    $self->initial_regions_file($initial_regions_file);

    my $merged_regions_file  = catfile($dir, $prefix . '_merged_regions.bed');

    $ok = $self->merge_regions(
        -in_regions_file        => $initial_regions_file,
        -merged_regions_file    => $merged_regions_file,
        -has_region_id          => $self->has_region_id()
    );

    unless ($ok) {
        carp "Could not merge $t_or_b initial search regions\n";
        return undef;
    }

    $self->merged_regions_file($merged_regions_file);
    $self->final_regions_file($merged_regions_file);

    my $tss_search_regions;
    if ($filtering_regions_file) {
        $self->filtering_regions_file($filtering_regions_file);

        #
        # We cannot assume that the filtering regions are non-overlapping
        # (merged). We can EITHER sort/merge them first and then intersect
        # them with our merged regions from above OR intersect them with the
        # merged regions above first and then sort/merge the results. The
        # results are equivalent but with the former method there are
        # occasions where there are the odd region which is not in exact order.
        # This actually doesn't matter but may as well do it this way anyway.
        # NOTE: I didn't test to see if one was more time efficient.
        #
        my $initial_filtered_regions_file
            = catfile($dir, $prefix . '_initial_filtered_regions.bed');

        $ok = $self->filter_regions(
            -in_regions_file        => $merged_regions_file,
            -filtering_regions_file => $filtering_regions_file,
            -filtered_regions_file  => $initial_filtered_regions_file
        );

        unless ($ok) {
            carp "Could not create $t_or_b initial filtered regions file\n";
            return undef;
        }

        my $merged_filtered_regions_file
            = catfile($dir, $prefix . '_filtered_regions.bed');

        $ok = $self->merge_regions(
            -in_regions_file        => $initial_filtered_regions_file,
            -merged_regions_file    => $merged_filtered_regions_file,
            -has_region_id          => $self->has_region_id()
        );

        unless ($ok) {
            carp "Could not create $t_or_b final merged filtered regions file"
                . "\n";
            return undef;
        }

        $self->filtered_regions_file($merged_filtered_regions_file);
        $self->final_regions_file($merged_filtered_regions_file);

        $tss_search_regions = $self->read_bed(
            -filename => $merged_filtered_regions_file
        );
    } else {
        $tss_search_regions = $self->read_bed(
            -filename => $merged_regions_file
        );
    }

    #
    # Assign unique IDs to the final merged / filtered search regions.
    # These IDs are completely independent from the IDs of the pre-computed
    # search regions retrieved stored in the database.
    #
    # XXX
    # For future consideration, we could use chr:start-end as the ID
    # rather than a meaningless numeric ID.
    # XXX Do we even need this?
    #
    my $sr_id = 1;
    foreach my $sr (@$tss_search_regions) {
        $sr->id($sr_id++);
    }

    return $tss_search_regions;
}

=head2 create_initial_tss_search_regions

 Title   : create_initial_tss_search_regions
 Usage   : $srt->create_initial_tss_search_regions(
               -tss            => $tss_list,
               -upstream_bp    => $upstream_bp,
               -downstream_bp  => $downstream_bp,
               -fh             => $fh,
               -filename       => $filename
           );

 Function: Create the initial set of search regions from a list of TSSs
           by applying the provided upstream/downstream flanks. If a
           file name or file handle is also provided, write these regions
           to the specified file in BED format.

 Args    : -tss
                A list of OPOSSUM::TSS objects defining the CAGE peaks
                which are used to compute the search regions.
           -upstream_bp
                Amount of upstream flanking seuquence to apply to the CAGE
                peaks.
           -downstream_bp
                Amount of downstream flanking seuquence to apply to the CAGE
                peaks.
           -filtering_regions
                OPTIONAL. A listref of OPOSSUM::SearchRegion objects used to
                filter (intersect) with the search regions computed from
                the CAGE peaks.
           -filename
                OPTIONAL. Name of a file to which the regions are written.
           -fh
                OPTIONAL. A file handle to which the regions are written.

 Returns : True on success, false otherwise.

=cut
sub create_initial_tss_search_regions
{
    my ($self, %args) = @_;

    my $tss_list        = $args{-tss};
    my $upstream_bp     = $args{-upstream_bp};
    my $downstream_bp   = $args{-downstream_bp};
    my $fh              = $args{-fh};
    my $filename        = $args{-filename};

    unless ($tss_list && $tss_list->[0]) {
        carp "No TSS list provided to create_initial_tss_search_regions\n";
        return undef;
    }

    $upstream_bp = 0 unless defined $upstream_bp;
    $downstream_bp = 0 unless defined $downstream_bp;

    my $species = $self->species();
    unless ($species) {
        carp "create_initial_tss_search_regions: species not defined!\n";
        return undef;
    }

    my $assembly = $SPECIES_ASSEMBLY->{$species};
    unless ($assembly) {
        carp  "create_initial_tss_search_regions: could not determine"
            . " genome assembly for species '$species'!\n";
        return 0;
    }

    my $chrom_lengths = $ASSEMBLY_CHROM_LENGTH->{$assembly};
    unless ($chrom_lengths) {
        carp  "create_initial_tss_search_regions: could not chromosome lengths"
            . " for genome assembly '$assembly'!\n";
        return 0;
    }

    #
    # If the TSS is from FANTOM5 (i.e. it was fetched from the
    # FANTOM5-oPOSSUM DB, then it has a search region ID (the ID of the
    # pre-computed search region which contains it). If this is the case,
    # we want to preserve this search region ID by using the 4th (name)
    # column of all BED files to store it and supplying any necessary options
    # to the various BEDTools merge, intersect etc. operations so that this
    # column is retained in the resultant BED files. Set flag to indicate this.
    #
    my $tss1 = $tss_list->[0];
    if (defined $tss1->search_region_id) {
        $self->has_region_id(1);
    }

    my @regions;
    foreach my $tss (@$tss_list) {
        my $chrom  = $tss->chrom;
        my $start  = $tss->start;
        my $end    = $tss->end;
        my $strand = $tss->strand;

        $chrom =~ s/^chrom//;
        $chrom =~ s/^chr//;

        if ($strand eq '-') {
            $start = $start - $downstream_bp;
            $end   = $end + $upstream_bp;
        } else {
            $start = $start - $upstream_bp;
            $end   = $end + $downstream_bp;
        }

        my $chrom_end = $chrom_lengths->{$chrom};

        $start = 1 if $start < 1;
        $end = $chrom_end if $end > $chrom_end;

        my $sr = OPOSSUM::SearchRegion->new(
            -chrom      => $chrom,
            -start      => $start,
            -end        => $end,
        );

        if ($self->has_region_id()) {
            #
            # If this TSS (CAGE peak) came from FANTOM5 then it's search
            # region ID is the ID of the pre-computed search region within
            # which this TSS falls. These pre-computed search regions are
            # the maximum sized non-overlapping regions which were
            # pre-computed by applying the maximum upstream and downstream
            # flanks to the each of the CAGE peaks and then merging them all.
            # This any new region created will fall into one of these
            # pre-computed search regions. Preserve this pre-computed
            # search region information by setting it as the parent ID of
            # this search region as these IDs are used to much more rapidly
            # search the database by reducing the search space to these
            # parent regions. 
            #
            # This only applies to search regions derived from TSSs fetched
            # from the FANTOM5-oPOSSUM DB. The parent ID won't be set if the
            # TSSs were read from a custom (user supplied) BED file rather
            # than retrieved from the database. This is OK.
            #
            $sr->parent_id($tss->search_region_id);
        }

        push @regions, $sr;
    }

    #
    # If filename or file handle is provided also write the regions to a
    # BED file.
    #
    if ($fh) {
        $self->write_bed(-fh => $filename, -regions => \@regions);
    } elsif ($filename) {
        $self->write_bed(-filename => $filename, -regions => \@regions);
    }

    return @regions ? \@regions : undef;
}

=head2 merge_regions

 Title   : merge_regions
 Usage   : $srt->merge_regions(
               -in_regions_file        => $in_file,
               -merged_regions_file    => $merged_file
           );

 Function: Run BEDTools merge on the input search regions file to combine
           overlapping regions.

 Args    : An input regions file name and an output regions merged file
           name.
 Returns : True on success, false otherwise.

=cut

sub merge_regions
{
    my ($self, %args) = @_;

    my $in_file         = $args{-in_regions_file};
    my $merged_file     = $args{-merged_regions_file};
    my $has_region_id   = $args{-has_region_id};

    unless ($in_file) {
        carp "No input search regions file provided to merge_regions!\n";
        return 0;
    }

    unless ($merged_file) {
        carp "No output merged search regions file provided to"
            . " merge_regions!\n";
        return 0;
    }

    #my $dir = $self->dir();
    #if ($dir) {
    #    $in_file = catfile($dir, $in_file);
    #    $merged_file = catfile($dir, $merged_file);
    #}

    #
    # BEDTools merge (and possibly other operations) require the BED file to
    # be sorted.
    #
    my $in_file_sorted = "$in_file.sorted";
    my $cmd = "sort -k1,1 -k2,2n $in_file > $in_file_sorted";
    my $out = `exec 2>&1; $cmd`;
    my $status = $? >> 8;
    if ($status) {
        carp "merge_regions '$cmd' failed! Exited with status $status - $out\n";
        return 0;
    }

    #
    # Rename sorted file back to original input file name (overwriting
    # original file).
    #
    $cmd = "mv $in_file_sorted $in_file";
    $out = `exec 2>&1; $cmd`;
    $status = $? >> 8;
    if ($status) {
        carp "merge_regions '$cmd' failed! Exited with status $status - $out\n";
        return 0;
    }

    my $cmd;
    if ($has_region_id) {
        #
        # For FANTOM5 TSSs the 4th (name) column is used to store the
        # precomputed 'parent' region of the search regions and we want to
        # preserve this using the -c and -o options.
        #
        $cmd = "$BT_MERGE_EXEC -i $in_file -c 4 -o distinct > $merged_file";
    } else {
        #
        # The user entered TSSs do not have the name column and if we run
        # bedtools with the -o and -c options if throws an error.
        #
        $cmd = "$BT_MERGE_EXEC -i $in_file > $merged_file";
    }

    my $out = `exec 2>&1; $cmd`;
    my $status = $? >> 8;
    if ($status) {
        carp "merge_regions '$cmd' failed! Exited with status $status - $out\n";
        return 0;
    }

    return 1;
}

=head2 filter_regions

 Title   : filter_regions
 Usage   : $srt->filter_regions(
               -in_regions_file        => $in_file,
               -filtering_regions_file => $filtering_file,
               -filtered_regions_file  => $out_file
           );

 Function: Run BEDTools intersect using the input and filtering region files
           and write the intersection of the two sets of regions to the
           specified output file.

 Args    : An input regions file name, a filtering regions file and an
           output filtered regions file name.
 Returns : True on success, false otherwise.

=cut

sub filter_regions
{
    my ($self, %args) = @_;

    my $in_file         = $args{-in_regions_file};
    my $filtering_file  = $args{-filtering_regions_file};
    my $out_file        = $args{-filtered_regions_file};

    unless ($in_file) {
        carp "filter_regions: no input regions file name provided!\n";
        return 0;
    }

    unless ($filtering_file) {
        carp "filter_regions: no filtering regions file name provided!\n";
        return 0;
    }

    unless ($out_file) {
        carp "filter_regions: no output regions file name provided!\n";
        return 0;
    }

    #
    # If directory is set, ASSUME the full path is not included in
    # the filenames and prepend it.
    #
    #$in_file = catfile($self->dir, $in_file) if $self->dir;
    #$filtering_file = catfile($self->dir, $filtering_file) if $self->dir;
    #$out_file = catfile($self->dir, $out_file) if $self->dir;

    my $cmd = "$BT_INTERSECT_EXEC -a $in_file -b $filtering_file > $out_file";
    my $out = `exec 2>&1; $cmd`;
    my $status = $? >> 8;
    if ($status) {
        carp "filter_regions '$cmd' failed! Exited with status $status - $out\n";
        return 0;
    }

    return 1;
}

=head2 extract_search_region_sequences

 Title   : extract_search_region_sequences
 Usage   : $srt->extract_search_region_sequences(
               -regions_file    => $regions_file,
               -out_seq_file    => $seq_file
           );

 Function: Extract the actual sequences corresponding to the regions
           contained in the regions file (BED format). Write these
           sequences to the specified output file and also return them.

 Args    : An species name, input regions file name and an output sequence
           file name.
 Returns : True on success, false otherwise.

=cut

sub extract_search_region_sequences
{
    my ($self, %args) = @_;

    my $regions_file = $args{-regions_file};
    my $out_seq_file = $args{-out_seq_file};

    unless ($regions_file) {
        carp "extract_final_search_region_sequences: no input search regions"
            . " file provided\n";
        return 0;
    }

    unless ($out_seq_file) {
        carp "extract_final_search_region_sequences: no output sequence file"
            . " provided\n";
        return 0;
    }

    my $species = $self->species();
    unless ($species) {
        carp "extract_final_search_region_sequences: no species defined!\n";
        return 0;
    }

    my $assembly = $SPECIES_ASSEMBLY->{$species};
    unless ($assembly) {
        carp  "extract_final_search_region_sequences: could not determine"
            . " genome assembly for species '$species'!\n";
        return 0;
    }

    my $ref_fasta = $ASSEMBLY_FASTA->{$assembly};
    unless ($ref_fasta) {
        carp  "extract_final_search_region_sequences: could not determine"
            . " reference genome fasta file for assembly '$assembly'!\n";
        return 0;
    }

    #
    # If directory is set, ASSUME the full path is not included in
    # the filenames and prepend it.
    #
    #$regions_file = catfile($self->dir, $regions_file) if $self->dir;
    #$out_seq_file = catfile($self->dir, $out_seq_file) if $self->dir;

    my $cmd = "$BT_GETFASTA_EXEC -fi $ref_fasta -bed $regions_file"
            . " -fo $out_seq_file";

    my $out = `exec 2>&1; $cmd`;
    my $status = $? >> 8;

    if ($status) {
        carp "extract_search_region_sequences '$cmd' failed with status"
           . " $status - $out\n";
        return 0;
    }

    return 1;
}

=head2 create_regions_from_sequences

 Title   : create_regions_from_sequences
 Usage   : $srt->create_regions_from_sequences(
               -seq_file            => $seq_file,
               -out_regions_file    => $out_regions_file,
               -coord_shift         => $coord_shift
           );

 Function: Extract the regions corresponding to the sequences in the given
           sequence file. Optionally output the regions to the specified
           output regions file. This will only work if the sequence ID
           contains the coordinate information, e.g. chr1:1001000-1001599.

 Args    : -seq_file        => Input sequence file in fasta format
           -out_regions_file
                            => OPTIONAL. If specified, also write the
                               regions to this file (BED format).
           -coord_shift     => OPTIONAL. If true convert the coordinates
                               to one-based. The sequence file headers
                               extracted by BEDTools are in 0-based
                               coordinates (as of the writing of this code).

 Returns : A list of OPOSSUM::SearchRegion objects on success, false
           otherwise.

=cut

sub create_regions_from_sequences
{
    my ($self, %args) = @_;

    my $seq_file        = $args{-seq_file};
    my $coord_shift     = $args{-coord_shift};
    my $out_reg_file    = $args{-out_regions_file};

    unless ($seq_file) {
        carp "No input sequence file provided to fetch_regions_from_sequences!"
            . "\n";
        return undef;
    }

    #my $dir = $self->dir();
    #if ($dir) {
    #    $seq_file = catfile($dir, $seq_file);
    #}

    my $seqIO = Bio::SeqIO->new(-file => $seq_file, -format => 'fasta');
    unless ($seqIO) {
        carp "Could not open sequence file $seq_file!";
        return undef;
    }

    my @regions;
    while (my $seq = $seqIO->next_seq()) {
        my $seq_id = $seq->display_id();

        if ($seq_id =~ /\s*(\w+):(\d+)-(\d+)/) {
            my $chrom = $1;
            my $start = $2;
            my $end   = $3;

            $chrom =~ s/^chrom//;
            $chrom =~ s/^chr//;

            #
            # Convert to 1-based coordinates
            #
            if ($coord_shift) {
                $start += 1;
            }

            push @regions, OPOSSUM::SearchRegion->new(
                -chrom  => $chrom,
                -start  => $start,
                -end    => $end
            );
        } else {
            carp "Could not determine chromosomal coordinates of sequence from"
                . " sequence ID";
            return undef;
        }
    }

    if (@regions && $out_reg_file) {
        $self->write_bed(
            -filename   => $out_reg_file,
            -regions    => \@regions
        );
    }

    return @regions ? \@regions : undef;
}

sub has_region_id
{
    my $self = shift;

    if (@_) {
        $self->{-region_type} = shift;
    }

    return $self->{-region_type};
}

sub dir
{
    my $self = shift;

    if (@_) {
        $self->{-dir} = shift;
    }

    return $self->{-dir};
}

sub species
{
    my $self = shift;

    if (@_) {
        $self->{-species} = shift;
    }

    return $self->{-species};
}

sub t_or_b
{
    my $self = shift;

    return $self->{-t_or_b};
}

sub initial_regions
{
    my $self = shift;

    unless ($self->{-initial_regions}) {
        my $initial_regions_file = $self->initial_regions_file();
        if ($initial_regions_file) {
            my $initial_regions = $self->read_bed(
                -filename => $initial_regions_file
            );
            $self->{-initial_regions} = $initial_regions;
        }
    }

    return $self->{-initial_regions};
}

sub initial_regions_file
{
    my $self = shift;

    if (@_) {
        $self->{-initial_regions_file} = shift;
    }

    return $self->{-initial_regions_file};
}

sub merged_regions
{
    my $self = shift;

    unless ($self->{-merged_regions}) {
        my $merged_regions_file = $self->merged_regions_file();
        if ($merged_regions_file) {
            my $merged_regions = $self->read_bed(
                -filename => $merged_regions_file
            );
            $self->{-merged_regions} = $merged_regions;
        }
    }

    return $self->{-merged_regions};
}

sub merged_regions_file
{
    my $self = shift;

    if (@_) {
        $self->{-merged_regions_file} = shift;
    }

    return $self->{-merged_regions_file};
}

sub filtering_regions
{
    my $self = shift;

    unless ($self->{-filtering_regions}) {
        my $filtering_regions_file = $self->filtering_regions_file();
        if ($filtering_regions_file) {
            my $filtering_regions = $self->read_bed(
                -filename => $filtering_regions_file
            );
            $self->{-filtering_regions} = $filtering_regions;
        }
    }

    return $self->{-filtering_regions};
}

sub filtering_regions_file
{
    my $self = shift;

    if (@_) {
        $self->{-filtering_regions_file} = shift;
    }

    return $self->{-filtering_regions_file};
}

sub filtered_regions
{
    my $self = shift;

    unless ($self->{-filtered_regions}) {
        my $filtered_regions_file = $self->filtered_regions_file();
        if ($filtered_regions_file) {
            my $filtered_regions = $self->read_bed(
                -filename => $filtered_regions_file
            );
            $self->{-filtered_regions} = $filtered_regions;
        }
    }

    return $self->{-filtered_regions};
}

sub filtered_regions_file
{
    my $self = shift;

    if (@_) {
        $self->{-filtered_regions_file} = shift;
    }

    return $self->{-filtered_regions_file};
}

sub final_regions
{
    my $self = shift;

    unless ($self->{-final_regions}) {
        my $final_regions_file = $self->final_regions_file();
        if ($final_regions_file) {
            my $final_regions = $self->read_bed(
                -filename => $final_regions_file
            );
            $self->{-final_regions} = $final_regions;
        }
    }

    return $self->{-final_regions};
}

sub final_regions_file
{
    my $self = shift;

    if (@_) {
        $self->{-final_regions_file} = shift;
    }

    return $self->{-final_regions_file};
}

sub read_bed
{
    my ($self, %args) = @_;

    my $fh       = $args{-fh};
    my $filename = $args{-filename};

    my $have_fh = 0;
    $have_fh = 1 if defined $fh;

    unless ($have_fh || $filename) {
        carp "read_bed: no filename or file handle provided!\n";
        return 0;
    }

    #
    # Check if either a file handle, filename or neither is passed. A
    # filehandle takes precedence over a filename.
    #
    unless ($have_fh) {
        #
        # If directory is set, ASSUME the full path is not included in
        # the filename and prepend it.
        #
        #$filename = catfile($self->dir, $filename) if $self->dir;

        $fh = FileHandle->new($filename);
        unless (defined $fh) {
            carp("Error opening BED file $filename for reading\n");
            return 0;
        }
    }

    #
    # The search region's ID is used for mapping TFBSs to regions etc. so
    # create an ID here. The pre-computed regions which come from the
    # DB have an ID field set, but this is not preserved in the various
    # reading and writing to BED files. The fourth column of the BED files
    # is used for the pre-computed (parent) ID of regions computed from
    # FANTOM5 CAGE peaks.
    #
    my $sr_id = 1;
    my @regions;
    #
    # Four column format (name column holds the pre-computed (parent)
    # search region ID
    #
    while (my $line = <$fh>) {
        chomp $line;

        #
        # NOTE: BED format does not specify tab delimeted columns
        # so split on any run of white space.
        #
        next unless $line =~ /^\s*\w+\s+\d+\s+\d+/;

        #
        # Note: parent ID may or may not be present depending on whether
        # region was constructed from FANTOM5 CAGE peaks.
        #
        my ($chrom, $start, $end, $parent_id) = split /\s+/, $line;

        # Note: BED specification is for 0-based start coordinates.
        $start++;

        if ($chrom =~ /chr(\w+)/) {
            $chrom = $1;
        }

        push @regions, OPOSSUM::SearchRegion->new(
            -id         => $sr_id++,
            -chrom      => $chrom,
            -start      => $start,
            -end        => $end,
            -parent_id  => $parent_id
        );
    }

    #
    # If a filehandle was passed then it is the caller's responsibility to
    # close it. Otherwise the file was opened locally, so close it here.
    #
    unless ($have_fh) {
        $fh->close();
    }

    return @regions ? \@regions : undef;
}

sub write_bed
{
    my ($self, %args) = @_;

    my $fh          = $args{-fh};
    my $filename    = $args{-filename};
    my $basename    = $args{-basename};
    my $regions     = $args{-regions};

    unless ($regions && $regions->[0]) {
        carp "write_bed: no search regions provided!\n";
        return 0;
    }

    my $have_fh = 0;
    $have_fh = 1 if defined $fh;

    #
    # Check if either a file handle, filename or neither is passed. A
    # filehandle takes precedence over a filename. If neither is passed
    # the regions are written to a temporary file.
    #
    unless ($have_fh) {
        if (defined $filename) {
            #
            # If directory is set, ASSUME the full path is not included in
            # the filename and prepend it.
            #
            #$filename = catfile($self->dir, $filename) if $self->dir;

            $fh = FileHandle->new(">$filename");
            unless (defined $fh) {
                carp("Error opening BED file $filename for writing\n");
                return 0;
            }
        } else {
            ($fh, $filename) = $self->_create_tempfile(
                -basename => $basename, -suffix => '.bed'
            );
            unless (defined $fh) {
                carp("Error creating BED temp. file with basename $basename\n");
                return 0;
            }
        }
    }

    foreach my $reg (@$regions) {
        my $chrom = $reg->chrom;
        unless ($chrom =~ /^chr/) {
            $chrom = "chr$chrom";
        }

        my $parent_id = $reg->parent_id;

        if (defined $parent_id) {
            #
            # Note: using the BED file name field (column 4) to store the
            # parent region ID
            #
            printf $fh "%s\t%d\t%d\t%d\n",
                $chrom,
                $reg->start - 1,    # BED 0-based start coord
                $reg->end,
                $reg->parent_id;
        } else {
            printf $fh "%s\t%d\t%d\n",
                $chrom,
                $reg->start - 1,    # BED 0-based start coord
                $reg->end;
        }
    }

    #
    # If a filehandle was passed then it is the caller's responsibility to
    # close it. Otherwise the file was opened locally, so close it here.
    #
    unless ($have_fh) {
        $fh->close();
    }

    return 1;
}

sub _create_tempfile
{
    my ($self, %args) = @_;

    my $basename    = $args{-basename};
    my $suffix      = $args{-suffix};

    my $dir = $self->dir();
    my $t_or_b = $self->t_or_b();

    my $template = '';
    if (defined $t_or_b) {
        if ($t_or_b eq 'target') {
            $template = 't';
        } elsif ($t_or_b eq 'background') {
            $template = 'b';
        }
    }

    $template .= "_$basename" if $basename;
    $template .= "_XXXXXX";

    my ($fh, $filename);
    if ($dir) {
        ($fh, $filename) = tempfile($template, SUFFIX => $suffix, DIR => $dir);
    } else {
        ($fh, $filename) = tempfile($template, SUFFIX => $suffix, TMPDIR => 1);
    }

    unless ($fh) {
        carp "Could not create tempfile $template\n";
        return ();
    }

    return ($fh, $filename);
}

sub _cleanup
{
    my ($self) = @_;

    if ($self->{-initial_regions_file}) {
        unlink $self->{-initial_regions_file};
    }

    if ($self->{-merged_regions_file}) {
        unlink $self->{-merged_regions_file};
    }

    if ($self->{-filtering_regions_file}) {
        unlink $self->{-filtering_regions_file};
    }

    if ($self->{-filtered_regions_file}) {
        unlink $self->{-filtered_regions_file};
    }

    return;
}

sub DESTROY
{
    my $self = shift;

    unless ($DEBUG) {
        $self->_cleanup();
    }
}

1;
