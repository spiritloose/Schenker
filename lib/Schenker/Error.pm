package Schenker::Error;
use Any::Moose;
use overload
    '""'   => \&as_string,
    'bool' => sub { 1 };

use CGI::ExceptionManager::StackTrace;

has message => (
    is  => 'ro',
    isa => 'Str',
);

has stack_trace => (
    is  => 'ro',
    isa => 'CGI::ExceptionManager::StackTrace',
);

sub BUILDARGS {
    my ($class, $message) = @_;
    $message = $message ? "$message" : '';
    my $stack_trace = CGI::ExceptionManager::StackTrace->new($message);
    { message => $message, stack_trace => $stack_trace };
}

sub raise {
    my $proto = shift;
    my $self = ref $proto ? $proto : $proto->new(@_);
    die $self;
}

sub as_string {
    my $self = shift;
    $self->message;
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
