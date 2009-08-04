package Schenker;
use 5.00800;
use base 'Exporter';
use Any::Moose;
use HTTP::Engine;
use HTTP::Engine::Middleware;
use HTTPx::Dispatcher;
use Carp qw(croak);
use Scalar::Util qw(blessed);
use List::MoreUtils qw(any);
use Path::Class;
use MIME::Types;
use Schenker::Templates;
use Schenker::Halt;
use Schenker::Options;
use Schenker::Error;
use Schenker::NotFound;

our $VERSION = '0.01';

our $App;
our $AppFile;
our $Engine;
our $Initialized;
our $Exited;
our $Middleware;
our @Filters;
our %Errors;
our %Templates;
our $MIMETypes;
our %TTOptions;

our @EXPORT = (qw/
    get head post put Delete
    Use helpers Before error not_found define_error
    request response stash session status param params redirect halt
    back body content_type etag headers last_modified
    media_type mime attachment send_file
/, @Schenker::Options::EXPORT, @Schenker::Templates::EXPORT);

sub import {
    croak q/Can't use Schenker twice./ if defined $App;

    ($App, $AppFile) = caller;
    croak <<'END_MSG' if defined $App and $App eq 'main';
Can't use Schenker in the 'main' package.
Please use Schenker in your package.
END_MSG

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

sub middleware {
    $Middleware ||= HTTP::Engine::Middleware->new(
        method_class => 'HTTP::Engine::Request',
    );
}

sub mime_types { $MIMETypes ||= MIME::Types->new }

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

sub Use {
    croak 'module required' if @_ == 0;
    middleware->install(@_);
}

sub route {
    my $method = shift or croak 'method required';
    my $path   = shift or croak 'path required';
    my $action = pop   or croak 'action required';
    croak 'action must be coderef' if ref $action ne 'CODE';
    my %options = @_;
    my $function;

    if (my $host = $options{host} || $options{host_name}) {
        $function = sub {
            if (ref $host eq 'Regexp') {
                request->uri->host =~ $host;
            } else {
                request->uri->host eq $host;
            }
        };
    }

    if (my $agent = $options{agent} || $options{user_agent}) {
        my $orig_func = $function;
        $function = sub {
            if ($orig_func) {
                $orig_func->() or return 0;
            }
            if (ref $agent eq 'Regexp') {
                request->user_agent =~ $agent;
            } else {
                request->user_agent eq $agent;
            }
        };
    }

    $path =~ s|^/||;
    connect $path => {
        controller => __PACKAGE__,
        action     => $action,
        conditions => {
            method => $method,
            defined $function ? (function => $function) : (),
        },
    };
}

sub head { route 'HEAD', @_ }

sub get { route ['GET', 'HEAD'], @_ }

sub post { route 'POST', @_ }

sub Delete { route 'DELETE', @_ }

sub put { route 'PUT', @_ }

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

sub halt {
    Schenker::Halt->halt(@_);
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

sub mime {
    my ($ext, $type, $encoding, $system) = @_;
    croak 'usage: mime $ext => $type' if !defined $ext or !defined $type;
    my $extensions = ref $ext eq 'ARRAY' ? $ext : [$ext];
    mime_types->addType(MIME::Type->new(
        type       => $type,
        extensions => $extensions,
        defined $encoding ? (encoding => $encoding) : (),
        defined $system   ? (system   => $system)   : (),
    ));
}

sub media_type {
    my $ext = shift or croak 'ext required';
    mime_types->mimeTypeOf($ext);
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
        my $rule = Schenker->match($req) or route_missing;
        parse_nested_query;
        run_before_filters($rule);
        run_action($rule);
    };
    if ($@) {
        handle_exception($@);
    }
}

sub standalone {
    any { options->server eq $_ } qw(ServerSimple POE AnyEvent);
}

sub install_builtin_middlewares {
    configure 'development' => sub {
        Use 'HTTP::Engine::Middleware::AccessLog' => {
            logger => sub { print STDERR @_, "\n" },
        } if standalone;
    };

    Use 'HTTP::Engine::Middleware::Static' => {
        regexp  => qr{^/(.*)$},
        docroot => options->public,
        is_404_handler => 0,
    } if options->static;

    Use 'HTTP::Engine::Middleware::MethodOverride' if options->methodoverride;

    Use 'HTTP::Engine::Middleware::Encode' => options->encode;

    Use 'HTTP::Engine::Middleware::HTTPSession' => options->session_options
            if options->sessions;
}

sub request_handler {
    my $req = shift;
    my $res = HTTP::Engine::Response->new;
    dispatch($req, $res);
    $res;
}

sub init_engine {
    my $args = do {
        if (standalone) {
            +{
                host => options->host,
                port => options->port,
            };
        } elsif (options->server eq 'FCGI') {
            +{
                defined options->listen  ? (listen      => options->listen)  : (),
                defined options->nproc   ? (nproc       => options->nproc)   : (),
                defined options->pidfile ? (pidfile     => options->pidfile) : (),
                defined options->daemon  ? (detach      => options->daemon)  : (),
                defined options->manager ? (manager     => options->manager) : (),
                defined options->keeperr ? (keep_stderr => options->keeperr) : (),
            };
        } else {
            +{};
        }
    };
    $Engine = HTTP::Engine->new(
        interface => {
            module => options->server,
            args   => $args,
            request_handler => middleware->handler(\&request_handler),
        }
    );
}

sub print_banner {
    return unless standalone;
    print STDERR "== Schenker/$VERSION has taken the stage on @{[options->port]} " .
            "for @{[options->environment]} with backup from @{[options->server]}\n";
}

sub init_signal {
    return unless standalone;
    $SIG{INT} = $SIG{QUIT} = $SIG{TERM} = sub {
        print STDERR "\n== Schenker has ended his set (crowd applauds)\n";
        exit;
    };
}

sub run_engine {
    my $res = $Engine->run(@_);
    POE::Kernel->run if options->server eq 'POE';
    AnyEvent->condvar->recv if options->server eq 'AnyEvent';
    $res;
}

sub init {
    $Initialized and return;
    parse_in_file_templates;
    install_builtin_middlewares;
    init_engine;
    init_signal;
    $Initialized = 1;
}

sub run {
    init;
    print_banner;
    run_engine(@_);
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
