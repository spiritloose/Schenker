use inc::Module::Install;
name 'Schenker';
all_from 'lib/Schenker.pm';

requires 'Scalar::Util';
requires 'List::MoreUtils';
requires 'Data::Visitor::Encode';
requires 'Path::Class';
requires 'HTTP::Engine';
requires 'HTTP::Engine::Middleware';
requires 'HTTPx::Dispatcher';
requires 'MIME::Types';
requires 'CGI::ExceptionManager';

features(
    'Template-Toolkit' => [
        -default => 1,
        recommends('Template'),
    ],
    'Auto set Template variables' => [
        -default => 1,
        recommends('PadWalker'),
    ],
    'Text::MicroTemplate' => [
        -default => 0,
        recommends('Text::MicroTemplate'),
    ],
    'Sessions' => [
        -default => 0,
        recommends('HTTP::Session'),
    ],
);

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_set_repository;
auto_include;
WriteAll;
