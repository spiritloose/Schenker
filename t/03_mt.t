package MyApp;
use Test::More;
use Schenker;

BEGIN {
    eval 'use Text::MicroTemplate'; ## no critic
    plan skip_all => 'Text::MicroTemplate not installed' if $@;
    plan tests => 3;
}

my $schenker = 'Schenker';
template test1 => sub {
    'hello, <?= $_[0] ?> world!';
};
is(mt('test1', {}, $schenker), 'hello, Schenker world!');

mt_options tag_start => '[*';
mt_options tag_end   => '*]';
template test2 => sub {
    'hello, [*= $_[0] *] world!';
};
is(mt('test2', {}, $schenker), 'hello, Schenker world!');

# from file
like(mt('test'), qr/this is test\.mt/);
