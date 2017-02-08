#!/usr/bin/env perl

=head1 NAME

cleanup_old_results.pl

=head1 SYNOPSIS

  cleanup_old_results.pl

=head1 ARGUMENTS

  None. Uses the REMOVE_TEMPFILES_OLDER_THAN and REMOVE_RESULTFILES_OLDER_THAN
  constants defined in OPOSSUM::Opt::BaseOpt which define how many days old
  these files need to be to be removed.

=head1 DESCRIPTION

Cleanup old result and temp. files. This was originally done within the web
app's teardown routine but caused BIG slow downs in the webserver. This
functionality will be done here instead and called as a cron job.

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

use File::Path;
use File::stat;

use OPOSSUM::Web::Opt::BaseOpt;

use constant APACHE_UID => 48;
use constant APACHE_GID => 48;


clean_tempfiles();
clean_resultfiles();

exit;

sub clean_tempfiles
{
    my @tempfiles = glob(OPOSSUM_TMP_PATH . "/*");
    foreach my $file (@tempfiles) {
        if (-d $file) {
            print "$file is a directory - skipping...";
            next;
        }

        #print "Processing temp. file $file\n";
        if (-M $file > REMOVE_TEMPFILES_OLDER_THAN) {
            #print "Temp. file $file is old\n";
            #
            # Safety check. Make sure file is owned by Apache.
            # We may want to specifically change owner/group so as
            # to preserve some older results.
            #
            my $sb = stat($file);
            my $user = getpwuid($sb->uid);
            my $group = getgrgid($sb->gid);
            print "Temp. file $file user is $user and group is $group\n";
            if ($user eq 'apache' && $group eq 'apache') {
                print "Removing temp. file $file\n";
                unlink $file;
            } else {
                print "Temp. file $file is not owned by Apache\n";
            }
        }
    }
}

sub clean_resultfiles
{
    my @files = glob(ABS_HTDOCS_RESULTS_PATH . "/*");

    foreach my $file (@files) {
        #print "Processing result file $file\n";
        if (-M $file > REMOVE_RESULTFILES_OLDER_THAN) {
            #print "Result file $file is old\n";
            #
            # Safety check. Make sure file is owned by Apache.
            # We may want to specifically change owner/group so as
            # to preserve some older results.
            #
            my $sb = stat($file);
            my $user = getpwuid($sb->uid);
            my $group = getgrgid($sb->gid);
            #print "Result file $file user is $user and group is $group\n";
            if ($user eq 'apache' && $group eq 'apache') {
                if (-d $file) {
                    # remove entire tree if directory
                    print "Removing result directory $file\n";
                    rmtree($file, 0, 0);
                } elsif (-f $file) {
                    # unlink if file
                    #print "Removing result file $file\n";
                    unlink($file);
                }
            } else {
                print "Result file $file is not owned by Apache\n";
            }
        }
    }
}
