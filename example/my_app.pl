#!/usr/bin/env perl

use Dancer2;
use Dancer2::Plugin::OpenAPI;
use Path::Tiny;

openapi( url => path(__FILE__)->sibling('openapi.yaml') );

sub my_controller {
    return "Hello World!\n";
}

dance;
