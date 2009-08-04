package Schenker::Router;
use Any::Moose;
use base qw(Exporter);

use Carp qw(croak);
use HTTPx::Dispatcher;

our @EXPORT = qw(get head post put Delete);

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
                Schenker->request->uri->host =~ $host;
            } else {
                Schenker->request->uri->host eq $host;
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
                Schenker->request->user_agent =~ $agent;
            } else {
                Schenker->request->user_agent eq $agent;
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

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
