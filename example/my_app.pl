#!/usr/bin/env perl

use Dancer2;
use Dancer2::Plugin::Swagger2;
use File::Basename ();
use File::Spec;

swagger2( url =>
      File::Spec->catfile( File::Basename::dirname(__FILE__), 'swagger2.yaml' )
);

sub my_controller {
    return "Hello World!\n";
}

dance;
