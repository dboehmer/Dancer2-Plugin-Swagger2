package Dancer2::Plugin::OpenAPI;

use strict;
use warnings;

# ABSTRACT: A Dancer2 plugin for creating routes from an OpenAPI spec
# VERSION

use Dancer2::Plugin;
use JSON::Validator;
use JSON::Validator::OpenAPI;
use Module::Runtime 'use_module';

=head1 MIGRATING FROM DANCER1

If you've been using Dancer1 before you might know L<Dancer::Plugin::Swagger>.
Please note that that module's workflow is completely different! It is about
creating the spec from the app. The module described in this text is about
reading the spec and creating parts of the app for you.

=head1 SYNOPSIS

C<example/my_app.pl>:

{{ include('example/my_app.pl')->indent }}

C<example/swagger2.yaml>:

{{ include('example/openapi.yaml')->indent }}

Then on the terminal run:

    perl my_app.pl
    curl http://localhost:3000/api/welcome

You'll find the example files displayed above in the distribution and repository.

=head1 DEBUGGING

To see some more debug messages on STDERR set environment variable C<OPENAPI_DEBUG>
to a true value.

=cut

sub DEBUG { !!$ENV{OPENAPI_DEBUG} }

=head1 METHODS

=head2 openapi( url => $url, ... )

Import routes from OpenAPI file. Named arguments:

=over

=item * C<url>: URL to passed to L<Swagger2> module

=item * C<controller_factory>: custom callback generator/finder that returns callbacks to routes

=item * C<create_options_route>: autocreate additional route replying to OPTIONS requests based on Swagger data

=item * C<validate_spec>: boolish value (default: true) telling if Swagger2 file shall be validated by official Swagger specification

=item * C<validate_requests>: boolish value (default: same as C<validate_spec>) telling if HTTP requests shall be validated by loaded specification (needs C<validate_spec> to be true)

=item * C<validate_responses>: boolish value (default: same as C<validate_spec>) telling if HTTP responses shall be validated by loaded specification (needs C<validate_spec> to be true)

=back

=cut

register openapi => sub {
    my ( $dsl, %args ) = @_;
    my $conf = plugin_setting;

    ### get arguments/config values/defaults ###

    my $controller_factory =
         $args{controller_factory} || \&_default_controller_factory;
    my $url = $args{url} or die "argument 'url' missing";
    my $create_options_route =
        exists $args{create_options_route}   ? !!$args{create_options_route}
      : exists $conf->{create_options_route} ? !!$conf->{create_options_route}
      :                                        '';
    my $validate_requests =
        exists $args{validate_requests}   ? !!$args{validate_requests}
      : exists $conf->{validate_requests} ? !!$conf->{validate_requests}
      :                                     1;
    my $validate_responses =
        exists $args{validate_responses}   ? !!$args{validate_responses}
      : exists $conf->{validate_responses} ? !!$conf->{validate_responses}
      :                                      1;

    # depcrecation notice
    if ( exists $args{validate_spec} or exists $conf->{validate_spec} ) {
        warn "Config key 'validate_spec' is not supported anymore";
    }

    # validate $url against OpenAPI spec
    # TODO is this step done implicitly in the next step?
    my $openapi =
      JSON::Validator->new->schema(JSON::Validator::OpenAPI::SPECIFICATION_URL);
    $openapi->validate($url);

    my $api = JSON::Validator->new->schema($url);

    my $basePath = $api->schema->get('/basePath');
    my $paths    = $api->schema->get('/paths');      # TODO might be undef?

    while ( my ( $path => $path_spec ) = each %$paths ) {
        my $dancer2_path = $path;

        $basePath and $dancer2_path = $basePath . $dancer2_path;

        # adapt Swagger2 syntax for URL path arguments to Dancer2 syntax
        # '/path/{argument}' -> '/path/:argument'
        $dancer2_path =~ s/\{([^{}]+?)\}/:$1/g;

        my @http_methods = sort keys %$path_spec;

        if ($create_options_route) {
            my $allow_methods = join ', ' => 'OPTIONS', map uc, @http_methods;
            $dsl->options(
                $dancer2_path => sub {
                    $dsl->headers(
                        Allow => $allow_methods,    # RFC 2616 HTTP/1.1
                        'Access-Control-Allow-Methods' => $allow_methods, # CORS
                        'Access-Control-Max-Age'       => 60 * 60 * 24,
                    );
                },
            );
        }

        for my $http_method (@http_methods) {
            my $method_spec = $path_spec->{ $http_method };
            my $coderef = $controller_factory->(
                $method_spec, $http_method, $path, $dsl, $conf, \%args
            ) or next;

            DEBUG and warn "Add route $http_method $dancer2_path";

            my $params = $method_spec->{parameters};

            # Dancer2 DSL keyword is different from HTTP method
            $http_method eq 'delete' and $http_method = 'del';

            $dsl->$http_method(
                $dancer2_path => sub {
                    my @args = @_;

                    if ($validate_requests) {
                        my @errors = _validator()->validate_request( $dsl->app, $method_spec );

                        if (@errors) {
                            DEBUG and warn "Invalid request: @errors\n";
                            $dsl->status(400);
                            return { errors => [ map { "$_" } @errors ] };
                        }
                    }

                    my $result = $coderef->(@args);

                    if ($validate_responses) {
                        my @errors = _validator()->validate_response( $dsl->app, $method_spec,
                            $dsl->response->status, $result );

                        if (@errors) {
                            DEBUG and warn "Invalid response: @errors\n";
                            $dsl->status(500);

                            # TODO hide details of server-side errors?
                            return { errors => [ map { "$_" } @errors ] };
                        }
                    }

                    return $result;
                }
            );
        }
    }
};

register_plugin;

=head2 default_controller_factory

Default method for finding a callback for a given C<operationId>. Can be
overriden by the C<controller_factory> argument to C<swagger2> or config option.

The default uses the C<controller> argument/config option or the name of
the app (possibly with C<::Controller> appended). If the C<operationId>
looks like a Perl module the module name is tried under the namespace
mentioned above and as a top level module name.

The module warns as long as controller modules or methods can't be found
and returns a coderef on the first match.

=cut

sub _default_controller_factory {
    # TODO simplify argument list
    my ( $method_spec, $http_method, $path, $dsl, $conf, $args, ) = @_;

    # from Dancer2 app
    my $namespace = $args->{controller} || $conf->{controller};
    my $app = $dsl->app->name;

    # from Swagger2 file
    my $module;
    my $method = $method_spec->{operationId};
    if ( $method =~ s/^(.+)::// ) {    # looks like Perl module
        $module = $1;
    }

    # different candidates possibly reflecting operationId
    my @controller_candidates = do {
        if ($namespace) {
            if ($module) { $namespace . '::' . $module, $module }
            else         { $namespace }
        }
        else {
            if ($module) {
                (                      # parens for better layout by Perl::Tidy
                    $app . '::' . $module,
                    $app . '::Controller::' . $module,
                    $module,           # maybe a top level module name?
                );
            }
            else { $app, $app . '::Controller' }
        }
    };

    # check candidates
    for my $controller (@controller_candidates) {
        local $@;
        if ( ! eval { use_module( $controller ); 1; } ) {
            if ( $@ && $@ =~ m/^Can't locate / ) {    # module doesn't exist
                DEBUG and warn "Can't load '$controller'";

                # don't do `next` here because controller could be
                # defined in other package ...
            }
            else {    # module doesn't compile
                die $@;
            }
        }

        if ( my $cb = $controller->can($method) ) {
            return $cb;    # confirmed candidate
        }
        else {
            DEBUG and warn "Controller '$controller' can't '$method'";
        }
    }

    # none found
    warn "Can't find any handler for operationId '$method_spec->{operationId}'";
    return;
}

my $validator;
sub _validator { $validator ||= JSON::Validator::OpenAPI->new }

=head1 SEE ALSO

=over

=item * L<Mojolicious::Plugin::Swagger2> A similar plugin for the L<Mojolicious> Web framework

=item * L<http://swagger.io/>: Website of the Swagger alias OpenAPI Specification

=back

=head1 ACKNOWLEDGEMENT

This software has been developed with support from L<STRATO|https://www.strato.com/>.
In German: Diese Software wurde mit Unterstützung von L<STRATO|https://www.strato.de/> entwickelt.

=cut

1;
