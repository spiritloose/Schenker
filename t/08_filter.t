package MyApp;
use Test::More tests => 1;
use Schenker;
use HTTP::Request::Common;

Before sub {
    stash foo => 'bar';
};

get '/' => sub {
    is(stash->{foo}, 'bar');
};

Schenker::run(GET 'http://localhost/');

