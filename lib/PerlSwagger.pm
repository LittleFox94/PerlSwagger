package PerlSwagger;

use JSON;
use YAML 'LoadFile', 'DumpFile';

use PerlSwagger::PathBuilder;

our $VERSION = 0.001;

sub to_app {
    my ($package, $spec) = @_;

    my $spec_hash = ref($spec) eq 'HASH' ? $spec : LoadFile($spec);
    $spec_hasn    = _resolve_references($spec_hash);

    my $paths     = $spec_hash->{paths};

    my @routes = ();
    for my $path (keys %$paths) {
        push(@routes, PerlSwagger::PathBuilder->build($spec_hash->{basePath} . $path, $paths->{$path}));
    }

    return sub {
        my $env    = shift;

        my $response = {
            status  => 500,
            body    => [ 'Server error' ],
            headers => [
                'Content-Type' => 'text/plain',
            ],
        };

        my $route_found = 0;

        for my $route (@routes) {
            if(lc $route->{method} eq lc $env->{REQUEST_METHOD}) {
                if($env->{PATH_INFO} =~ $route->{path}) {
                    $route_found = 1;
                    _do_route($route, $env, $response);
                    last;
                }
            }
        }

        if($route_found == 0) {
            $response->{status} = 404;
            $response->{body}   = [ 'Not found' ];
        }

        return [
            $response->{status},
            $response->{headers},
            $response->{body},
        ];
    };
}

sub _do_route {
    my ($route, $env, $response) = @_;

    my $input = _read_input($env->{'psgi.input'}, $env->{CONTENT_LENGTH});

    my $input_data = $env->{CONTENT_TYPE} =~ m~^application/json~   ? JSON::decode_json($input)
                   : $env->{CONTENT_TYPE} =~ m~^application/x-yaml~ ? Load($input)
                   : undef;

    my $params = {};

    if(defined($input_data)) {
        $params = $route->{parameters}->filter_params($input_data);
    }

    my @path_params = @{$route->{parameters}->{path_params}};
    if(@path_params) {
        my @params = ($env->{PATH_INFO} =~ $route->{path});

        my $i = 0;
        for my $param (@path_params) {
            if($param->{schema}->{type} ne 'boolean') {
                $params->{$param->{name}} = $params[$i++];
            }
            else {
                $params->{$param->{name}} = $params[$i++] eq 'true';
            }
        }
    }

    if(!$route->{parameters}->check_required($params)) {
        $response->{status} = 422;
        $response->{body}   = [ 'Required arguments are missing' ];
        return;
    }

    if($route->{handler}) {
        $response->{status} = 200;
        $response->{body}   = undef;

        local $@;
        eval {
            my $ret = $route->{handler}->($params, $response);

            if(!defined($response->{body})) {
                $response->{body} = JSON::encode_json($ret);
                push(@{$response->{headers}}, 'Content-Type' => 'application/json');
            }

            if(ref $response->{body} eq '') {
                $response->{body} = [ $response->{body} ];
            }
        };

        if($@) {
            $response->{status}  = 500;
            $response->{body}    = [ 'Server error' ],
            $response->{headers} = [
                'Content-Type' => 'text/plain',
            ];

            warn 'Route threw up: ' . $@;
        }
    }
    else {
        warn 'No handler for route "' . uc($route->{method}) . ' ' . $route->{orig_path} . '"';
    }
}

sub _read_input {
    my ($fh, $cl) = @_;

    $fh->seek(0, 0);
    $fh->read(my $content, $cl, 0);
    $fh->seek(0, 0);

    return $content;
}

sub _resolve_references {
    my ($hash) = @_;

    my $get_hash_deep = sub {
        my (@parts) = @_;

        my $current = $hash;
        for my $part (@parts) {
            $current = $current->{$part};
        }

        return $current;
    };

    my $resolve_sub; $resolve_sub = sub {
        my ($sub_hash) = @_;

        my $transformed = {};

        for my $key (keys %$sub_hash) {
            if($key eq '$ref') {
                my $locator = $sub_hash->{$key};

                if($locator =~ m~#/.*~) {
                    my (undef, @parts) = split(qr~/~, $locator);
                    return $get_hash_deep->(@parts);
                }
            }
            else {
                my $value = $sub_hash->{$key};

                if(ref($value) eq 'HASH') {
                    $value = $resolve_sub->($value);
                }
                elsif(ref($value) eq 'ARRAY') {
                    $value = [
                        map {
                            my $res = $_;

                            if(ref($_) eq 'HASH') {
                                $res = $resolve_sub->($_);
                            }

                            $res;
                        } @$value
                    ];
                }

                $transformed->{$key} = $value;
            }
        }

        return $transformed;
    };

    return $resolve_sub->($hash);
}

1;
__END__
=pod

=head1 NAME

PerlSwagger - Swagger 2.0 API Service Framework

=head1 SYNOPSIS

=head2 app.psgi

    use lib ".";
    use PerlSwagger;
    PerlSwagger->to_app('swagger.yml');

=head2 swagger.yml

    ---
    swagger: "2.0"
    info:
      version: "1.0.0"
      title: "Simplest possible example"
      description: "Just the simplest possible example"
    consumes:
      - "application/json"
    produces:
      - "application/json"
    paths:
      /:
        get:
          description: "Hello World, what else?"
          x-handler: "example::API->index"
          responses:
            200:
              description: "All ok, Hello World!"
              schema:
                type: "object"
                  properties:
                    message:
                    type: "string"

=head2 example/API.pm

    package example::API;

    sub index {
        return {
            message => "test",
        };
    }

    1;

=head1 DESCRIPTION

PerlSwagger is a simple to use web framework for RESTful webservices described with an OpenAPI 2.0 (formerly known as Swagger 2.0) specification.

The framework parses the specification on startup and creates a PSGI compatible app from it, which can be used with plackup.

Before calling any route handler, it checks the given parameters and only gives valid ones to the handler. Simple handlers don't have to know they are running as a webservice, as they just get a HashRef containing all the parameters and may return a HashRef as response body.

Handlers for routes are specified with the "x-handler" key in specification, which is something like this "My::Api::Code->handler_sub".

=head1 METHODS

=head2 to_app

    my $plack_app = to_app($spec_filepath);

Create plack application from swagger spec file.

=head1 LINKS

=over 4

=item GitHub repository:

https://github.com/LittleFox94/PerlSwagger

=item OpenAPI 2.0 specification:

https://github.com/OAI/OpenAPI-Specification/blob/master/versions/2.0.md

=back

=cut
