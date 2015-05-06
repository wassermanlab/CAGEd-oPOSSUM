=head1 NAME

OPOSSUM::Tools::BiasAway - quick and dirty class to run BiasAway.

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

package OPOSSUM::Tools::BiasAway;

use Carp;
use FileHandle;
use File::Path qw(make_path remove_tree);
use Readonly;

use strict;

Readonly::Scalar my $BA_EXEC        => 'python2.7 /apps/BiasAway/BiasAway.py g';
Readonly::Scalar my $BA_DFLT_FOLD   => 1;

=head2 new

 Title   : new
 Usage   : $ba = OPOSSUM::Tools::BiasAway->new(
               -working_dir => $working_dir,
               -debug       => $debug
           );

 Function: Construct a new OPOSSUM::Tools::BiasAway object.

 Args    : -working_dir => (temporary) working directory where BiasAway
                           creates binned sequence files.
           -debug       => OPTIONAL. If set, do not remove working
                           directory on object destruction.

 Returns : A new OPOSSUM::Tools::BiasAway object

=cut

sub new
{
    my ($class, %args) = @_;

    my $dir = $args{-working_dir};

    unless ($dir) {
        carp "No working BiasAway working directory provided";
        return undef;
    }
    
    my $self = bless {
        %args
    }, ref $class || $class;

    if (-d $dir) {
        unless (-w $dir) {
            carp "Specified BiasAway working directory $dir is not writable";
            return undef;
        }
    } else {
        unless (make_path($dir)) {
            carp "Unable to create BiasAway working directory $dir";
            return undef;
        }

        $self->{-dir_created} = 1;
    }

    return $self;
}

=head2 run

 Title   : run
 Usage   : $ba = OPOSSUM::Tools::BiasAway->run(
                -fg_seq_file    => $fg_seq_file,
                -bg_seq_file    => $bg_seq_file,
                -out_seq_file   => $out_seq_file,
                -fold           => $fold,
                -length_match   => $length_match
            );

 Function: Compute a set of sequences GC composition matched (and optionally
           length matched) to the given foreground sequences.

 Args    : -fg_seq_file
                Name of the foreground sequences file.
           -bg_seq_file
                Name of the background sequences file. This is the pool
                of sequences from which BiasAway computes the sequences
                which match GC composition bias to the foreground.
           -out_seq_file
                Output file of sequences which matche the foreground file
                for GC composition (and length).
           -fold
                OPTIONAL. The proportion of output sequences compared to
                foreground.
           -length_match
                OPTIONAL. If provided, also try to match the length of the
                foreground sequences.

 Returns : True on success, false otherwise.

=cut

sub run
{
    my ($self, %args) = @_;

    my $fg_seq_file     = $args{-fg_seq_file};
    my $bg_seq_file     = $args{-bg_seq_file};
    my $out_seq_file    = $args{-out_seq_file};
    my $fold            = $args{-fold};
    my $length_match    = $args{-length_match};

    unless ($fg_seq_file) {
        carp "No foreground sequence file name provided";
        return 0;
    }

    unless ($bg_seq_file) {
        carp "No background sequence file name provided";
        return 0;
    }

    unless ($out_seq_file) {
        carp "No output GC composition matched sequence file name provided";
        return 0;
    }

    unless ($fold) {
        $fold = $BA_DFLT_FOLD;
    }

    my $cmd = $BA_EXEC;

    if ($length_match) {
        $cmd .= " -l";
    }

    $cmd .= sprintf(" -f %s -b %s -r %s -n %d > %s",
                $fg_seq_file,
                $bg_seq_file,
                $self->{-working_dir},
                $fold,
                $out_seq_file
            );

    my $out = `exec 2>&1; $cmd`;
    my $status = $? >> 8;
    if ($status) {
        carp "Error running BiasAway - $out";
    }

    return 1;
}

sub DESTROY
{
    my $self = shift;

    #
    # Remove working directory if and only if debug mode is NOT set and the
    # directory was actually created on object creation (don't remove it if
    # the directory already existed).
    #
    unless ($self->{-debug}) {
        if ($self->{-dir_created}) {
            remove_tree($self->{-working_dir});
        }
    }
}

1;
