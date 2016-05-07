#
# This module should be included in all the oPossum*Web.pm modules and
# possibly the background perl scripts called by those modules. It
# contains all routines that are common to all the oPossum variants. This
# includes utility functions as well as the common template routines like
# 'errors' and 'warnings'.
#

use OPOSSUM::Web::Opt::BaseOpt;

use lib OPOSSUM_LIB_PATH;

#use Data::Dumper;    # for debugging only

use File::Path qw{rmtree};
use OPOSSUM::TFSet;
use TFBS::DB::JASPAR5;

use Template;
use CGI::Carp qw(carpout);    # fatalsToBrowser;

use strict;

#
# High-level error routine. Call low level _error routine with current error
# and output all current errors to HTML error template.
#
sub error
{
    my ($self, $error) = @_;

    $self->_error($error) if $error;

    my $errors = $self->errors();

    #my $err_str = join "\n", @$errors;
    #carp "\nERROR:\n$err_str\n";

    my $error_html;
    foreach my $err (@$errors) {
        chomp $err;
        $err =~ s/\n/<br>/g;
        $error_html .= "$err<br>";
    }

    my $state = $self->state;

    my $vars = {
        abs_htdocs_path  => ABS_HTDOCS_PATH,
        rel_htdocs_path  => REL_HTDOCS_PATH,
        abs_cgi_bin_path => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path => REL_CGI_BIN_PATH,
        bg_color_class   => $state->bg_color_class(),
        title            => $state->title(),
        heading          => $state->heading(),
        section          => 'Error',
        version          => VERSION,
        devel_version    => DEVEL_VERSION,
        error            => $error_html,
        var_template     => "error.html"
    };

    my $output = $self->process_template('master.html', $vars);

    $self->clear_errors();

    return $output;
}

#
# High-level warning routine. Call low level _warning routine with current
# warning and output all current warnings to HTML warning template.
#
sub warning
{
    my ($self, $warning) = @_;

    $self->_warning($warning) if $warning;

    my $warnings = $self->warnings();

    my $warning_html;
    foreach my $warn (@$warnings) {
        chomp $warn;
        $warn =~ s/\n/<br>/g;
        $warning_html .= "$warn<br>";
    }

    my $state = $self->state;

    my $vars = {
        abs_htdocs_path  => ABS_HTDOCS_PATH,
        rel_htdocs_path  => REL_HTDOCS_PATH,
        abs_cgi_bin_path => ABS_CGI_BIN_PATH,
        rel_cgi_bin_path => REL_CGI_BIN_PATH,
        bg_color_class   => $state->bg_color_class(),
        title            => $state->title(),
        heading          => $state->heading(),
        section          => 'Warning',
        version          => VERSION,
        devel_version    => DEVEL_VERSION,
        warning          => $warning_html,
        var_template     => "warning.html"
    };

    my $output = $self->process_template('master.html', $vars);

    $self->warnings(undef);

    return $output;
}

sub process_template
{
    my ($self, $template_name, $vars) = @_;

    my $config = {
        ENCODING     => 'utf8',
        ABSOLUTE     => 1,
        INCLUDE_PATH => ABS_HTDOCS_TEMPLATE_PATH . "/", # or list ref
        INTERPOLATE  => 1,  # expand "$var" in plain text
        POST_CHOMP   => 1,  # cleanup whitespace
        #PRE_PROCESS  => 'header',  # prefix each template
        EVAL_PERL    => 1  # evaluate Perl code blocks
    };

    my $string   = '';
    my $template = Template->new($config);
    my $input    = ABS_HTDOCS_TEMPLATE_PATH . "/$template_name";
    $template->process($input, $vars, \$string, {binmode => ':utf8'}) || die $template->error();

    return $string;
}

#
# Andrew - March 4, 2012
# Was wondering if I could use this to display the results.html created by
# an analysis script by oPossumWeb/oPossumGeneSSAWeb, but no go
# says the file is not found--some kind of permission problem?
#
=head3
sub process_html
{
	my ($self, $html_file) = @_;

	my $config = {
		ABSOLUTE	=> 1,
		POST_CHOMP	=> 1,
		EVAL_PERL	=> 1
	};

	my $string = '';
	my $vars;
	my $template = Template->new($config);
	$template->process($html_file, $vars, \$string) || die $template->error();

	return $string;
}
=cut

sub jdbh
{
    my $self = shift;

    if (@_) {
        $self->{-jdbh} = shift;
    }

    return $self->{-jdbh};
}

sub state
{
    my $self = shift;

    if (@_) {
        $self->param('state', shift);
    }

    return $self->param('state');
}

sub errors
{
    my $self = shift;

    if (@_) {
        my $error = shift;
        $self->param('errors', [$error]);
    }

    return $self->param('errors');
}

sub clear_errors
{
    my $self = shift;

    $self->param('errors', undef);
}

sub warnings
{
    my $self = shift;

    if (@_) {
        my $warning = shift;
        $self->param('warnings', [$warning]);
    }

    return $self->param('warnings');
}

sub jaspar_db_connect
{
    my $self = shift;

    my $dbh = TFBS::DB::JASPAR5->connect(
        "dbi:mysql:" . JASPAR_DB_NAME . ":" . JASPAR_DB_HOST,
        JASPAR_DB_USER,
        JASPAR_DB_PASS
    );

    unless ($dbh) {
        $self->_error("Could not connect to JASPAR database " . JASPAR_DB_NAME);
        return;
    }

    $self->jdbh($dbh);
}

sub fetch_tf_set
{
    my ($self, %args) = @_;

    my %matrix_args = %args;

    unless ($matrix_args{-matrixtype}) {
        $matrix_args{-matrixtype} = 'PFM';
    }

    #printf STDERR "fetch_tf_set: matrix_args = \n"
    #    . Data::Dumper::Dumper(%matrix_args) . "\n";

    my $jdbh = $self->jdbh();

    my $matrix_set = $jdbh->get_MatrixSet(%matrix_args);

    my $tf_set = OPOSSUM::TFSet->new(-matrix_set => $matrix_set);

    return $tf_set;
}

sub parse_textbox_as_list
{
    my ($self, $param) = @_;

    my $text = $self->parse_textbox($param);

    return unless defined $text;

    my @list = split "\n", $text;

    return (@list && $list[0]) ? \@list : undef;
}

sub parse_textbox
{
    my ($self, $param) = @_;

    my $text = $self->query->param($param);

    return unless defined $text;

    #
    # Strip leading trailing space
    #
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    #
    # Not sure the newline problem is applicable to pasted text, but to be
    # safe...
    #

    # Convert DOS style <CR><LF> to linux <LF>
    $text =~ s/\r\n/\n/g;

    # Convert older Mac style <CR> to linux <LF>
    $text =~ s/\r/\n/g;

    return unless defined $text;

    return $text;
}

sub parse_upload_filename
{
    my ($self, $param) = @_;

    my $filename = $self->query->param($param);
    #my $fh = $self->query->upload($param);
    #my $filename = $fh->filename;

    return unless defined $filename;

    #
    # Strip leading trailing space
    #
    $filename =~ s/^\s+//;
    $filename =~ s/\s+$//;

    return unless defined $filename;

    #
    # Strip path
    #
    $filename =~ s/.*\///;

    return unless defined $filename;

    return $filename;
}

sub upload_and_parse_filename
{
    my ($self, $cgi_param_name) = @_;

    printf STDERR "upload_and_parse_filename() called with cgi param"
        . " '$cgi_param_name'\n";

    my $q = $self->query;

    my $tmp_user_filename = $q->param($cgi_param_name);

    #
    # The CGI module changed it's implementation of temporary (upload) files.
    # Now for some *unknown* reason, although retrieving the user entered
    # file name with e.g. $q->param('cgi_param_name') appears to correctly
    # return a simple string file name, when it is later assigned to and
    # stored in the state object, it actually gets stored as something like
    # e.g. 'CGI::File::Temp=GLOB(0x13692f48)'. Quoting the file name seems to
    # "force" it to be treated as a string.
    #
    my $user_filename = "$tmp_user_filename";

    #
    # This should return a CGI::::File::Temp object which is also just a
    # File::Temp object.
    #
    my $fh = $q->upload($cgi_param_name);

    return () unless $fh;

    printf STDERR "upload_and_parse_filename() filehande obtained\n";

    # This is the local temporary file name
    my $tmp_filename = $fh->filename;

    return ($fh, undef) unless defined $user_filename;

    printf STDERR "upload_and_parse_filename() user file name '$user_filename'"
        . " obtained\n";

    #
    # Strip leading trailing space
    #
    $user_filename =~ s/^\s+//;
    $user_filename =~ s/\s+$//;

    return ($fh, undef) unless defined $user_filename;

    #
    # Strip path
    #
    $user_filename =~ s/.*\///;

    return ($fh, undef) unless defined $user_filename;

    printf STDERR "upload_and_parse_filename() final parsed file name"
        . " = '$user_filename'\n";

    return ($fh, $user_filename);
}

sub create_local_file_from_text
{
    my ($self, $localpath, $text) = @_;

    unless ($text) {
        $self->_error("Not text provided for local file $localpath");
        return;
    }

    unless (open(FH, ">$localpath")) {
        $self->_error("Unable to create local file $localpath");
        return;
    }

    print FH $text;

    close(FH);

    return 1;
}

sub create_local_file_from_list
{
    my ($self, $localpath, $list) = @_;

    unless ($list && $list->[0]) {
        $self->_error("Not text provided for local file $localpath");
        return;
    }

    unless (open(FH, ">$localpath")) {
        $self->_error("Unable to create local file $localpath");
        return;
    }

    foreach my $line (@$list) {
        print FH "$line\n";
    }

    close(FH);

    return 1;
}

sub create_local_file_from_upload
{
    my ($self, $localpath, $cgi_file_param) = @_;

    my $q = $self->query;

    my $file = $q->param($cgi_file_param);
    my $fh   = $q->upload($cgi_file_param);
    #my $fh = $q->upload($cgi_file_param);
    #my $file = $fh->filename;

    my $text;
    while (my $line = <$fh>) {
        $text .= $line;
    }

    unless ($text) {
        $self->_error("Upload file $file is empty");
        return;
    }

    #
    # Strip leading trailing space
    #
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    # Convert DOS style <CR><LF> to linux <LF>
    $text =~ s/\r\n/\n/g;

    # Convert older Mac style <CR> to linux <LF>
    $text =~ s/\r/\n/g;

    unless (open(FH, ">$localpath")) {
        $self->_error("Unable to create local file $localpath");
        return;
    }

    print FH $text;

    close(FH);

    return 1;
}

sub create_local_file_from_upload_fh
{
    my ($self, $temp_fh, $local_filename) = @_;

    my $text;
    while (my $line = <$temp_fh>) {
        $text .= $line;
    }

    unless ($text) {
        my $temp_filename = $temp_fh->filename;
        $self->_error("Uploaded temp. file $temp_filename is empty");
        return;
    }

    #
    # Strip leading trailing space
    #
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;

    # Convert DOS style <CR><LF> to linux <LF>
    $text =~ s/\r\n/\n/g;

    # Convert older Mac style <CR> to linux <LF>
    $text =~ s/\r/\n/g;

    unless (open(FH, ">$local_filename")) {
        $self->_error("Unable to create local file $local_filename");
        return;
    }

    print FH $text;

    close(FH);

    return 1;
}

#
# Create a local working file. Used to store input gene and TF IDs.
#
sub create_local_working_file
{
    my ($self, $dir, $name, $lines) = @_;

    my $filename = "$dir/$name";

    unless ($filename =~ /\.txt$/) {
        $filename .= '.txt';
    }

    unless (open(FH, ">$filename")) {
        $self->_error("Could not create local working file $filename - $!");
        return undef;
    }

    foreach my $line (@$lines) {
        print FH "$line\n";
    }

    close(FH);

    return $filename;
}

sub check_file_format
{
    my ($self, $file, $format) = @_;

    if ($format eq 'bed3') {
        return $self->check_file_format_bed3($file);
    } elsif ($format eq 'bed6') {
        return $self->check_file_format_bed6($file);
    } elsif ($format eq 'matrix') {
        #return $self->check_file_format_matrix($file);
        $self->_error("Matrix file format check not implemented yet!");
        return undef;
    } elsif ($format eq 'cageid') {
        #return $self->check_file_format_cageid($file);
        $self->_error("CAGE peak names file format check not implemented yet!");
        return undef;
    }

    $self->_error("Unknown file format '$format'");

    return undef;
}

sub check_file_format_bed3
{
    my ($self, $file) = @_;

    unless (open(FH, $file)) {
        $self->_error(
            "Error opening file '$file' to check BED 3-column format"
        );
        return undef;
    }

    while (my $line = <FH>) {
        chomp $line;

        if ($line =~ /^(\w+)\s+\d+\s+\d+/) {
            # Enforce that the chromosome column explicitly starts with 'chr'
            my $chrom = $1;
            unless ($chrom =~ /^chr/ && $chrom !~ /^chrom/) {
                $self->_error(
                    "BED file chromosome columns should start with"
                    . " 'chr', e.g.: chr1"
                );
                close(FH);
                return undef;
            }
        } else {
            $self->_error("Poorly formatted 3-column BED line:\n$line"
                . "\nShould be, e.g.: chr1\t1166845\t1167892");
            close(FH);
            return undef;
        }
    }

    close(FH);

    return 1;
}

sub check_file_format_bed6
{
    my ($self, $file) = @_;

    unless (open(FH, $file)) {
        $self->_error(
            "Error opening file '$file' to check BED 6-column format"
        );
        return undef;
    }

    while (my $line = <FH>) {
        chomp $line;

        if ($line =~ /^(\w+)\s+\d+\s+\d+\s+\S+\s+\w+\s+[+-]{1}(\s+|$)/) {
            # Enforce that the chromosome column explicitly starts with 'chr'
            my $chrom = $1;
            unless ($chrom =~ /^chr/ && $chrom !~ /^chrom/) {
                $self->_error("BED file chromosome columns should start with"
                    . " 'chr', e.g.: chr1");
                close(FH);
                return undef;
            }
        } else {
            $self->_error("Poorly formatted 6-column BED line:\n$line"
                . "\nShould be, e.g.: chr1\t1166845\t1167892\tname\t0\t+");
            close(FH);
            return undef;
        }
    }

    close(FH);

    return 1;
}

#
# Low-level error routine. Add latest error to internal error list and
# output to stderr (log file).
#
# Errors are now stored in the CGI::Application params rather than the
# state object.
# DJA 2012/10/17
#
#
sub _error
{
    my ($self, $error) = @_;

    return unless $error;

    #
    # Don't carp errors to log file yet. Do it in high level error routine
    # so that related errors are written in the correct order, see comments
    # above.
    # DJA 2012/10/17
    #
    carp "\nERROR: $error\n";

    #
    # Now put new errors on the front of the list so errors will be written
    # in the correct order. More general, higher level routine's errors are
    # added latter but should be written earlier.
    # DJA 2012/10/17
    #
    my @errors;
    push @errors, $error;

    my $cur_errors = $self->errors();
    if ($cur_errors) {
        push @errors, @$cur_errors;
    }

    $self->param('errors', \@errors);

    return @errors ? \@errors : undef;
}

#
# Low-level warning routine. Add latest warning to internal warning list and
# output to stderr (log file).
#
sub _warning
{
    my ($self, $warning) = @_;

    return unless $warning;

    carp "\nWarning: $warning\n";

    my @warnings;
    push @warnings, $warning;

    my $cur_warnings = $self->warnings();
    if ($cur_warnings) {
        push @warnings, @$cur_warnings;
    }

    $self->param('warnings', \@warnings);

    return @warnings ? \@warnings : undef;
}

sub _clean_tempfiles
{
    my $self = shift;

    my @tempfiles = glob(OPOSSUM_TMP_PATH . "/*");
    foreach my $file (@tempfiles) {
        unlink $file if -M $file > REMOVE_TEMPFILES_OLDER_THAN;
    }
}

sub _clean_resultfiles
{
    my $self = shift;

    my @files = glob(ABS_HTDOCS_RESULTS_PATH . "/*");

    foreach my $file (@files) {
        if (-M $file > REMOVE_RESULTFILES_OLDER_THAN) {
            if (-d $file) {
                # remove entire tree if directory
                rmtree($file, 0, 0);
            } elsif (-f $file) {
                # unlink if file
                unlink($file);
            }
        }
    }
}

sub _time
{
    my @months   = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    my @weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
    my ($second,     $minute,    $hour,
        $dayOfMonth, $month,     $yearOffset,
        $dayOfWeek,  $dayOfYear, $daylightSavings
    ) = localtime();
    my $year = 1900 + $yearOffset;
    my $theTime =
        "$hour:$minute:$second, $weekDays[$dayOfWeek] $months[$month] $dayOfMonth, $year";
    #print STDERR $theTime;
    return $theTime;
}

1;
