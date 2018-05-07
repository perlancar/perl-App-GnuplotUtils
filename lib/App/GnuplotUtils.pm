package App::GnuplotUtils;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

our %SPEC;

$SPEC{xyplot} = {
    v => 1.1,
    summary => "Plot XY data using gnuplot",
    description => <<'_',

Example `input.txt`:

    1 1
    2 3
    3 5.5
    4 7.9
    6 11.5

Example using `xyplot`:

    % xyplot < input.txt

Keywords: xychart, XY chart, XY plot

_
    args => {
        delimiter => {
            summary => 'Supply field delimiter character instead of the default whitespace(s)',
            schema => 'str*',
            cmdline_aliases => {d=>{}},
        },
        # XXX more options
    },
    deps => {
        prog => 'gnuplot',
    },
};
sub xyplot {
    my %args = @_;

    my $fieldsep_re = qr/\s+/;
    if (defined $args{delimited}) {
        $fieldsep_re = qr/\Q$args{delimited}\E/;
    }

    my (@x, @y);
    while (<STDIN>) {
        chomp;
        my @f = split $fieldsep_re, $_;
        push @x, $f[0];
        push @y, $f[0];
    }

    require Chart::Gnuplot;
    require File::Temp;
    my ($fh, $filename) = File::Temp::tempfile();
    $filename .= ".png";
    log_trace "Output filename: %s", $filename;
    my $chart = Chart::Gnuplot->new(
        output => $filename,
        title => "(No title)",
        xlabel => "x",
        ylabel => "y",
    );
    my $dataset = Chart::Gnuplot::DataSet->new(
        xdata => \@x,
        ydata => \@y,
        title => "(Untitled dataset)",
        style => "points", # "linespoints",
    );
    $chart->plot2d($dataset);

    require Browser::Open;
    Browser::Open::open_browser("file:$filename");

    [200];
}

1;
#ABSTRACT: Utilities related to plotting data using gnuplot

=head1 DESCRIPTION

This distributions provides the following command-line utilities. They are
mostly simple/convenience wrappers for gnuplot:

# INSERT_EXECS_LIST


=head1 SEE ALSO

=cut
