# this is IRC::EventedObject from ntirc's libirc.
package EventedObject;

#-----------------------------------------------------------
# libirc: an insanely flexible perl IRC library.           |
# Copyright (c) 2011, the NoTrollPlzNet developers         |
# EventedObject.pm: store & fire events on various objects |
#-----------------------------------------------------------
# package IRC::EventedObject;

use warnings;
use strict;

sub fire_event {
    my ($obj, $event, @arguments) = @_;
    return unless exists $obj->{events}->{$event};

    # run through each event registered to that name
    foreach my $code (@{$obj->{events}->{$event}}) {
        $code->($obj, @arguments)
    }

    return 1
}

sub attach_event {
    my ($obj, $event, $code) = @_;

    if (!defined $code || ref $code ne 'CODE') {
        return # no CODE reference.
    }

    # create the array ref if it doesn't exist
    if (!$obj->{events}->{$event}) {
        $obj->{events}->{$event} = [];
    }

    # add the CODE to the array ref of hooks
    push @{$obj->{events}->{$event}}, $code;

    return 1
}

1
