# Copyright (c) 2012, Mitchell Cooper
#
# EventedObject 0.2 based on the libuic UIC::EventedObject:
# event system based on EventedObject from foxy-java IRC Bot,
# ... which is based on EventedObject from Arinity IRC Services,
# ... which is based on EventedObject from ntirc IRC Client,
# ... which is based on EventedObject from libirc IRC Library,
# ... which can be found at https://github.com/cooper/evented-object.
#
package EventedObject;
 
use warnings;
use strict;
use utf8;

our $VERSION = '0.2';
 
# create a new evented object
sub new {
    bless {}, shift;
}
 
# attach an event callback
sub attach_event {
    my ($obj, $event, $code, $name, $priority) = @_;
    $priority ||= 0; # priority does not matter, so call last.
    $obj->{events}->{$event}->{$priority} ||= [];
    push @{$obj->{events}->{$event}->{$priority}}, [$name, $code];
    return 1;
}
 
sub fire_event {
    my ($obj, $event) = (shift, shift);
 
    # event does not have any callbacks
    return unless $obj->{events}->{$event};
 
    # iterate through callbacks by priority.
    foreach my $priority (sort { $b <=> $a } keys %{$obj->{events}->{$event}}) {
        foreach my $cb (@{$obj->{events}->{$event}->{$priority}}) {
 
            # create info about the call
            $obj->{event_info} = {
                object   => $obj,
                callback => $cb->[0],
                caller   => [caller 1],
                priority => $priority
            };
 
            # call it.
            $cb->[1]->($obj, @_);
        }
    }
 
    return 1;
}
 
sub delete_event {
    my ($obj, $event, $name) = @_;
 
    # event does not have any callbacks
    return unless $obj->{events}->{$event};
 
    # iterate through callbacks and delete matches
    foreach my $priority (keys %{$obj->{events}->{$event}}) {
        my $a = $obj->{events}->{$event}->{$priority};
        @$a   = grep { $_->[0] ne $name } @$a;
 
        # none left in this priority.
        if (scalar @$a == 0) {
            delete $obj->{events}->{$event}->{$priority};
        }
    }
 
    # delete this event because all have been removed.
    if (scalar keys %{$obj->{events}->{$event}} == 0) {
        delete $obj->{events}->{$event};
    }
 
    return 1;
}
 
# aliases
sub on; sub del; sub fire;
*on   = *attach_event;
*del  = *delete_event;
*fire = *fire_event;
 
1
