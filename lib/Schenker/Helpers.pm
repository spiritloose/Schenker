package Schenker::Helpers;
use Any::Moose;
use base 'Exporter';

use Carp qw(croak);
use MIME::Types;

our @EXPORT = qw(media_type mime);

our $MIMETypes;

sub mime_types { $MIMETypes ||= MIME::Types->new }

sub media_type {
    my $ext = shift or croak 'ext required';
    mime_types->mimeTypeOf($ext);
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

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
