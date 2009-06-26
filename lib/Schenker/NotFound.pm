package Schenker::NotFound;
use Any::Moose;

BEGIN { extends 'Schenker::Error' }

__PACKAGE__->meta->make_immutable;
1;
__END__
