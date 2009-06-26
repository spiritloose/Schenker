package MyApp;
use Test::More tests => 7;
use Schenker;
use HTTP::Request::Common;

get '/' => sub {
    isa_ok(request, 'HTTP::Engine::Request');
    is(param('foo'), 'bar');
    is(params->{foo}, 'bar');
    is(back, 'http://google.com/');
    stash test => 'test';
    is(stash->{test}, 'test');
};

post '/nested_params' => sub {
    is_deeply(param('post'), { title => 'a', body => 'b', author => 'c' });
    is(param('foo'), 'bar');
};

Schenker::run(GET 'http://localhost/?foo=bar', Referer => 'http://google.com/');
Schenker::run(POST 'http://localhost/nested_params', {
    'post[title]'  => 'a',
    'post[body]'   => 'b',
    'post[author]' => 'c',
    'foo'          => 'bar',
});

