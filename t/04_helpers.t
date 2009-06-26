package MyApp;
use Test::More tests => 4;
use Schenker;

helpers foo => sub { 'foo' };

can_ok(__PACKAGE__, 'foo');
is(foo(), 'foo');

SKIP: {
    eval 'use Template';
    skip 'Template not installed', 1 if $@;
    template tt => sub {
        'foo() returns [% foo() %]'
    };
    like(tt('tt'), qr/foo\(\) returns foo/);
}

SKIP: {
    eval 'use Text::MicroTemplate';
    skip 'Text::MicroTemplate not installed', 1 if $@;
    template mt => sub {
        'foo() returns <?= foo() ?>'
    };
    like(mt('mt'), qr/foo\(\) returns foo/);
}
