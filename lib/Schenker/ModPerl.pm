package Schenker::ModPerl;
use Any::Moose;

BEGIN {
    extends 'HTTP::Engine::Interface::ModPerl';
    Schenker::init;
}

sub create_engine { $Schenker::Engine }

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

mod_perl2 Handler for Schenker

=head1 SYNOPSIS

    # myapp.pl
    package MyApp;
    use Schenker;

    get '/' => sub {
        "hello, world!";
    };

    # httpd.conf
    PerlSetEnv SCHENKER_ENV production
    PerlSwitches -I/path/to/your/lib
    PerlRequire /path/to/myapp.pl
    <Location />
        SetHandler perl-script
        PerlResponseHandler Schenker::ModPerl
    </Location>

=head1 DESCRIPTION

mod_perl2 Handler for Schenker

=head1 NOTICE

Schenker::ModPerl can handle just one application in a Apache process.
If you want to run multiple applications, run multiple Apache processes.

=head1 AUTHOR

Jiro Nishiguchi E<lt>jiro@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item * L<Schenker>

=back

=cut
