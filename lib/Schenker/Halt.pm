package Schenker::Halt;
use Any::Moose;
use base 'Exporter';
use overload
    '""'   => \&as_string,
    'bool' => sub { 1 };

our @EXPORT = qw(halt);

has status => (
    is  => 'ro',
    isa => 'Int',
);

has message => (
    is  => 'ro',
    isa => 'Str',
);

sub BUILDARGS {
    my $class = shift;
    my $options;
    if (@_ == 1) {
        $options->{message} = $_[0];
    } elsif (@_ == 2) {
        $options->{status}  = $_[0];
        $options->{message} = $_[1];
    }
    $options;
}

sub halt {
    die __PACKAGE__->new(@_);
}

sub as_string {
    my $self = shift;
    $self->message;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
