#!/usr/bin/env perl

=head1 NAME

jobs_report.pl

=head1 SYNOPSIS

  jobs_report.pl [-d dir]

=head1 ARGUMENTS

    -d, -dir dir
        Name of the top level oPOSSUM analysis results directory to check
        for oPOSSUM job log files.

=head1 DESCRIPTION

Generate a report of oPOSSUM jobs which have not completed successfully, i.e
have either failed or are currently running.

Check sub-directories under the top level oPOSSUM analysis results directory.
Check the oPOSSUM analysis log files for jobs which have not yet finished and
report them.

Unfinished jobs may fall into several categories as follows:
1) Jobs which are still running - report run time highlighting if the job
   had been running for more than MAX_JOB_TIME.
2) Jobs which failed gracefully, i.e. wrote an error (FATAL) message to their
   respective log file and (presumably) notified the user of the error via
   e-mail (for jobs run in the background) or via direct error web page (for
   those jobs run in the foreground).
3) Jobs which crashed and exited ungracefully from an uncaught error or
   possibly due to some system problem such as a lack of memory and did not
   log the error or notify the user.

=head1 AUTHOR

David Arenillas, Andrew Kwon
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
use Carp;
use Time::Local;

use OPOSSUM::Web::Opt::BaseOpt;

use constant RESULTS_DIR    => '/apps/CAGEd_oPOSSUM/htdocs/results';
use constant MAX_JOB_TIME   => 12;  # hours
use constant EMAIL          => 'dave@cmmt.ubc.ca';

my $results_dir;
GetOptions(
    'dir|d=s'       => \$results_dir,
);

unless ($results_dir) {
    $results_dir = RESULTS_DIR;
}

unless (-d $results_dir) {
    die "Top level results directory $results_dir does not exist\n";
}

unless (chdir $results_dir) {
    die "Could not change directory to $results_dir\n";
}

my @unfinished = split /\n/, `grep -L 'Finished analysis' */caged_opossum.log`;

my %running_job;
my %error_job;
my %crashed_job;
if (@unfinished) {
    my $current_time = time();

    foreach my $log_file (@unfinished) {
        my ($job_id) = ($log_file =~ /(^.*)\/caged_opossum\.log/);

        my $start_line = `grep 'Starting analysis' $log_file`;
 
        my $start_date = line_date($start_line);
        my $start_time = datestr_to_localtime($start_date);

        my $job_running = job_running($job_id);

        if ($job_running) {
                my $run_time = $current_time - $start_time if $start_time;

                $running_job{$job_id} = {
                    -job_id         => $job_id,
                    -start_date     => $start_date,
                    -run_time       => $run_time
                }
        } else {
            my $error_line = `grep 'FATAL' $log_file`;

            if ($error_line) {
                my ($error) = $error_line =~ /FATAL\s+(.*)/;

                my $error_date = line_date($error_line);
                my $error_time = datestr_to_localtime($error_date);

                $error_job{$job_id} = {
                    -job_id         => $job_id,
                    -start_date     => $start_date,
                    -end_date       => $error_date,
                    -message        => $error
                };
            } else {
                my $last_line = job_last_line($log_file);

                my ($info) = $last_line =~ /INFO\s+(.*)/;

                my $last_date = line_date($last_line);
                my $last_time = datestr_to_localtime($last_date);

                $crashed_job{$job_id} = {
                    -job_id         => $job_id,
                    -start_date     => $start_date,
                    -end_date       => $last_date,
                    -message        => $info
                }
            }
        }
    }
}

my $report;

report_error_jobs(\%error_job, \$report);
report_crashed_jobs(\%crashed_job, \$report);
report_running_jobs(\%running_job, \$report);

print $report;

email_report($report);

exit;

sub job_running
{
    my ($job_id) = @_;

    my $out = `ps auwx | grep $job_id`;
    
    if ($out =~ /caged_opossum\.pl.*-j\s+$job_id/) {
        return 1;
    }

    return 0;
}

sub report_running_jobs
{
    my ($jobs, $report) = @_;

    $$report .= "\n\nRunning jobs:\n\n";
    foreach my $job_id (sort {
                            $jobs->{$a}->{-start_date}
                        cmp $jobs->{$b}->{-start_date}
                        } keys %$jobs
    ) {
        my $job = $jobs->{$job_id};

        $$report .= sprintf "$job_id\t%s\t%s hrs",
            $job->{-start_date},
            ($job->{-run_time} > MAX_JOB_TIME * 3600)
                ? sprintf "***%.2f***", $job->{-run_time} / 3600
                : sprintf "%.2f", $job->{-run_time} / 3600;

        $$report .= "\n";
    }
}

sub report_error_jobs
{
    my ($jobs, $report) = @_;

    $$report .= "\n\nJobs which failed due to error:\n\n";
    foreach my $job_id (sort {
                            $jobs->{$a}->{-start_date}
                        cmp $jobs->{$b}->{-start_date}
                        } keys %$jobs
    ) {
        my $job = $jobs->{$job_id};

        $$report .= sprintf "$job_id\t%s\t%s\t%s\n",
            $job->{-start_date},
            $job->{-end_date},
            $job->{-message};
    }
}

sub report_crashed_jobs
{
    my ($jobs, $report) = @_;

    $$report .= "\n\nJobs which died without reporting an error:\n\n";

    foreach my $job_id (sort {
                            $jobs->{$a}->{-start_date}
                        cmp $jobs->{$b}->{-start_date}
                        } keys %$jobs
    ) {
        my $job = $jobs->{$job_id};

        $$report .= sprintf "$job_id\t%s\t%s\t%s\n",
            $job->{-start_date},
            $job->{-end_date},
            $job->{-message} ? $job->{-message} : '';
    }
}

sub line_date
{
    my ($line) = @_;

    if ($line && $line =~ /\[(\d+\/\d+\/\d+\s+\d+:\d+:\d+)\]/) {
        return $1;
    }

    return undef;
}

sub datestr_to_localtime
{
    my ($datestr) = @_;

    if ($datestr && $datestr =~ /(\d+)\/(\d+)\/(\d+)\s+(\d)+:(\d+):(\d+)/) {
        return timelocal($6, $5, $4, $3, $2-1, $1-1900);
    }

    return undef;
}

sub job_last_line
{
    my $log_file = shift;

    return `tail -1 $log_file`;
}

sub email_report
{
    my ($report) = @_;

    my $cmd = "/usr/sbin/sendmail -i -t";

    unless (open(SM, "|" . $cmd)) {
        die "Could not open sendmail - $!";
    }

    printf SM "To: %s\n", EMAIL;
    print SM "Subject: CAGEd-oPOSSUM job report\n\n";
    print SM "$report" ;

    close(SM);
}
