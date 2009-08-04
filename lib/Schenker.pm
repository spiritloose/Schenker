package Schenker;
use 5.00800;
use base 'Exporter';
use Any::Moose;
use Carp qw(croak);
use Scalar::Util qw(blessed);
use Path::Class qw(file dir);
use Schenker::Router;
use Schenker::Engine;
use Schenker::Templates;
use Schenker::Halt;
use Schenker::Options;
use Schenker::Error;
use Schenker::NotFound;
use Schenker::Helpers;

our $VERSION = '0.01';

our $App;
our $AppFile;
our $Initialized;
our $Exited;
our @Filters;
our %Errors;

our @EXPORT = (qw/
        helpers Before error not_found define_error
        request response stash session status param params redirect
        back body content_type etag headers last_modified
        attachment send_file
    /,
    @Schenker::Engine::EXPORT,
    @Schenker::Router::EXPORT,
    @Schenker::Templates::EXPORT,
    @Schenker::Halt::EXPORT,
    @Schenker::Options::EXPORT,
    @Schenker::Helpers::EXPORT,
);

sub import {
    my ($pkg, $file) = caller;
    croak <<'END_MSG' if defined $pkg and $pkg eq 'main';
Can't use Schenker in the 'main' package.
Please use Schenker in your package.
END_MSG
    ($App, $AppFile) = ($pkg, $file) unless defined $App; # only first time

    __PACKAGE__->export_to_level(1, @_);
    any_moose->import({ into_level => 1 });
}

sub unimport {
    my $caller = caller;
    any_moose->unimport;
    no strict 'refs';
    for my $method (@EXPORT) {
        delete ${"$caller\::"}{$method};
    }
}

sub request {
    croak 'cannot call request in not running server.';
}

sub response {
    croak 'cannot call response in not running server.';
}

sub stash {
    croak 'cannot call stash in not running server.';
}

sub make_stash {
    my $stash = shift;
    sub {
        if (@_ == 0) {
            return $stash;
        } elsif (@_ == 1) {
            return $stash->{$_[0]};
        } elsif (@_ % 2 == 0) {
            my %args = @_;
            while (my ($key, $val) = each %args) {
                $stash->{$key} = $val;
            }
        } else {
            croak 'usage: stash $key or stash $key => $val;';
        }
    };
}

sub session {
    croak 'cannot call session in not running server.';
}

sub make_session {
    if (options->sessions) {
        sub { request->session };
    } else {
        sub { croak q/session is disabled. To enable session, set 'sessions' option true./ };
    }
}

sub helpers {
    croak 'usage: helpers $name => $code' if @_ % 2 != 0;
    my %helpers = @_;
    while (my ($name, $sub) = each %helpers) {
        $App->meta->add_method($name, $sub);
    }
}

sub Before {
    my $code = shift or croak 'code required';
    croak 'code must be coderef' if ref $code ne 'CODE';
    push @Filters, $code;
}

sub error {
    my $code = pop or croak 'code required';
    my $class = shift || 'Schenker::Error';
    $Errors{$class} = $code;
}

sub not_found {
    error 'Schenker::NotFound', @_;
}

sub error_in_request {
    my $body = pop;
    my $code = shift || 500;
    halt $code, $body;
}

sub not_found_in_request {
    my $body = shift;
    halt 404, $body;
}

sub status {
    my $status = shift;
    response->status($status) if defined $status;
    response->status;
}

sub param {
    request->param(@_);
}

sub params {
    request->params(@_);
}

sub parse_nested_query {
    my $new_params = {};
    for my $full_key (param) {
        my $this_param = $new_params;
        my $value = params->{$full_key};
        my @split_keys = split /\]\[|\]|\[/, $full_key;
        for my $index (0..$#split_keys) {
            last if @split_keys == $index + 1;
            $this_param->{$split_keys[$index]} ||= {};
            $this_param = $this_param->{$split_keys[$index]};
        }
        $this_param->{$split_keys[-1]} = $value;
    }
    params $new_params;
}

sub headers {
    @_ ? response->header(@_) : response->headers;
}

sub redirect {
    my $uri = shift;
    status 302;
    headers Location => $uri;
    halt @_;
}

sub back {
    request->referer;
}

sub body {
    if (@_) {
        response->body($_[0]);
        response->content_length(bytes::length($_[0]));
    }
    response->body;
}

sub content_type {
    response->content_type($_[0]) if @_;
    response->content_type;
}

sub etag {
    my $etag = shift or croak 'ETag required';
    headers 'ETag' => $etag;
}

sub last_modified {
    my $time = shift;
    headers->last_modified($time) if $time;
    headers->last_modified($time);
}

sub define_error {
    my ($name, $code) = @_;
    croak 'name required' unless $name;
    any_moose('::Meta::Class')->create($name,
        superclasses => ['Schenker::Error'],
        cache => 1,
    );
    return unless $code;
    croak 'code must be coderef' if ref $code ne 'CODE';
    error $name => $code;
}

sub attachment {
    my $file = shift;
    my $disposition = 'attachment';
    if ($file) {
        $file = file($file);
        $disposition .= sprintf '; filename="%s"', $file->basename;
    }
    headers 'Content-Disposition' => $disposition;
}

sub send_file {
    my $file = file(shift);
    my %options = @_;
    raise Schenker::NotFound "$file not found" unless -f $file;
    my $stat = $file->stat;
    last_modified $stat->mtime;
    my ($ext) = $file =~ /\.(.+?)$/;
    my $type = $options{type} || media_type $ext || content_type || 'application/octet-stream';
    content_type $type;
    response->content_length($options{length} || $stat->size);
    if (exists $options{disposition}) {
        if ($options{disposition} eq 'attachment' or $options{filename}) {
            attachment $options{filename} || $file->basename;
        } elsif ($options{disposition} eq 'inline') {
            headers 'Content-Disposition' => 'inline';
        }
    }
    my $body = $file->slurp;
    halt $body;
}

sub run_action {
    my $rule = shift;
    my $action = $rule->{action};
    my $args = $rule->{args};
    my $body = $action->($args);
    body $body if defined $body and request->method ne 'HEAD';
}

sub run_before_filters {
    my $rule = shift;
    for my $filter (@Filters) {
        $filter->($rule);
    }
}

sub die_in_request {
    my $stuff = shift;
    if (blessed $stuff and
            ($stuff->isa('Schenker::Error') or $stuff->isa('Schenker::Halt'))) {
        die $stuff;
    }
    raise Schenker::Error $stuff;
}

sub route_missing {
    my $message = sprintf q/PATH %s doesn't match rules/, request->path;
    raise Schenker::NotFound $message;
}

sub handle_exception {
    my $error = shift;
    if ($error->isa('Schenker::Halt')) {
        status $error->status if $error->status;
        body $error->message  if $error->message;
    } elsif ($error->isa('Schenker::Error')) {
        my $handler = $Errors{ref $error} || $Errors{'Schenker::Error'} || sub {
            status 500;
            content_type 'text/plain';
            body 'Internal Server Error';
        };
        $handler->($error);
    } else {
        # NOTREACHED
        die;
    }
}

sub dispatch {
    my ($req, $res) = @_;
    my $stash = {};

    no warnings 'redefine';
    local *request   = sub { $req };
    local *response  = sub { $res };
    local *stash     = make_stash($stash);
    local *session   = make_session;
    local *error     = \&error_in_request;
    local *not_found = \&not_found_in_request;

    no strict 'refs';
    local *{"$App\::request"}   = \&request;
    local *{"$App\::response"}  = \&response;
    local *{"$App\::stash"}     = \&stash;
    local *{"$App\::session"}   = \&session;
    local *{"$App\::error"}     = \&error;
    local *{"$App\::not_found"} = \&not_found;
    use strict;
    use warnings;

    local $@;
    local $SIG{__DIE__} = \&die_in_request;
    eval {
        my $rule = Schenker::Router->match($req) or route_missing;
        parse_nested_query;
        run_before_filters($rule);
        run_action($rule);
    };
    if ($@) {
        handle_exception($@);
    }
}

sub request_handler {
    my $req = shift;
    my $res = HTTP::Engine::Response->new;
    dispatch($req, $res);
    $res;
}

sub init {
    $Initialized and return;
    Schenker::Templates->parse_in_file_templates;
    Schenker::Engine->init(\&request_handler);
    $Initialized = 1;
}

sub run {
    init;
    Schenker::Engine->run(@_);
}

sub exit {
    $Exited = 1;
    CORE::exit(shift);
}

sub run_at_end {
    $? == 0      or  return; # compile error, die(), exit() with non-zero value
    defined $App or  return; # run this file as script
    $Initialized and return; # already called run()
    $Exited      and return; # -h given
    options->run or  return; # disable 'run';
    run;
}

END {
    run_at_end;
}

# default settings
configure sub {
    set environment => $ENV{SCHENKER_ENV} || 'development';
    disable 'sessions';
    enable 'logging';
    enable 'reload';
    set root => sub { file($AppFile)->dir };
    enable 'static';
    set public => sub { dir(options->root)->subdir('public') };
    set views => sub { dir(options->root)->subdir('views') };
    enable 'run';
    set server => 'ServerSimple';
    set host => '0.0.0.0';
    set port => 4567;
    set app_file => $AppFile;
    enable 'dump_errors';
    enable 'clean_trace';
    disable 'raise_errors';
    disable 'lock';
    enable 'methodoverride';
    set listen => undef;
    set nproc => undef;
    set pidfile => undef;
    set daemon => undef;
    set manager => undef;
    set keeperr => undef;
    set encode => {
        encode => 'utf-8',
        decode => 'utf-8',
    };
    set session_options => {
        state => {
            class => 'Cookie',
            args  => {
                name => 'schenker_sid',
            }
        },
        store => {
            class => 'OnMemory',
            args  => {},
        },
    };
    tt_options ENCODING => 'utf-8';

    # for prove
    if ($ENV{HARNESS_ACTIVE}) {
        set server => 'Test';
        set environment => 'test';
        disable 'run';
    }

    # for mod_perl
    if ($ENV{MOD_PERL}) {
        set server => 'ModPerl';
        disable 'run';
    }

    Schenker::Options->parse_argv;

    configure development => sub {
        Before sub {
            headers 'X-Schenker' => $VERSION;
        };
        error sub {
            my $error = shift;
            warn $error;
            status 500;
            content_type 'text/html';
            body $error->stack_trace->as_html(powered_by => 'Schenker');
        };
        not_found sub {
            my $error = shift;
            status 404;
            content_type 'text/html';
            body <<"END_HTML";
<!DOCTYPE html>
<html>
<head>
    <style type="text/css">
    body { text-align:center;font-family:helvetica,arial;font-size:22px;
    color:#888;margin:20px}
    #c {margin:0 auto;width:500px;text-align:left}
    </style>
</head>
<body>
    <h2>Schenker doesn't know this lick.</h2>
    <div id="c">
    Try this:
    <pre>@{[lc request->method]} '@{[request->path]}' => sub {\n  "Hello World";\n};</pre>
    </div>
</body>
</html>
END_HTML
        };
    };

    configure qw(test production) => sub {
        error sub {
            my $error = shift;
            warn $error;
            status 500;
            content_type 'text/html; charset=iso-8859-1';
            body <<'END_HTML';
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>500 Internal Server Error</title>
</head><body>
<h1>Internal Server Error</h1>
<p>The server encountered an internal error or
misconfiguration and was unable to complete
your request.</p>
<p>Please contact the server administrator,
and inform them of the time the error occurred,
and anything you might have done that may have
caused the error.</p>
<p>More information about this error may be available
in the server error log.</p>
</body></html>
END_HTML
        };
        not_found sub {
            my $error = shift;
            status 404;
            content_type 'text/html; charset=iso-8859-1';
            body <<"END_HTML";
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL @{[request->path]} was not found on this server.</p>
</body></html>
END_HTML
        };
    };
};

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Schenker - DSL for quickly creating web applications

=head1 SYNOPSIS

    package MyApp;
    use Schenker;

    get '/' => sub {
        'Hello, world!';
    };

=head1 DESCRIPTION

Schenker is a DSL for quickly creating web applications in Perl.

=head1 AUTHOR

Jiro Nishiguchi E<lt>jiro@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item * L<http://www.sinatrarb.com/>

=item * L<HTTP::Engine>

=item * L<HTTP::Engine::Middleware>

=item * L<HTTPx::Dispatcher>

=back

=cut
