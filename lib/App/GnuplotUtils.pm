package App::GnuplotUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

$SPEC{xyplot} = {
    v => 1.1,
    summary => "Plot XY dataset(s) using gnuplot",
    description => <<'_',

This utility is a wrapper for gnuplot to quickly generate a graph from the
command-line and view it using an image viewer program or a browser.

**Specifying dataset**

You can specify the dataset to plot directly from the command-line or specify
filename to read the dataset from.

To plot directly from the command-line, specify comma-separated list of X & Y
number pairs using `--dataset-data` option:

    % xyplot --dataset-data '1,1, 2,3, 3,5.5, 4,7.9, 6,11.5' ; # whitespaces are optional

To add more datasets, specify more `--dataset-data` options:

    % xyplot --dataset-data '1,1, 2,3, 3,5.5, 4,7.9, 6,11.5' \
             --dataset-data '1,4,2,4,3,2,4,9,5,3,6,6';         # will plot two lines

To add a title to your chart and every dataset, use `--dataset-title`:

    % xyplot --chart-title "my chart" \
             --dataset-title "foo" --dataset-data '1,1, 2,3, 3,5.5, 4,7.9, 6,11.5' \
             --dataset-title "bar" --dataset-data '1,4,2,4,3,2,4,9,5,3,6,6'

To specify dataset from files, use one or more `--dataset-file` options (or
specify the filenames as arguments):

    % xyplot --dataset-file ds1.txt --dataset-file ds2.txt
    % xyplot ds1.txt ds2.txt

`ds1.txt` should contain comma, or whitespace-separated list of X & Y numbers.
You can put one number per line or more.

 1 1
 2 3
 3 5.5
 4 7.9
 6 11.5
 8
 13.5
 9 14.2 10 14.8

To accept data from stdin, you can specify `-` as the filename:

 % tabulate-drug-concentration ... | xyplot -


**Seeing plot result**

`xyplot` uses <pm:Desktop::Open> to view the resulting plot. The module will
first find a suitable application, and failing that will use the web browser. If
you specify `--output-file` (`-o`), the plot is written to the specified image
file.


**Keywords**

xychart, XY chart, XY plot

_
    args => {
        chart_title => {
            schema => 'str*',
        },
        output_file => {
            schema => 'filename*',
            cmdline_aliases => {o=>{}},
            tags => ['category:output'],
        },
        overwrite => {
            schema => 'bool*',
            cmdline_aliases => {O=>{}},
            tags => ['category:output'],
        },

        field_delimiter => {
            summary => 'Supply field delimiter character in dataset file instead of the default whitespace(s) or comma(s)',
            schema => 'str*',
            cmdline_aliases => {d=>{}},
        },
        dataset_datas => {
            summary => 'Dataset(s)',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'dataset_data',
            'schema' => ['array*', of=>'str*'],
        },
        dataset_files => {
            summary => 'Dataset(s) from file(s)',
            'x.name.is_plural' => 1,
            'x.name.singular' => 'dataset_file',
            'schema' => ['array*', of=>'filename*'],
            pos => 0,
            slurpy => 1,
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
        req_one => [qw/dataset_datas dataset_files/],
    },
    deps => {
        prog => 'gnuplot',
    },
    links => [
        {url=>'prog:tchart', summary=>'From App::tchart Perl module, to quickly create ASCII chart, currently sparklines'},
        {url=>'prog:asciichart', summary=>'From App::AsciiChart Perl module, to quickly create ASCII chart'},
    ],
};
sub xyplot {
    require Chart::Gnuplot;
    require File::Slurper::Dash;
    require File::Temp;
    require Scalar::Util;

    my %args = @_;

    my $fieldsep_re = qr/\s*,\s*|\s+/s;
    if (defined $args{delimited}) {
        $fieldsep_re = qr/\Q$args{delimited}\E/;
    }

    my ($outputfilename);
    if (defined $args{output_file}) {
        $outputfilename = $args{output_file};
        if (-f $outputfilename && !$args{overwrite}) {
            return [412, "Not overwriting existing file '$outputfilename', use --overwrite (-O) to overwrite"];
        }
    } else {
        my $tempfh;
        ($tempfh, $outputfilename) = File::Temp::tempfile();
        $outputfilename .= ".png";
    }
    log_trace "Output filename: %s", $outputfilename;

    my $chart = Chart::Gnuplot->new(
        output => $outputfilename,
        title => $args{chart_title} // "(chart created by xyplot on ".scalar(localtime).")",
        xlabel => "x",
        ylabel => "y",
    );

    my $n;
    if ($args{dataset_datas}) {
        $n = $#{ $args{dataset_datas} };
    } else {
        $n = $#{ $args{dataset_files} };
    }

    my @datasets;
    for my $i (0..$n) {
        my (@x, @y);
        if ($args{dataset_datas}) {
            my $dataset = [split $fieldsep_re, $args{dataset_datas}[$i]];
            while (@$dataset) {
                my $item = shift @$dataset;
                warn "Not a number in --dataset-data: '$item'" unless Scalar::Util::looks_like_number($item);
                push @x, $item;

                warn "Odd number of numbers in --dataset-data" unless @$dataset;
                $item = shift @$dataset;
                warn "Not a number in --dataset-data: '$item'" unless Scalar::Util::looks_like_number($item);
                push @y, $item;
            }
        } else {
            my $filename = $args{dataset_files}[$i];
            my $content = File::Slurper::Dash::read_text($filename);

            chomp $content;
            my @numbers = split $fieldsep_re, $content;
            warn "Odd number of numbers in dataset file '$filename'" unless @numbers % 2 == 0;
            while (@numbers) {
                my $item = shift @numbers;
                warn "Not a number in dataset file '$filename': '$item'" unless Scalar::Util::looks_like_number($item);
                push @x, $item;

                $item = shift @numbers;
                warn "Not a number in dataset file '$filename': '$item'" unless Scalar::Util::looks_like_number($item);
                push @y, $item;
            }
        }

        my $dataset = Chart::Gnuplot::DataSet->new(
            xdata => \@x,
            ydata => \@y,
            title => $args{dataset_titles}[$i] // "(dataset #$i)",
            style => $args{dataset_styles}[$i] // 'linespoints',
        );
        push @datasets, $dataset;
    }
    $chart->plot2d(@datasets);

    if (defined $args{output_file}) {
        return [200];
    } else {
        require Desktop::Open;
        my $res = Desktop::Open::open_desktop("file:$outputfilename");
        if (defined $res && $res == 0) {
            return [200];
        } else {
            return [500, "Can't open $outputfilename"];
        }
    }
}

1;
#ABSTRACT: Utilities related to plotting data using gnuplot

=head1 DESCRIPTION

This distributions provides the following command-line utilities. They are
mostly simple/convenience wrappers for gnuplot:

# INSERT_EXECS_LIST


=cut
