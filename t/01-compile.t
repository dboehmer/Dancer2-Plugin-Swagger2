#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most tests => 1;

bail_on_fail;
use_ok 'Dancer2::Plugin::Swagger2';
