package MyApp;
use Test::More tests => 12;
use Schenker;
use HTTP::Request::Common;

get '/' => sub {
    isa_ok(response, 'HTTP::Engine::Response');
    status 404;
    is(status, 404);
    body 'body';
    is(body, 'body');
    return;
};

get '/redirect' => sub {
    redirect 'http://google.com/';
};

my $now = time;
get '/headers' => sub {
    content_type 'text/javascript';
    last_modified $now;
    headers 'X-Framework' => 'Schenker';
    etag 'FooBar';
    'location.href = "http://google.com/";'
};

get '/send_file' => sub {
    send_file 't/public/test.txt';
};

my $res;
$res = Schenker::run(GET 'http://localhost/');
is($res->content, 'body');

$res = Schenker::run(GET 'http://localhost/redirect');
ok($res->is_redirect);
is($res->header('Location'), 'http://google.com/');

$res = Schenker::run(GET 'http://localhost/headers');
is($res->content_type, 'text/javascript');
is($res->last_modified, $now);
is($res->header('X-Framework'), 'Schenker');
is($res->header('ETag'), 'FooBar');

$res = Schenker::run(GET 'http://localhost/send_file');
is($res->content_type, 'text/plain');
like($res->content, qr/this is test\.txt/);
