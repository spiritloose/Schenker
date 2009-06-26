package MyApp;
use Test::More tests => 2;
use Schenker;

my $type = media_type 'txt';
is($type, 'text/plain');

mime schenker => 'application/x-schenker';

$type = media_type 'schenker';
is($type, 'application/x-schenker');
