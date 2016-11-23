package PerlSwagger;

use JSON;
use YAML 'LoadFile';

use PerlSwagger::PathBuilder;

our $VERSION = 0.001;

sub to_app {
    my ($package, $spec) = @_;

    my $spec_hash = LoadFile($spec);
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

    my $input = _read_input($env->{'psgi.input'});

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
        }
    }
    else {
        warn 'No handler for route "' . uc($route->{method}) . ' ' . $route->{orig_path} . '"';
    }
}

sub _read_input {
    my ($fh) = @_;

    my $buffer_size = 8192;
    my $read_size   = 0;
    my $data        = '';

    do {
        my $buffer;
        $read_size = $fh->read($buf, $buffer_size);

        $data .= $buffer;
    } while($read_size == $buffer_size);
}

1;
__END__
=pod

=head1 NAME

PerlSwagger - Swagger 2.0 API Service Framework

=head1 SYNOPSIS

    use PerlSwagger;

    PerlSwagger->to_app('swagger.yml');

=head1 METHODS

=head2 to_app

    my $plack_app = to_app($spec_filepath);

Create plack application from swagger spec file.

=cut
