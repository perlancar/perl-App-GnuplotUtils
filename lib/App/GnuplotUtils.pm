package App::GnuplotUtils;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

our %SPEC;

$SPEC{xyplot} = {
    v => 1.1,
    summary => "Plot XY dataset(s) using gnuplot",
    description => <<'_',

Example `input1.txt`, each line contains whitespace-separated values of X data
(number), Y data (number), X tic label (string, optional), Y tic label (string,
optional):

    1 1
    2 3
    3 5.5
    4 7.9
    6 11.5

Example using `xyplot` (one data-set):

    % xyplot < input1.txt

Example `input2.txt` (note that only the first dataset is allowed to set X and Y
labels [TODO: allow secondary axes/tic labels]):

    1 8
    2 12
    3 5
    4 4
    6 8

Using two datasets:

    % xyplot --dataset-file  input1.txt  --dataset-file  input2.txt \
             --dataset-color red         --dataset-color blue \
             --dataset-style linespoints --dataset-style points

Keywords: xychart, XY chart, XY plot

_
    args => {
        chart_title => {
            schema => 'str*',
        },
        field_delimiter => {
            summary => 'Supply field delimiter character in dataset file instead of the default whitespace(s)',
            schema => 'str*',
            cmdline_aliases => {d=>{}},
        },
        datasets => {
            summary => 'Dataset(s)',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'dataset',
            'schema' => ['array*', of=>'array*'],
        },
        dataset_files => {
            summary => 'Dataset(s) from file(s)',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'dataset_file',
            'schema' => ['array*', of=>'filename*'],
        },
        dataset_titles => {
            summary => 'Dataset title(s)',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'dataset_title',
            schema => ['array*', of=>'str*'],
        },
        dataset_styles => {
            summary => 'Dataset plot style(s)',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'dataset_style',
            schema => ['array*', of=>['str*', in=>[
                'lines', 'points', 'linespoints', 'dots', 'impluses', 'steps',
                'boxes', 'xerrorbars', 'yerrorbars', 'xyerrorbars',
                'xerrorlines', 'yerrorlines', 'xyerrorlines', 'boxerrorbars',
                'boxxyerrorbars', 'financebars', 'candlesticks', 'hbars',
                'hlines', 'vectors', 'circles', 'histograms',
            ]]],
        },
    },
    args_rels => {
        req_one => [qw/datasets dataset_files/],
    },
    deps => {
        prog => 'gnuplot',
    },
};
sub xyplot {
    require Chart::Gnuplot;
    require File::Slurper::Dash;
    require File::Temp;

    my %args = @_;

    my $fieldsep_re = qr/\s+/;
    if (defined $args{delimited}) {
        $fieldsep_re = qr/\Q$args{delimited}\E/;
    }

    my $chart;
    my ($tempfh, $tempfilename);
    my $n;
    if ($args{datasets}) {
        $n = $#{ $args{datasets} };
    } else {
        $n = $#{ $args{dataset_files} };
    }
    for my $i (0..$n) {
        my (@x, @y, @xticlabels, @yticlabels);
        if ($args{datasets}) {
            my $dataset = $args{datasets}[$i];
            @x          = map { $_->{x} }      @$dataset;
            @y          = map { $_->{y} }      @$dataset;
            @xticlabels = map { $_->{xlabel} } @$dataset;
            @yticlabels = map { $_->{ylabel} } @$dataset;
        } else {
            my $filename = $args{dataset_files}[$i];
            my $content = File::Slurper::Dash::read_text($filename);

            for my $line (split /^/m, $content) {
                chomp $line;
                my @f = split $fieldsep_re, $line;
                push @x, $f[0];
                push @y, $f[1];
                push @xticlabels, $f[2] if @f >= 3 && defined $f[2] && length $f[2];
                push @yticlabels, $f[3] if @f >= 4 && defined $f[3] && length $f[3];
            }
        }

        unless ($tempfh) {
            ($tempfh, $tempfilename) = File::Temp::tempfile();
            $tempfilename .= ".png";
            log_trace "Output filename: %s", $tempfilename;
            use DD;
            $chart = Chart::Gnuplot->new(
                dd(
                    output => $tempfilename,
                title => $args{chart_title} // "(No title)",
                xlabel => "x",
                ylabel => "y",
                (@xticlabels ? (xtics => {labels=>\@xticlabels, labelfmt=>'%s'}) : ()),
                    (@yticlabels ? (ytics => {labels=>\@yticlabels, labelfmt=>'%s'}) : ()),
                )
            );
        }

        my $dataset = Chart::Gnuplot::DataSet->new(
            xdata => \@x,
            ydata => \@y,
            title => $args{dataset_titles}[$i] // "(Untitled dataset #$i)",
            style => $args{dataset_styles}[$i] // 'points',
        );
        $chart->plot2d($dataset);
    }

    require Browser::Open;
    Browser::Open::open_browser("file:$tempfilename");

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
