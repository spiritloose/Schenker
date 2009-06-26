package MyApp;
use strict;
use Test::More tests => 48;

BEGIN {
    use_ok 'Schenker';
    use_ok 'Schenker::Templates';
    use_ok 'Schenker::Options';
    use_ok 'Schenker::Error';
    use_ok 'Schenker::NotFound';
    use_ok 'Schenker::Halt';
}

can_ok(__PACKAGE__, 'get');
can_ok(__PACKAGE__, 'post');
can_ok(__PACKAGE__, 'Delete');
can_ok(__PACKAGE__, 'put');
can_ok(__PACKAGE__, 'head');
can_ok(__PACKAGE__, 'options');
can_ok(__PACKAGE__, 'set');
can_ok(__PACKAGE__, 'enable');
can_ok(__PACKAGE__, 'disable');
can_ok(__PACKAGE__, 'configure');
can_ok(__PACKAGE__, 'development');
can_ok(__PACKAGE__, 'test');
can_ok(__PACKAGE__, 'production');
can_ok(__PACKAGE__, 'Use');
can_ok(__PACKAGE__, 'helpers');
can_ok(__PACKAGE__, 'before');
can_ok(__PACKAGE__, 'error');
can_ok(__PACKAGE__, 'not_found');
can_ok(__PACKAGE__, 'define_error');
can_ok(__PACKAGE__, 'request');
can_ok(__PACKAGE__, 'response');
can_ok(__PACKAGE__, 'stash');
can_ok(__PACKAGE__, 'status');
can_ok(__PACKAGE__, 'param');
can_ok(__PACKAGE__, 'params');
can_ok(__PACKAGE__, 'redirect');
can_ok(__PACKAGE__, 'back');
can_ok(__PACKAGE__, 'body');
can_ok(__PACKAGE__, 'content_type');
can_ok(__PACKAGE__, 'etag');
can_ok(__PACKAGE__, 'headers');
can_ok(__PACKAGE__, 'last_modified');
can_ok(__PACKAGE__, 'media_type');
can_ok(__PACKAGE__, 'mime');
can_ok(__PACKAGE__, 'attachment');
can_ok(__PACKAGE__, 'send_file');
can_ok(__PACKAGE__, 'halt');
can_ok(__PACKAGE__, 'template');
can_ok(__PACKAGE__, 'tt');
can_ok(__PACKAGE__, 'tt_options');
can_ok(__PACKAGE__, 'mt');
can_ok(__PACKAGE__, 'mt_options');

