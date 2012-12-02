#
# Copyright (c) 2012, Mitchell Cooper
#
# EventedObject: a simple yet featureful base class event framework.
#
# EventedObject 0.2 is based on the libuic UIC::EventedObject:
# an event system based on the EventedObject class from foxy-java IRC Bot,
# ... which is based on EventedObject from Arinity IRC Services,
# ... which is based on EventedObject from ntirc IRC Client,
# ... which is based on EventedObject from libirc IRC Library,
# ... which can be found in its latest version at https://github.com/cooper/evented-object.
#
#
# COMPATIBILITY NOTES:
#
# EventedObject versions 0.0 to 0.7 are entirely compatible - anything that worked in
# version 0.0 or even compies of EventedObject before it was versioned also work in
# version 0.7; however, some recent changes break the compatibility with these previous
# versions in many cases.
#
# EventedObject 1.* series and above are incompatible with the former versions.
# EventedObject 1.8+ is designed to be more thread-friendly and work well in asyncrhonous
# programs, whereas the previous versions were not suitable for such uses.
#
# The main comptability issue is the arguments passed to the callbacks. In the earlier
# versions, the EventedObject instance was *always* the first argument of *all* events,
# until EventedObject 0.6 added the ability to pass a parameter to attach_event() that
# would tell EventedObject to omit the object from the callback's argument list.
#
# The new EventedObject series, 1.8+, passes a hash reference $event instead of the
# EventedObject. $event contains information that was formerly held within the object
# itself, such as event_info, event_return, and event_data. These are now accessible
# through this new hash reference as $event->{info}, $event->{return}, $event->{data},
# etc. The object is now accessible with $event->{object}.
#
# Events are now stored in the 'eventedObject.events' hash key instead of 'events', as
# 'events' was a tad bit too broad and could conflict with other libraries.
#
# In addition to these changes, the attach_event() method was deprecated in version 1.8
# in favor of the new register_event(); however, it will remain in EventedObject until at
# least the late 2.* series.
#

package EventedObject 1.8;
 
use warnings;
use strict;
use utf8;

my $events = 'eventedObject.events';

# create a new evented object
sub new {
    bless {}, shift;
}

# attach an event callback. deprecated. do not use directly.
sub attach_event {
    my ($obj, $event_name, $code, $name, $priority, $silent, $data) = @_;
    $name ||= $event_name.q(.).rand(9001); # so illegal.
    $priority ||= 0; # priority does not matter, so call last.
    $obj->{$events}{$event_name}{$priority} ||= [];
    push @{$obj->{$events}{$event_name}{$priority}}, {
        name   => $name,
        code   => $code,
        silent => $silent,
        data   => $data
    };
    return 1;
}

# attach an event callback.
# $obj->register_event(myEvent => sub {
#     ...
# }, name => 'some.callback', priority => 200, with_obj => 1);
# note: no_obj fires callback without $event as first argument.
sub register_event {
    my ($obj, $event_name, $code, %opts) = @_;
    my $silent = $opts{no_obj} ? undef : 1;
    return $obj->attach_event(
        $event_name => $code,
        $opts{name},
        $opts{priority},
        $silent,
        $opts{data}
    );
}
 
# fire an event.
# $event = {
#     object        => the evented object,
#     name          => the name of the event,
#     callback      => the callback currently being called (CODE),
#     callback_name => the name of the callback currently being called,
#     priority      => the priority of the current callback,
#     caller        => the caller of fire_event,
#     return        => a hashref of name:value return values,
#     last_return   => the return value of the last-called event,
#     count         => the number of callbacks called,
#     data          => data passed to event when handler was registered,
#     stop          => true to stop iteration of events
# };
# returns $event.
sub fire_event {
    my ($obj, $event_name) = (shift, shift);
    
    # event does not have any callbacks.
    return unless $obj->{$events}{$event_name};
 
    # create event object.
    my $event = {
        name   => $event_name,
        object => $obj,
        caller => [caller 1]
    };
 
    # iterate through callbacks by priority.
    PRIORITY: foreach my $priority (sort { $b <=> $a } keys %{$obj->{$events}{$event_name}}) {
        CALLBACK: foreach my $cb (@{$obj->{$events}{$event_name}{$priority}}) {
 
            # create info about the call.
            $event->{callback}      = $cb->{code};
            $event->{callback_name} = $cb->{name};
            $event->{priority}      = $priority;
            $event->{data}          = $cb->{data} if defined $cb->{data};
 
            # call it.
            $event->{last_return}      =
            $event->{return}{$cb->{name}} = $cb->{silent} ? $cb->{code}($event, @_) : $cb->{code}(@_);
            
            # if $event->{stop} is true, stop the iteration.
            if ($event->{stop}) {
                $event->{stopper} = $event->{callback_name};
                last PRIORITY;
            }
            
        }
    }
    
    delete $event->{object};
    return $event;
}

# delete an event callback or all callbacks of an event.
# returns a true value if any events were deleted, false otherwise.
sub delete_event {
    my ($obj, $event_name, $name) = @_;
    my $amount;
    
    # event does not have any callbacks.
    return unless $obj->{$events}{$event_name};
 
    # iterate through callbacks and delete matches.
    foreach my $priority (keys %{$obj->{$events}{$event_name}}) {
    
        # if a specific callback name is specified, weed it out.
        if (defined $name) {
            my $a = $obj->{$events}{$event_name}{$priority};
            @$a = grep { $_->{name} ne $name } @$a;
            
            # none left in this priority.
            if (scalar @$a == 0) {
                delete $obj->{$events}{$event_name}{$priority};
            }
            
            # delete this event because all priorities have been removed.
            if (scalar keys %{$obj->{$events}{$event_name}} == 0) {
                delete $obj->{$events}{$event_name};
            }
            
        }
        
        # if no callback is specified, delete all events of this type.
        else {
            $amount = scalar keys %{$obj->{$events}{$event_name}};
            delete $obj->{$events}{$event_name};
        }
 
    }

    return $amount;
}
 
# aliases.
sub on; sub del; sub fire;
*on   = *attach_event;
*del  = *delete_event;
*fire = *fire_event;
 
1
