# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as
# `perl Filter-Arguments.t'

#########################

use strict;
use Test::More tests => 2;

BEGIN {
	use_ok('Filter::Arguments')
};

my $result = eval {

    my @ARGV = qw( --solo --bool_default --a --b --c --d A --e B --f C --x --y --z --six );

    my $solo                : Argument(bool) = 1;
    my $bool_default        : Argument;
    my ($a,$b,$c)           : Arguments(bool);
    my ($d,$e,$f)           : Arguments(value);
    my ($x,$y,$z)           : Arguments(xbool);
    my ($three,$four,$five) : Arguments(value) = (3,4,5);
    my ($six,$seven,$eight) : Arguments(bool)  = ('SIX','SEVEN','EIGHT');
    # my $never_mind          : Argument(value) = 'x';

    my @result = (
        $solo,
        $bool_default,
        $a, $b, $c,
        $d, $e, $f,
        $x, $y, $z,
        $three, $four, $five,
        $six, $seven, $eight,
    );
    return join ',', @result;
};
is( $result, '0,1,1,1,1,A,B,C,0,0,1,3,4,5,0,SEVEN,EIGHT', 'mixed argument types' );


