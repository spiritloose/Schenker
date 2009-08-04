package Schenker::Options;
use Any::Moose;
use base 'Exporter';

use Carp qw(croak);
use List::MoreUtils qw(any);
use Getopt::Long qw(:config bundling no_ignore_case);

our @EXPORT = qw(
    configure options set enable disable
    development test production standalone
);

my $instance;

sub options {
    $instance ||= __PACKAGE__->new;
}

sub set {
    croak 'usage: set $option => $value' if @_ % 2 != 0;
    options->define(@_);
}

sub enable {
    my $option = shift or croak 'option required';
    set $option => 1;
}

sub disable {
    my $option = shift or croak 'option required';
    set $option => 0;
}

sub development { options->environment eq 'development' }

sub test { options->environment eq 'test' }

sub production { options->environment eq 'production' }

sub standalone {
    any { options->server eq $_ } qw(ServerSimple POE AnyEvent);
}

sub configure {
    my $code = pop or croak 'code required';
    croak 'code must be coderef' if ref $code ne 'CODE';
    my @envs = @_;
    $code->() if @envs == 0 or any { $_ eq options->environment } @envs;
}

sub define {
    my $self = shift;
    my %options = @_;
    while (my ($option, $value) = each %options) {
        unless (ref $value eq 'CODE') {
            return $self->define($option => sub { $value });
        } else {
            $self->meta->add_method($option => sub { $value->() });
        }
    }
}

sub usage {
    my $exit_code = shift || 0;
    print STDERR <<"END_USAGE";
Usage: $0 [OPTIONS]
    -h, --help              display this help
    -H, --host              set the host (default is 0.0.0.0)
    -p, --port=PORT         set the port (default is 4567)
    -e, --environment=ENV   set the environment (default is development)
    -s, --server=SERVER     specify HTTP::Engine interface (default is ServerSimple)
    -l, --listen=LISTEN     Socket path to listen on
                            (defaults to standard input)
                            can be HOST:PORT, :PORT or a filesystem path.
    -n, --nproc=NUM         specify number of processes to keep to serve requests.
                            (defaults to 1, requires --listen)
    -P, --pidfile=FILE      specify filename for pid file (requres --listen)
    -d, --daemon            daemonize (requires --listen)
    -M, --manager=MANAGER   specify alternate process manager
                            (FCGI::ProcManager sub-class) or empty string to disable
    -E, --keeperr           send error messages to STDOUT, not to the webserver
END_USAGE
    Schenker::exit($exit_code);
}

sub parse_argv {
    my %options = (
        help        => 'h',
        host        => 'H=s',
        port        => 'p=i',
        environment => 'e=s',
        server      => 's=s',
        listen      => 'l=s',
        nproc       => 'n=i',
        pidfile     => 'P=s',
        daemon      => 'd',
        manager     => 'M=s',
        keeperr     => 'E',
    );

    my $conf = {};
    GetOptions($conf, map { "$_|$options{$_}" } keys %options) or usage 1;

    usage 0 if exists $conf->{help};

    for my $key (keys %options) {
        set $key => $conf->{$key} if exists $conf->{$key};
    }
}

no Any::Moose;
1;
__END__
