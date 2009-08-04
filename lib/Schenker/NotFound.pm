package Schenker::NotFound;
use Any::Moose;

BEGIN { extends 'Schenker::Error' }

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
