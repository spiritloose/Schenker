package Schenker::Engine;
use Any::Moose;
use base 'Exporter';

use Carp qw(croak);
use HTTP::Engine;
use HTTP::Engine::Middleware;
use Schenker::Options;

our @EXPORT = qw(Use);

my $engine;

my $middleware;

sub middleware {
    $middleware ||= HTTP::Engine::Middleware->new(
        method_class => 'HTTP::Engine::Request',
    );
}

sub Use {
    croak 'module required' if @_ == 0;
    middleware->install(@_);
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

sub init_signal {
    return unless standalone;
    $SIG{INT} = $SIG{QUIT} = $SIG{TERM} = sub {
        print STDERR "\n== Schenker has ended his set (crowd applauds)\n";
        exit;
    };
}
sub print_banner {
    return unless standalone;
    print STDERR "== Schenker/$Schenker::VERSION has taken the stage on @{[options->port]} " .
            "for @{[options->environment]} with backup from @{[options->server]}\n";
}

sub init {
    my $class = shift;
    my $handler = shift or croak 'handler required';

    install_builtin_middlewares;
    init_signal;

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

    $engine = HTTP::Engine->new(
        interface => {
            module => options->server,
            args   => $args,
            request_handler => middleware->handler($handler),
        }
    );
}

sub run {
    my $class = shift;
    print_banner;
    my $res = $engine->run(@_);
    POE::Kernel->run if options->server eq 'POE';
    AnyEvent->condvar->recv if options->server eq 'AnyEvent';
    $res;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
