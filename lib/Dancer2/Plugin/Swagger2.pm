package Dancer2::Plugin::Swagger2;

use Dancer2 ':syntax';
use Dancer2::Plugin;
use Module::Load;
use Swagger2;

=head1 Dancer2::Plugin::Swagger2

=head2 Debugging

To see some more debug messages on STDOUT set environment variable C<SWAGGER2_DEBUG>
to a true value.

=cut

sub DEBUG { !!$ENV{SWAGGER2_DEBUG} }

=head2 swagger2(url => $url, (cb => \&cb)?)

Import routes from Swagger file. Named arguments:

=over

=item C<url>: URL to passed to C<Swagger2> module

=item C<cb>: custom callback generator/finder that returns callbacks to routes

=item C<validate>: boolish value (default: true) telling if Swagger2 file shall be validated

=back

=cut

register swagger2 => sub {
    my ( $dsl, %args ) = plugin_args(@_);
    my $conf = plugin_setting;

    # get arguments/config values/defaults
    my $cb = $args{cb} || $conf->{cb} || \&default_cb;
    my $url = $args{url} or die "argument 'url' missing";
    my $validate =
        exists $args{validate}   ? !!$args{validate}
      : exists $conf->{validate} ? !!$conf->{validate}
      :                            1;

    # parse Swagger2 file
    my $swagger2 = Swagger2->new($url)->expand;

    if ($validate) {
        my @errors = $swagger2->validate;
        @errors and die join "\n" => "Swagger2: Invalid spec:", @errors;
    }

    my $basePath = $swagger2->api_spec->get('/basePath');
    my $paths    = $swagger2->api_spec->get('/paths');    # TODO might be undef?

    while ( my ( $path => $path_spec ) = each $paths ) {
        my $dancer2_path = $path;
        $dancer2_path =~ s/\{([^{}]+?)\}/:$1/g;

        while ( my ( $method => $method_spec ) = each %$path_spec ) {
            my $coderef = $cb->( $conf, $dsl, \%args, $method_spec ) or next;

            $basePath and $dancer2_path = $basePath . $dancer2_path;

            DEBUG and warn "Add route $method $dancer2_path";

            my $params = $method_spec->{parameters};

            $dsl->$method(
                $dancer2_path => sub {

                    # TODO validate input

                    my $response = $coderef->();

                    # TODO validate output

                    return $response;
                }
            );
        }
    }
};

=head2 default_cb

Default method for finding a callback for a given C<operationId>. Can be
overriden by the C<cb> argument to C<swagger2> or config option.

The default uses the C<controller> argument/config option or the name of
the app (possibly with C<::Controller> appended). If the C<operationId>
looks like a Perl module the module name is tried under the namespace
mentioned above and as a top level module name.

The module warns as long as controller modules or methods can't be found
and returns a coderef on the first match.

=cut

sub default_cb {
    my ( $conf, $dsl, $args, $method_spec ) = @_;

    # from Dancer2 app
    my $set = $args->{controller} || $conf->{controller};
    my $app = $dsl->app->name;

    # from Swagger2 file
    my $module;
    my $method = $method_spec->{operationId};
    if ( $method =~ s/^(.+)::// ) {    # looks like Perl module
        $module = $1;
    }

    # different candidates possibly reflecting operationId
    my @candidates = do {
        if ($set) {
            if ($module) { $set . '::' . $module, $module }
            else         { $set }
        }
        else {
            if ($module) {             # parens for better layout by Perl::Tidy
                (
                    $app . '::' . $module,
                    $app . '::Controller::' . $module,
                    $module,           # maybe a top level module name?
                );
            }
            else { $app, $app . '::Controller' }
        }
    };

    # check candidates
    for my $controller (@candidates) {
        eval { load $controller };
        if ($@) {
            if ( $@ =~ m/^Can't locate / ) {    # module doesn't exist
                DEBUG and warn "Controller '$controller' doesn't exist";
                next;
            }
            else {                              # module doesn't compile
                die $@;
            }
        }

        my $cb = $controller->can($method);

        if ( not $cb ) {
            DEBUG and warn "Controller '$controller' can't '$method'";
            next;
        }

        # confirmed candidate, return coderef to controller method
        $cb and return $cb;
    }

    # none found
    warn "Can't find any handler for operationId '$method_spec->{operationId}'";
    return;
}

register_plugin;

1;
