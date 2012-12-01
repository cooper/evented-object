# Copyright (c) 2012, Mitchell Cooper
#
# EventedObject 0.2 based on the libuic UIC::EventedObject:
# event system based on EventedObject from foxy-java IRC Bot,
# ... which is based on EventedObject from Arinity IRC Services,
# ... which is based on EventedObject from ntirc IRC Client,
# ... which is based on EventedObject from libirc IRC Library,
# ... which can be found at https://github.com/cooper/evented-object.
#
package EventedObject 0.7;
 
use warnings;
use strict;
use utf8;
 
# create a new evented object
sub new {
    bless {}, shift;
}

# attach an event callback.
sub attach_event {
    my ($obj, $event, $code, $name, $priority, $silent, $data) = @_;
    $priority ||= 0; # priority does not matter, so call last.
    $obj->{events}->{$event}->{$priority} ||= [];
    push @{$obj->{events}->{$event}->{$priority}}, [$name, $code, $silent, $data];
    return 1;
}

# attach an event callback.
# $obj->register_event(myEvent => sub {
#     ...
# }, name => 'some.callback', priority => 200, with_obj => 1);
# with_obj replaces $silent - it's the opposite of $silent.
sub register_event {
    my ($obj, $event, $code, %opts) = @_;
    my $silent = $opts{with_obj} ? undef : 1;
    return $obj->attach_event(
        $event => $code,
        $opts{name},
        $opts{priority},
        $silent,
        $opts{data}
    );
}
 
# fire an event.
sub fire_event {
    my ($obj, $event) = (shift, shift);
    
    # event does not have any callbacks
    return unless $obj->{events}->{$event};
 
    # clear the last event_return.
    delete $obj->{event_return};
 
    # iterate through callbacks by priority.
    PRIORITY: foreach my $priority (sort { $b <=> $a } keys %{$obj->{events}->{$event}}) {
        CALLBACK: foreach my $cb (@{$obj->{events}->{$event}->{$priority}}) {
 
            # create info about the call
            $obj->{event_info} = {
                object   => $obj,
                callback => $cb->[0],
                caller   => [caller 1],
                priority => $priority
            };
            
            # set event data.
            $obj->{event_data} = $cb->[3] if defined $cb->[3];
 
            # call it.
            $obj->{event_return} = $cb->[1]->($obj, @_) unless $cb->[2];
            $obj->{event_return} = $cb->[1]->(   @_   ) if     $cb->[2];
            
            # if $obj->{event_stop} is true, stop the iteration.
            last PRIORITY if $obj->{event_stop};
            
        }
    }
    
    # delete event_info, as it causes a neverending reference.
    delete $obj->{event_info};
    delete $obj->{event_data};
    delete $obj->{event_stop};
   #delete $obj->{event_return};
 
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
