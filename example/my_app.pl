#!/usr/bin/env perl

use lib '../lib';

use Dancer2;
use Dancer2::Plugin::Swagger2;

swagger2( url => path( dirname(__FILE__), 'swagger2.yaml' ) );

sub my_controller {
    return "Hello World!\n";
}

dance;
