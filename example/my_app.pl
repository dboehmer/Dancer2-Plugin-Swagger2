#!/usr/bin/env perl

use Dancer2;
use Dancer2::Plugin::Swagger2;
use Path::Tiny;

swagger2( url => path(__FILE__)->sibling('swagger2.yaml') );

sub my_controller {
    return "Hello World!\n";
}

dance;
