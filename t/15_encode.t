package MyApp;
use Test::More tests => 2;
use Schenker;
use HTTP::Request::Common;
use Encode;

sub eucjp_str {
    my $q = 'シェンカー';
    Encode::from_to($q, 'utf-8', 'euc-jp');
    $q;
}

set encode => { decode => 'euc-jp', encode => 'euc-jp' };

post '/' => sub {
    ok utf8::is_utf8(param('q')), 'decode';
    decode('euc-jp', eucjp_str); # return flagged UTF-8 string
};

my $res = Schenker::run(POST 'http://localhost/', [ q => eucjp_str ]);
is $res->content, eucjp_str, 'encode';
