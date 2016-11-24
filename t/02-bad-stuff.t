use Test::More tests => 3;
use Plack::Test;
use HTTP::Request::Common;

{
    package t::PerlSwagger::TestApi;

    sub bool_test {
        my ($params, $response) = @_;
        $response->{body} = $params->{bool} == 1 ? 'true' : 'false';
    }

    sub throw_up {
        die;
    }
}

use PerlSwagger;
my $app = PerlSwagger->to_app(
    {
        swagger => '2.0',
        info    => {
            version => '1.0.0',
            title   => 'Test API',
        },
        paths   => {
            '/' => {
                get => {
                    description => 'Hello World!',
                    'x-handler' => 'foo', # does not exist
                    responses   => {
                        200 => {
                            description => 'Hello World!',
                            schema      => {
                                type => 'string',
                            },
                        },
                    },
                },
            },
            '/{bool}' => {
                parameters => [
                    {
                        name     => 'bool',
                        in       => 'path',
                        required => 1,
                        schema   => {
                            type => 'boolean',
                        },
                    }
                ],
                get => {
                    description => 'Boolean path argument',
                    'x-handler' => 't::PerlSwagger::TestApi->bool_test',
                    response    => {
                        200 => {
                            description => 'Return given path argument',
                            schema      => {
                                type => 'boolean',
                            },
                        },
                    },
                },
            },
            '/die' => {
                get => {
                    description => 'Die!',
                    'x-handler' => 't::PerlSwagger::TestApi->throw_up',
                    response    => {
                        500 => {
                            description => 'Everything ok (which is slightly paradoxical)',
                            schema      => {
                                type => 'string',
                            },
                        },
                    },
                },
            },
        },
    },
);

subtest 'Handle booleans in path' => sub {
    plan tests => 2;

    my $test = Plack::Test->create($app);
    my $res = $test->request(GET '/true');

    is($res->code, 200, 'Route handled correctly');
    is($res->content, 'true', 'Boolean interpreted correctly');
};

subtest 'Handle invalid handlers' => sub {
    plan tests => 1;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(GET '/');

    is($res->code, 501, 'Invalid handler fired HTTP 501');
};

subtest 'Route handlers throwing up' => sub {
    plan tests => 1;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(GET '/die');

    is($res->code, 500, 'Throwing up gives HTTP 500');
};
