package MyApp;
use Test::More tests => 2;
use Schenker;
use HTTP::Request::Common;

enable 'static';

my $res = Schenker::run(GET 'http://localhost/test.txt');
like($res->content, qr/this is test\.txt/);
is($res->content_type, 'text/plain');

