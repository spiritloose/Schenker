package MyApp;
use Test::More tests => 11;
use Schenker;
use HTTP::Request::Common qw(GET HEAD POST PUT DELETE);

get '/' => sub {
    'get /';
};
post '/' => sub {
    'post /';
};
put '/' => sub {
    'put /';
};
Delete '/' => sub {
    'delete /';
};

get '/foo/:foo' => sub {
    my $args = shift;
    $args->{foo};
};

get '/decode/:arg' => sub {
    my $args = shift;
    ok(utf8::is_utf8($args->{arg}));
};

put '/bar' => sub {
    'put /bar'
};

get '/agent' => agent => qr/iPhone/ => sub {
    'iPhone';
};

get '/agent' => sub {
    'Not iPhone';
};

get '/host' => host => 'example.com' => sub {
    'example.com';
};

get '/host' => sub {
    'Not example.com';
};

my $res;
$res = Schenker::run(GET 'http://localhost/');
like($res->content, qr{get /});

$res = Schenker::run(POST 'http://localhost/');
like($res->content, qr{post /});

$res = Schenker::run(PUT 'http://localhost/');
like($res->content, qr{put /});

$res = Schenker::run(DELETE 'http://localhost/');
like($res->content, qr{delete /});

$res = Schenker::run(GET 'http://localhost/foo/bar');
like($res->content, qr{bar});

$res = Schenker::run(GET 'http://localhost/decode/%263a');

$res = Schenker::run(POST 'http://localhost/bar?_method=PUT');
like($res->content, qr{put /bar});

$res = Schenker::run(GET 'http://localhost/agent', 'User-Agent' => 'iPhone');
is($res->content, 'iPhone');

$res = Schenker::run(GET 'http://localhost/agent', 'User-Agent' => 'Other');
is($res->content, 'Not iPhone');

$res = Schenker::run(GET 'http://example.com/host', 'User-Agent' => $0);
is($res->content, 'example.com');

$res = Schenker::run(GET 'http://localhost/host', 'User-Agent' => $0);
is($res->content, 'Not example.com');
