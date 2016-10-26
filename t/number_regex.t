#!/usr/bin/env perl

use strict;
use warnings;

use Dancer2::Plugin::Swagger2;
use Test::More;

sub is_number {
    my $number = shift;

    like(
        $number => Dancer2::Plugin::Swagger2->RE_JSON_NUMBER,
        "'$number' is a number"
    );
}

sub isnt_number {
    my $number = shift;

    unlike(
        $number => Dancer2::Plugin::Swagger2->RE_JSON_NUMBER,
        "'$number' is no number"
    );
}

is_number("123");
is_number("0123");
is_number("-123");
is_number("123.456");
is_number("-123.456");
is_number("1.2e3");
is_number("1.2e-3");
is_number("1.2e+3");
is_number("1.23e0");

isnt_number("");
isnt_number(".123");
isnt_number("1.2.3");
isnt_number("e");
isnt_number("123e");
isnt_number("123e+-0");

done_testing;
