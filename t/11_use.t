package MyApp;
use Test::More tests => 1;
use Schenker;
use HTTP::Request::Common;

my $message;
Use 'HTTP::Engine::Middleware::Profile' => {
    logger => sub { $message = shift },
};

get '/' => sub {
    'profile';
};

Schenker::run(GET 'http://localhost/');
ok($message);

