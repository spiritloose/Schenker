package Schenker::Options;
use Any::Moose;
use base 'Exporter';

use Carp qw(croak);
use List::MoreUtils qw(any);

our @EXPORT = qw(
    configure options set enable disable
    development test production
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

no Any::Moose;
1;
__END__
