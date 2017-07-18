#!/usr/bin/perl
use strict;
use warnings;

use Module::Build;

my $class = Module::Build->subclass(
    class => 'Evented::Object::Builder',
    code => q{
        sub ACTION_distmeta {
            use Pod::Readme;
            use Pod::Select;
            use File::Copy;


            my $self = shift;
            
            podselect({ -output => 'doc/Evented/Object.pod' },
                'lib/Evented/Object.pm');

            podselect({ -output => 'doc/Evented/Object/EventFire.pod' },
                'lib/Evented/Object/EventFire.pm');

            podselect({ -output => 'doc/Evented/Object/Collection.pod' },
                'lib/Evented/Object/Collection.pm');

            copy('doc/Evented/Object.pod', 'README.pod');

            my $parser = Pod::Readme->new();
            $parser->parse_from_file('README.pod', 'README');

            return $self->SUPER::ACTION_docs;
        }
    }
);

my $build = $class->new(
    module_name         => 'Evented::Object',
    dist_author         => 'Mitchell Cooper <cooper@cpan.org>',
    dist_abstract       => 'fire events on objects',
    requires            => {
        perl => '5.010',
        # Scalar::Util (nothing used unavailable in 5.10 core dist)
    },
    recommends          => {},
    build_requires      => {
        'Pod::Readme'   => 0,
        'Pod::Select'   => 0,
        'Test::More'    => 0,
    },
    auto_configure_requires => 0,
    license             => 'bsd',
    create_makefile_pl  => 'traditional',
    create_readme       => 1,
    dynamic_config      => 0,
    meta_merge          => {
        resources => {
            repository => 'https://github.com/cooper/evented-object'
        }
    },
);

$build->create_build_script;
