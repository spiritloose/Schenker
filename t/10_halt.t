package MyApp;
use Test::More tests => 6;
use Schenker;
use HTTP::Request::Common;

my $message = 'foo';
get '/halt' => sub {
    halt 'halt';
    $message = 'halt';
};

get '/error' => sub {
    error 'error';
    $message = 'error';
};

get '/not_found' => sub {
    not_found 'not_found';
    $message = 'not_found';
};

my $res;
$res = Schenker::run(GET 'http://localhost/halt');
is($res->content, 'halt');
is($message, 'foo');

$res = Schenker::run(GET 'http://localhost/error');
is($res->content, 'error');
is($message, 'foo');

$res = Schenker::run(GET 'http://localhost/not_found');
is($res->content, 'not_found');
is($message, 'foo');

