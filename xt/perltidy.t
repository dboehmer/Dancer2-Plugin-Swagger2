use strict;
use warnings;

use FindBin;
use Test::PerlTidy;
run_tests(
    perltidyrc => "$FindBin::Bin/../.perltidyrc",
    exclude    => [ qr{\.build/}, qr{Dancer2-Plugin-OpenAPI-.+/} ],
);
