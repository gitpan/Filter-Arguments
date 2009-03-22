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
our $VERSION = '0.05';

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

[% FOREACH declaration IN declarations %]    [% declaration %]
[% END %]    ARGUMENTS:
    {
        my @args = @ARGV;
        ARG:
        while ( my $arg = shift @args ) {
[% stack %]            die "unrecognized argument: $arg";
        }
    }
ARGUMENTS

FILTER_ONLY
	code_no_comments => sub {

        my %arguments;
        my @lines;
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

            $declaration 
                .= $initialization
                ? " = $initialization;"
                : ';';

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

                NAME:
                for my $name (@{ $names_ra }) {

                    next NAME
                        if $names{$name};

                    $names{$name} = 1;

                    my @other_names = grep { $_ ne $name } @{ $names_ra };

                    my $code;
                    my %names = ( name => $name, other_names => \@other_names );
                    $template->process( \$template_xbool, \%names, \$code );
                    push @argument_stack, $code;
                }
                next TYPE;
            }
        }

        my $argument_code;
        my %args = ( 
            declarations => \@declarations,
            stack        => join "", @argument_stack,
        );
        $template->process( \$template_arguments, \%args, \$argument_code );

        $argument_code =~ s{\n}{ }msxg;

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

 my @result = (
     $solo,
     $bool_default,
     $a, $b, $c,
     $d, $e, $f,
     $x, $y, $z,
     $three, $four, $five,
     $six, $seven, $eight,
 );
    
 print join ',', @result;

if invoked as:
 $ script.pl --solo --a --b --c --d A --e B --f C --x --y --z --six

will print: 

 0,,1,1,1,A,B,C,0,0,1,3,4,5,0,SEVEN,EIGHT

=head1 DESCRIPTION

Here is a simple way to configure and parse your command line arguments from @ARGV.

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

=back

=head1 DEPENDENCIES

Template
Filter::Simple

=head1 BUGS

Line numbers will be inaccurate if you have an Argument 
declaration which spans multiple lines.

Example:

 my $a
 : Argument = 1;

Line numbers in warnings and errors will be one less than true.

Also, don't put comments at the end of an Argument line.

Example:

 my $a :Argument = 1; # comment

This will result in an 'Invalid SCALAR attribute' compile time error.

=head1 AUTHOR

Dylan Doxey E<lt>dylan.doxey@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Dylan Doxey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut
