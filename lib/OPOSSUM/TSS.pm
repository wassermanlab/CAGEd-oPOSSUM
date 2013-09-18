=head1 NAME

OPOSSUM::TSS - TSS object (tss DB record)

=head1 DESCRIPTION

A TSS object models a record retrieved from the tss table of the FANTOM5
oPOSSUM DB. The TSS object contains positional information of the TSS as well
as short and long descriptions, associated genes/transcripts etc.

=head1 MODIFICATIONS

=head1 AUTHOR

 David Arenillas
 Wasserman Lab
 Centre for Molecular Medicine and Therapeutics
 University of British Columbia

 E-mail: dave@cmmt.ubc.ca

=head1 METHODS

=cut
package OPOSSUM::TSS;

use strict;
use Carp;
use OPOSSUM::DBObject;

use vars qw(@ISA);

@ISA = qw(OPOSSUM::DBObject);


=head2 new

 Title   : new
 Usage   : $tss = OPOSSUM::TSS->new(
                -id                 => 1,
                -search_region_id   => 36267,
                -chrom              => 10,
                -start              => 100007025,
                -end                => 100007067,
                -strand             => '+',
                -is_tss             => 1,
                -name               => 'chr10:100007025..100007067,+',
                -max_tag_count      => 10,
                -max_tpm            => 17.04380984004,
                -entrez_gene_ids    => 216274,
                -uniprot_ids        => [Q3TUM0,Q8JZS0,O88951],
                -short_description  => 'p1@Cep290',
                -description        => 'CAGE_peak_1_at_Cep290_5end',
                -association_with_transcript    => '0bp_to_uc007gxw.2_5end'
            );

 Function: Construct a new TSS object
 Returns : a new OPOSSUM::TSS object

=cut

sub new
{
    my ($class, %args) = @_;

    my $self = bless {
        %args
    }, ref $class || $class;

    return $self;
}

=head2 id

 Title   : id
 Usage   : $id = $tss->id() or $tss->id($id);
 Function: Get/set the ID of the TSS.
 Returns : The TSS ID.
 Args    : None or a new ID.

=cut

sub id
{
    my ($self, $id) = @_;

    if (defined $id) {
        $self->{-id} = $id;
    }
    return $self->{-id};
}

=head2 search_region_id

 Title   : search_region_id
 Usage   : $sr_id = $tss->search_region_id()
           or $tss->search_region_id($sr_id);
 Function: Get/set the search region ID of the search region that this TSS
           falls into.
 Returns : The search region ID.
 Args    : None or a new search region ID.


=cut

sub search_region_id
{
    my ($self, $sr_id) = @_;

    if (defined $sr_id) {
        $self->{-search_region_id} = $sr_id;
    }
    return $self->{-search_region_id};
}

=head2 chrom

 Title   : chrom
 Usage   : $chrom = $tss->chrom() or $tss->chrom($chrom);
 Function: Get/set the chromosome name.
 Returns : An string.
 Args    : None or a new chromosome name.

=cut

sub chrom
{
    my ($self, $chrom) = @_;

    if ($chrom) {
        $self->{-chrom} = $chrom;
    }
    return $self->{-chrom};
}

=head2 start

 Title   : start
 Usage   : $start = $tss->start() or $tss->start($start);
 Function: Get/set the start position of this TSS
 Returns : An integer.
 Args    : None or a new start position.

=cut

sub start
{
    my ($self, $start) = @_;

    if ($start) {
        $self->{-start} = $start;
    }
    return $self->{-start};
}

=head2 end

 Title   : end
 Usage   : $end = $tss->end() or $tss->end($end);
 Function: Get/set the end position of this TSS
 Returns : An integer.
 Args    : None or a new end position.

=cut

sub end
{
    my ($self, $end) = @_;

    if ($end) {
        $self->{-end} = $end;
    }
    return $self->{-end};
}

=head2 strand

 Title   : strand
 Usage   : $strand = $tss->strand() or $tss->strand($strand);
 Function: Get/set the strand of this TSS
 Returns : '+' or '-'.
 Args    : None or a new strand.

=cut

sub strand
{
    my ($self, $strand) = @_;

    if ($strand) {
        $self->{-strand} = $strand;
    }
    return $self->{-strand};
}

=head2 is_tss

 Title   : is_tss
 Usage   : $is_tss = $tss->is_tss() or $tss->is_tss($is_tss);
 Function: Get/set the 'is TSS' status of this TSS
 Returns : 0 or 1. 
 Args    : None or a new 'is TSS' status.

=cut

sub is_tss
{
    my ($self, $is_tss) = @_;

    if (defined $is_tss) {
        $self->{-is_tss} = $is_tss;
    }
    return $self->{-is_tss};
}

=head2 name

 Title   : name
 Usage   : $name = $tss->name() or $tss->name($name);
 Function: Get/set the name of this TSS
 Returns : '+' or '-'.
 Args    : None or a new name.

=cut

sub name
{
    my ($self, $name) = @_;

    if ($name) {
        $self->{-name} = $name;
    }
    return $self->{-name};
}

=head2 max_tag_count

 Title   : max_tag_count
 Usage   : $count = $tss->max_tag_count() or $tss->max_tag_count($count);
 Function: Get/set the maximum tag count across all experiments for this
           TSS.
 Returns : '+' or '-'.
 Args    : None or a new maximum tag count.

=cut

sub max_tag_count
{
    my ($self, $count) = @_;

    if ($count) {
        $self->{-max_tag_count} = $count;
    }
    return $self->{-max_tag_count};
}

=head2 max_tpm

 Title   : max_tpm
 Usage   : $tpm = $tss->max_tpm() or $tss->max_tpm($tpm);
 Function: Get/set the maximum tags per million (TPM) across all experiments
           for this TSS.
 Returns : '+' or '-'.
 Args    : None or a new maximum TPM value.

=cut

sub max_tpm
{
    my ($self, $tpm) = @_;

    if ($tpm) {
        $self->{-max_tpm} = $tpm;
    }
    return $self->{-max_tpm};
}

=head2 entrez_gene_ids

 Title   : entrez_gene_ids
 Usage   : $ids = $tss->entrez_gene_ids() or $tss->entrez_gene_ids($ids);
 Function: Get/set the Entrez Gene IDs associatted with this TSS.
 Returns : An array or array ref of Entrez Gene IDs.
 Args    : Optionally one of:
            a single Entrez Gene ID,
            a comma separated string of Entrez Gene IDs,
            an array reference of Entrez Gene IDs

=cut

sub entrez_gene_ids
{
    my $self = shift;

    if (@_) {
        my $ids = shift;

        if (ref $ids eq 'ARRAY') {
            # IDs passed in as arrayref
            $self->{-entrez_gene_ids} = $ids;
        } elsif (my @ary = split /\s*,\s*/, $ids) {
            # IDs passed in as a comma separated string
            $self->{-entrez_gene_ids} = \@ary;
        } else {
            # Single ID
            $self->{-entrez_gene_ids} = [$ids];
        }
    }

    if (wantarray) {
        return $self->{-entrez_gene_ids} ? @{$self->{-entrez_gene_ids}} : ();
    } else {
        return $self->{-entrez_gene_ids};
    }
}

=head2 uniprot_ids

 Title   : uniprot_ids
 Usage   : $ids = $tss->uniprot_ids() or $tss->uniprot_ids($ids);
 Function: Get/set the Uniprot IDs associated with this TSS.
 Returns : An array or array ref of Uniprot IDs.
 Args    : Optionally one of:
            a single Uniprot ID,
            a comma separated string of Uniprot IDs,
            an array reference of Uniprot IDs

=cut

sub uniprot_ids
{
    my $self = shift;

    if (@_) {
        my $ids = shift;

        if (ref $ids eq 'ARRAY') {
            # IDs passed in as arrayref
            $self->{-uniprot_ids} = $ids;
        } elsif (my @ary = split /\s*,\s*/, $ids) {
            # IDs passed in as a comma separated string
            $self->{-uniprot_ids} = \@ary;
        } else {
            # Single ID
            $self->{-uniprot_ids} = [$ids];
        }
    }

    if (wantarray) {
        return $self->{-uniprot_ids} ? @{$self->{-uniprot_ids}} : ();
    } else {
        return $self->{-uniprot_ids};
    }
}

=head2 hgnc_gene_ids

 Title   : hgnc_gene_ids
 Usage   : $ids = $tss->hgnc_gene_ids() or $tss->hgnc_gene_ids($ids);
 Function: Get/set the HGNC Gene IDs associatted with this TSS.
 Returns : An array or array ref of HGNC Gene IDs.
 Args    : Optionally one of:
            a single HGNC Gene ID,
            a comma separated string of HGNC Gene IDs,
            an array reference of HGNC Gene IDs

=cut

sub hgnc_gene_ids
{
    my $self = shift;

    if (@_) {
        my $ids = shift;

        if (ref $ids eq 'ARRAY') {
            # IDs passed in as arrayref
            $self->{-hgnc_gene_ids} = $ids;
        } elsif (my @ary = split /\s*,\s*/, $ids) {
            # IDs passed in as a comma separated string
            $self->{-hgnc_gene_ids} = \@ary;
        } else {
            # Single ID
            $self->{-hgnc_gene_ids} = [$ids];
        }
    }

    if (wantarray) {
        return $self->{-hgnc_gene_ids} ? @{$self->{-hgnc_gene_ids}} : ();
    } else {
        return $self->{-hgnc_gene_ids};
    }
}

=head2 short_description

 Title   : short_description
 Usage   : $desc = $tss->short_description()
           or $tss->short_description($desc);
 Function: Get/set the short description of this TSS
 Returns : A short description of this TSS.
 Args    : None or a new short description.

=cut

sub short_description
{
    my ($self, $desc) = @_;

    if ($desc) {
        $self->{-short_description} = $desc;
    }
    return $self->{-short_description};
}

=head2 description

 Title   : description
 Usage   : $desc = $tss->description()
           or $tss->description($desc);
 Function: Get/set the description of this TSS
 Returns : A description of this TSS.
 Args    : None or a new description.

=cut

sub description
{
    my ($self, $desc) = @_;

    if ($desc) {
        $self->{-description} = $desc;
    }
    return $self->{-description};
}

=head2 association_with_transcript

 Title   : association_with_transcript
 Usage   : $trans_assoc = $tss->association_with_transcript()
           or $tss->association_with_transcript($trans_assoc);
 Function: Get/set the transcript(s) with which this TSS is associated.
 Returns : A (possibly comma separated) string of transcripts with which
           this TSS is associated.
 Args    : None or a new (possibly comma separated) string of transcripts
           with which this TSS is associated.

=cut

sub association_with_transcript
{
    my ($self, $trans_assoc) = @_;

    if ($trans_assoc) {
        $self->{-association_with_transcript} = $trans_assoc;
    }
    return $self->{-association_with_transcript};
}

1;
