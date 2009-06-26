package MyApp;
use Test::More tests => 14;
use Schenker;

isa_ok(options, 'Schenker::Options');

set foo => 'foo';

can_ok(options, 'foo');
is(options->foo, 'foo');

enable 'bar';

can_ok(options, 'bar');
ok(options->bar);

disable 'baz';

can_ok(options, 'baz');
ok(!options->baz);

set environment => 'test';

configure test => sub {
    enable 'configure';
};
can_ok(options, 'configure');
ok(options->configure);

configure production => sub {
    disable 'configure';
};
ok(options->configure);

configure sub {
    disable 'configure';
};
ok(!options->configure);

ok(!development);
ok(test);
ok(!production);

