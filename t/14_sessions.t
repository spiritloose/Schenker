package MyApp;
use Test::More;
use Schenker;
use HTTP::Request::Common;

BEGIN {
    eval 'use HTTP::Session'; ## no critic
    plan skip_all => 'HTTP::Session not installed' if $@;
    plan tests => 2;
}

enable 'sessions';

get '/set' => sub {
    session->set(foo => 'bar');
};

get '/get' => sub {
    is(session->get('foo'), 'bar');
};

my $res;
$res = Schenker::run(GET 'http://localhost/set');
my $cookie = $res->header('Set-Cookie');
ok $cookie;
$res = Schenker::run(GET 'http://localhost/get', Cookie => $cookie);
