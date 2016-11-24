use strict;
use warnings;
use utf8;

{
    package t::PerlSwagger::TestApi;

    use List::Util 'max';

    our $PETS = [
        {
            id   => 1,
            name => 'Terry',
            tag  => 'cat, black, male',
        },
    ];


    sub retrieve_pets {
        return $PETS;
    }

    sub retrieve_pet_by_id {
        my ($params, $response) = @_;

        my $id   = $params->{id};
        my @pets = grep { $_->{id} == $id } @$PETS;

        if(@pets == 0) {
            $response->{status} = 404;
            $response->{body}   = '';
            return;
        }
        elsif(@pets > 1) {
            die('Multiple pets with the same ID found');
        }

        return $pets[0];
    }

    sub add_pet {
        my ($params, $response) = @_;

        my $dataset = {
            name => $params->{name},
            tag  => $params->{tag},
            id   => (max map { $_->{id} } @$PETS ) + 1,
        };

        push(@$PETS, $dataset);

        return $dataset;
    }
}

use Test::More tests => 8;

use Plack::Test;
use HTTP::Request::Common 'GET', 'POST', 'DELETE';
use JSON 'decode_json', 'encode_json';

use PerlSwagger;
my $app = PerlSwagger->to_app('t/data/petstore.yml');

subtest 'Get pets' => sub {
    plan tests => 2;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(GET '/api/pets');

    is($res->code, 200, 'Found pets');

    is_deeply(
        decode_json($res->content),
        [
            {
                id   => 1,
                name => 'Terry',
                tag  => 'cat, black, male',
            },
        ],
        'Request returned the right pet',
    );
};

subtest 'Get specific pet which is not existing in the store' => sub {
    plan tests => 1;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(GET '/api/pets/2');
    is($res->code, 404, 'Pet not found as not yet POSTed');
};

subtest 'Get specific pet with invalid argument as ID' => sub {
    plan tests => 1;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(GET '/api/pets/foo');
    is($res->code, 404, 'Pet with invalid path parameter not found');
};

subtest 'Add Pet without required arguments' => sub {
    plan tests => 1;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(POST '/api/pets');
    is($res->code, 422, 'Not giving required params should give 422');
};

subtest 'Add invalid pet' => sub {
    plan tests => 1;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(POST '/api/pets',
                              Content_Type => 'application/json',
                              Content      => encode_json(
                                  {
                                      name => [ 'foo' ],
                                  }
                              ));
    is($res->code, 422, 'Catched invalid argument');
};

subtest 'Add pet' => sub {
    plan tests => 2;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(POST '/api/pets',
                            Content_Type => 'application/json',
                            Content      => encode_json(
                                {
                                    name => 'Knut',
                                    tag  => 'white, cat, male',
                                }
                            ));
    is($res->code, 200, 'Added pet to the store');

    is_deeply(
        decode_json($res->content),
        {
            name => 'Knut',
            id   => 2,
            tag  => 'white, cat, male',
        },
        'Got the right pet back',
    );
};

subtest 'Get specific pet which is existing in the store' => sub {
    plan tests => 2;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(GET '/api/pets/2');

    is($res->code, 200, 'Pet found');

    is_deeply(
        decode_json($res->content),
        {
            name => 'Knut',
            id   => 2,
            tag  => 'white, cat, male',
        },
        'Correct pet returned',
    );
};

subtest 'Delete pet' => sub {
    plan tests => 1;

    my $test = Plack::Test->create($app);
    my $res  = $test->request(DELETE '/api/pets/2');

    is($res->code, 501, 'This method has no handler');
};
