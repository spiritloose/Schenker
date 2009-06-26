package Schenker::Options;
use Any::Moose;

sub set {
    my $self = shift;
    my %options = @_;
    while (my ($option, $value) = each %options) {
        unless (ref $value eq 'CODE') {
            return $self->set($option => sub { $value });
        } else {
            $self->meta->add_method($option => sub { $value->() });
        }
    }
}

no Any::Moose;
1;
__END__
