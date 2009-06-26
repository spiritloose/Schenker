package MyApp;
use Test::More tests => 5;
use Schenker;
use HTTP::Request::Common;

define_error 'MyError';
isa_ok('MyError', 'Schenker::Error');

error sub {
    my $error = shift;
    body $error->message;
};

not_found sub {
    my $error = shift;
    body $error->message;
};

error MyError => sub {
    body 'MyError';
};

define_error MyError2 => sub {
    body 'MyError2';
};

get '/error' => sub {
    die "die";
};

get '/raise' => sub {
    raise MyError;
};

get '/raise2' => sub {
    raise MyError2;
};

my $res;
$res = Schenker::run(GET 'http://localhost/raise');
is($res->content, 'MyError');

$res = Schenker::run(GET 'http://localhost/raise2');
is($res->content, 'MyError2');

$res = Schenker::run(GET 'http://localhost/error');
like($res->content, qr/^die/);

$res = Schenker::run(GET 'http://localhost/not_found');
like($res->content, qr/not_found/);

