#================================================================== -*-perl-*-
#
# Filter::Arguments
#
# DESCRIPTION
#
#  A simple way to configure and read your command line arguments.
#
# AUTHOR
#   Dylan Doxey <dylan.doxey@gmail.com>
#
# COPYRIGHT
#   Copyright (C) 2009 Dylan Doxey
#
#   This library is free software; you can redistribute it and/or modify it
#   under the same terms as Perl itself, either Perl version 5.8.0 or, at
#   your option, any later version of Perl 5 you may have available.
#
#=============================================================================

package Filter::Arguments;
our $VERSION = '0.07';

use 5.0071;
use strict;
use warnings FATAL => 'all';
use Filter::Simple;
use Template;

my $Arguments_Regex = qr{
    (
        my \s+ [(]? ( \s* \$\w+ (?: \s* [,] \s* \$ \w+ )* ) \s* [)]?
        \s* : \s*
        Arguments?
        (?: [(] \s* ( \w+ ) \s* [)] )? \s*
        (?: = \s* ( .+? ) )?
        ;
    )
}msx;

my $template_value = <<'VALUE';
    if ( $arg eq '--[% name %]' ) {
        $[% name %] = shift @args;
        next ARG;
    }
VALUE

my $template_bool = <<'BOOL';
    if ( $arg eq '--[% name %]' ) {
        $[% name %] = $[% name %] ? 0 : 1;
        next ARG;
    }
BOOL

my $template_xbool = <<'VALUE';
    if ( $arg eq '--[% name %]' ) {
        $[% name %] = $[% name %] ? 0 : 1;
        [% FOREACH other_name IN other_names %]$[% other_name %] = $[% name %] ? 0 : 1;
        [% END %]next ARG;
    }
VALUE

my $template_arguments = <<'ARGUMENTS';
    [% FOREACH declaration IN declarations %]
        [% declaration %]
    [% END %]
    ARGUMENTS:
    {
        my @args = @ARGV;
        my $usage = "[% usage %]";
        ARG:
        while ( my $arg = shift @args ) {
            [% stack %]
            print $usage;
            die "unrecognized argument: $arg\n";
        }
    }
ARGUMENTS

FILTER_ONLY
	code_no_comments => sub {

        my $line_count = 1;
        my %arguments;
        my @lines;
        my @usage_lines;
        my @declarations;
        my @argument_stack;

        while ( m/$Arguments_Regex/msxg ) {

            my $line           = $1;
            my $names          = $2;
            my $type           = $3 || 'bool';
            my $initialization = $4;

            my $declaration
                = $names =~ m/[,]/msx
                ? "my ($names)"
                : "my $names";

            if ( $initialization ) {

                # note: observation indicates no special handling is
                # needed for multiline initializations and line number fixing
                $declaration .= " = $initialization;";
            }
            else {
                $declaration .= ';';
            }

            $line_count += $line =~ s/(?:\r?\n)/\n/msxg;

            push @declarations, $declaration;
            push @lines, $line;

            for my $name (split /,/, $names) {

                $name =~ s{ (?: \A \s* | \s* \z) }{}msxg;
                $name =~ s{ \A \$ }{}msxg;

                push @{ $arguments{$type} }, $name;
            }
        }

        my %names;
        my $template = Template->new();

        TYPE:
        for my $type (keys %arguments) {

            my $names_ra = $arguments{$type};

            if ( $type eq 'bool' || $type eq 'value' ) {

                NAME:
                for my $name (@{ $names_ra }) {

                    next NAME
                        if $names{$name};

                    my $usage_line
                        = $type eq 'bool'
                        ? "--$name"
                        : "--$name <value>";

                    push @usage_lines, $usage_line;

                    $names{$name} = 1;

                    my $template_text
                        = $type eq 'bool'
                        ? $template_bool
                        : $template_value;

                    my $code;
                    my %name_for = ( name => $name );
                    $template->process( \$template_text, \%name_for, \$code );

                    push @argument_stack, $code;
                }
                next TYPE;
            }
            if ( $type eq 'xbool' ) {

                my $usage_line = '';

                NAME:
                for my $name (@{ $names_ra }) {

                    next NAME
                        if $names{$name};

                    $names{$name} = 1;

                    $usage_line .= "$name|";

                    my @other_names = grep { $_ ne $name } @{ $names_ra };

                    my $code;
                    my %names = ( name => $name, other_names => \@other_names );
                    $template->process( \$template_xbool, \%names, \$code );
                    push @argument_stack, $code;
                }

                if ( $usage_line ) {
                    chop $usage_line;
                    push @usage_lines, "--$usage_line";
                }

                next TYPE;
            }
        }

        my $usage
            = @usage_lines
            ? ( 'usage:\n$0 [options]\n    '
                . ( join '\n    ', @usage_lines )
                . '\n'
              )
            : "";

        my $argument_code;

        my %args = (
            declarations => \@declarations,
            stack        => ( join "", @argument_stack ),
            usage        => $usage,
        );
        $template->process( \$template_arguments, \%args, \$argument_code );

        ## print 'x' . '=' x 40 . "\n$argument_code\n" . 'x' . '=' x 40 . "\n";

        # remove newlines to keep inserted code to
        # one line and prevent line number problems
        $argument_code =~ s{\n}{ }msxg;

        # add some lines in case of multiline declarations
        $argument_code .= "\n" x --$line_count;

        while ( my $line = shift @lines ) {

            $line =~ s{([\$\(\)])}{\\$1}msxg;

            if ( @lines == 0 ) {
                s{$line}{$argument_code};
            }
            else {
                s{$line}{};
            }
        }
	};

1;

__END__

=pod

=head1 NAME

Filter::Arguments - Configure and read your command line arguments from @ARGV.

=head1 SYNOPSIS

 use Filter::Arguments;

 my $solo                : Argument(bool) = 1;
 my $bool_default        : Argument;
 my ($a,$b,$c)           : Arguments(bool);
 my ($d,$e,$f)           : Arguments(value);
 my ($x,$y,$z)           : Arguments(xbool);
 my ($three,$four,$five) : Arguments(value) = (3,4,5);
 my ($six,$seven,$eight) : Arguments(bool)  = ('SIX','SEVEN','EIGHT');

 my $multiline : Argument(value) = <<END_ML;
    my multi-line
    initial value
 END_ML

 my @result = (
     $solo,
     $bool_default,
     $a, $b, $c,
     $d, $e, $f,
     $x, $y, $z,
     $three, $four, $five,
     $six, $seven, $eight,
     $multiline,
 );

 print join ',', @result;

if invoked as:
 $ script.pl --solo --a --b --c --d A --e B --f C --x --y --z --six

will print:

 0,,1,1,1,A,B,C,0,0,1,3,4,5,0,SEVEN,EIGHT,my multi-line
 initial value

=head1 DESCRIPTION

Here is a simple way to configure and parse your command line arguments from @ARGV.
If an unrecognized argument is given then a basic usage statement is printed
and your program dies.

=head2 ARG TYPES

=over

=item bool (default)

This type of argument is either 1 or 0. If it is initialized to 1, then
it will flip-flop to 0 if the arg is given.

=item xbool

The 'x' as in XOR boolean. Only one of these booleans can be true. The
flip-flop behavior also applies to these also. So you may initialize them
however, but if one is set then the others are set to the opposite value
of the one that is set.

=item value

This type takes on the value of the next argument presented.

Example:

 my $noodle : Argument(value) = 'egg';

The variable $noodle will be 'egg', unless the argument sequence:

 --noodle instant

Where $noodle will then be 'instant'.

=back

=head1 TODO

=over

=item regex type argument

This would allow arguments matching a pattern such as:

 my @words   : Argument(regex) = qr{\A \w+ \z}xms;
 my @numbers : Argument(regex) = qr{\A \d+ \z}xms;

The permitted argument sequence:

 program.pl 12345 4321 horse

=item multivalue arguments

This would allow:

 my @words : Argument(value);

Where the permitted argument sequence would be:

 program.pl --words horse cow pig

=item required argument

 my $required ! Argument(value);

Where the program will die with usage statement if 
this option is not provided.

=back

=head1 DEPENDENCIES

=over

=item Template

=item Filter::Simple

=back

=head1 BUGS

Don't put comments at the end of an Argument line.

Example:

 my $a :Argument = 1; # comment

This will result in an 'Invalid SCALAR attribute' compile time error.

Version 0.06 intends to resolve the line numbering bug.

=head1 AUTHOR

Dylan Doxey E<lt>dylan.doxey@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Dylan Doxey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
