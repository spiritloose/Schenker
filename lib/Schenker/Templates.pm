package Schenker::Templates;
use base 'Exporter';
use Any::Moose;
use Carp qw(croak);

our @EXPORT = qw(template tt tt_options mt mt_options);

our %Templates;

our %TTOptions;

our %MTOptions;

sub make_options {
    my ($method, $data) = @_;
    no strict 'refs';
    *$method = sub {
        use strict;
        if (@_ == 1) {
            return $data->{$_[0]};
        } elsif (@_ % 2 == 0) {
            my %options = @_;
            while (my ($key, $val) = each %options) {
                $data->{$key} = $val;
            }
        } else {
            croak "usage: $method \$key or tt_options \$key => \$val";
        }
    }
}

BEGIN {
    eval 'use PadWalker qw(peek_my)'; ## no critic
    *peek_my = sub { {} } if $@;
    make_options tt_options => \%TTOptions;
    make_options mt_options => \%MTOptions;
}

sub template {
    my ($name, $code) = @_;
    croak 'name required' unless $name;
    croak 'code required' unless $code;
    croak 'code must be coderef' if ref $code ne 'CODE';
    $Templates{$name} = $code;
}

sub parse_in_file_templates {
    my $data = do {
        local $/;
        package main;
        <DATA> if defined *DATA and DATA->opened;
    };
    return unless $data;
    my ($name, $tmpl);
    for my $line (split /(\r?\n)/, $data) {
        if ($line =~ /^@@\s+(.+)/) {
            template $name => sub { $tmpl } if $name;
            $name = $1;
            undef $tmpl;
            next;
        }
        next unless $name;
        $tmpl .= $line;
    }
    if ($name and !exists $Templates{$name}) {
        template $name => sub { $tmpl };
    }
}

sub tt {
    require Template;
    my $template      = shift or croak 'template required';
    my $given_options = shift || {};
    my $given_vars    = shift || {};

    my $tmpl = $Templates{$template};
    $tmpl = defined $tmpl ? \$tmpl->() : "$template.tt";

    my %vars = %{peek_my(1) || {}};
    for my $key (keys %vars){
        my ($sigil, $name) = ($key =~ /^(.)(.+)$/);
        if ($sigil eq '$'){
            $vars{$name} = ${delete $vars{$key}};
        } else {
            $vars{$name} = delete $vars{$key};
        }
    }
    for my $method ($Schenker::App->meta->get_method_list) {
        no strict 'refs';
        $vars{$method} = \&{"$Schenker::App\::$method"};
    }
    $vars{$_} = $given_vars->{$_} for keys %$given_vars;

    my %options = %TTOptions;
    if (exists $options{INCLUDE_PATH}) {
        if (ref $options{INCLUDE_PATH} eq 'ARRAY') {
            push @{$options{INCLUDE_PATH}}, Schenker->options->views;
        } else {
            $options{INCLUDE_PATH} = [$options{INCLUDE_PATH}, Schenker->options->views];
        }
    } else {
        $options{INCLUDE_PATH} = Schenker->options->views;
    }
    $options{$_} = $given_options->{$_} for keys %$given_options;

    my $tt = Template->new(%options);
    $tt->process($tmpl, \%vars, \my $output) or die $tt->error;
    $output;
}

sub mt {
    my $template = shift;
    my $given_options = shift || {};
    my @vars = @_;
    if (my $tmpl = $Templates{$template}) {
        require Text::MicroTemplate;
        Text::MicroTemplate::render_mt({
            template     => $tmpl->(),
            package_name => $Schenker::App,
            %MTOptions, %$given_options,
        }, @vars)->as_string;
    } else {
        require Text::MicroTemplate::File;
        my %options = %MTOptions;
        if (exists $options{include_path}) {
            if (ref $options{include_path} eq 'ARRAY') {
                push @{$options{include_path}}, Schenker->options->views;
            } else {
                $options{include_path} = [$options{include_path}, Schenker->options->views];
            }
        } else {
            $options{include_path} = [Schenker->options->views];
        }
        $options{package_name} = $Schenker::App;
        $options{$_} = $given_options->{$_} for keys %$given_options;
        my $mt = Text::MicroTemplate::File->new(%options);
        $mt->render_file("$template.mt", @vars)->as_string;
    }
}

no Any::Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__
