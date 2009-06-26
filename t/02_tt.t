package MyApp;
use Test::More;
use Schenker;

BEGIN {
    eval 'use Template'; ## no critic
    plan skip_all => 'Template not installed' if $@;
    plan tests => 4;
}

my $schenker = 'Schenker';
template test1 => sub {
    'hello, [% schenker %] world!';
};
is(tt('test1', {}, { schenker => $schenker }), 'hello, Schenker world!');

tt_options TAG_STYLE => 'star';
use Template;
template test2 => sub {
    'hello, [* schenker *] world!';
};
is(tt('test2', {}, { schenker => $schenker }), 'hello, Schenker world!');

tt_options TAG_STYLE => 'template';

# from file
like(tt('test'), qr/this is test\.tt/);

SKIP: {
    eval 'use PadWalker'; ## no critic
    skip 'PadWalker not installed', 1 if $@;
    my $lexical = 42;
    template test3 => sub {
        '[% lexical %]';
    };
    is(tt('test3'), '42');
};

