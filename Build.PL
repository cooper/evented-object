#!/usr/bin/perl
use strict;
use warnings;

use Module::Build;

my $class = Module::Build->subclass(
    class => 'Evented::Object::Builder',
    code => q{
        sub ACTION_distmeta {
            my $self = shift;
            if (eval { require Pod::Markdown; 1 }) {
                my $p = Pod::Markdown->new;
                $self->log_info("Creating README.md using Pod::Markdown\n");
                open my $fh, '>', 'README.md' or return $self->SUPER::ACTION_distmeta(@_);
                $p->output_fh($fh);
                $p->parse_file('lib/Evented/Object.pm') and
                $self->_add_to_manifest('MANIFEST', 'README.md');
            }
            else {
                $self->log_warn("Cannot create README.md; Pod::Markdown unavailable\n");
            }
            return $self->SUPER::ACTION_distmeta(@_);
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
    build_requires      => {},
    configure_requires  => { 'Module::Build' => 0.42 },
    license             => 'bsd',
    create_makefile_pl  => 'traditional',
    # create_license    => 1,
    create_readme       => 1,
    dynamic_config      => 0,
    meta_merge          => {
        resources => {
            repository => 'https://github.com/cooper/evented-object'
        }
    },
);

$build->create_build_script;
