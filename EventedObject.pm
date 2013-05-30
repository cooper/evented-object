#
# Copyright (c) 2011-13, Mitchell Cooper
#
# EventedObject: a simple yet featureful base class event framework.
#
# EventedObject 0.2+ is based on the libuic UIC::EventedObject:
# an event system based on the EventedObject class from foxy-java IRC Bot,
# ... which is based on EventedObject from Arinity IRC Services,
# ... which is based on EventedObject from ntirc IRC Client,
# ... which is based on IRC::EventedObject from libirc IRC Library.
#
# EventedObject can be found in its latest version at https://github.com/cooper/eventedobject.
#
# COMPATIBILITY NOTES:
#   See README.md.
#

package EventedObject;
 
use warnings;
use strict;
use utf8;
use 5.010;

# these must be set before loading EventFire.
our ($events, $props);
BEGIN {
    $events = 'eventedObject.events';
    $props  = 'eventedObject.props';
}

use Scalar::Util 'weaken';

use EventedObject::EventFire;

our $VERSION = '3.34';

# create a new evented object.
sub new {
    bless {}, shift;
}

# attach an event callback.
# $eo->register_event(myEvent => sub {
#     ...
# }, name => 'some.callback', priority => 200, eo_obj => 1);
# note: no_obj fires callback without $event as first argument.
sub register_event {
    my ($eo, $event_name, $code, %opts) = @_;
    
    # no name was provided, so we shall construct
    # one using the power of pure hackery.
    # this is one of the most criminal things I've ever done.
    if (!defined $opts{name}) {
        my @caller  = caller;
        state $c    = 0;
        $opts{name} = "$event_name.$caller[0]($caller[2], ".$c++.q[)];
    }
    
    my $priority = $opts{priority} || 0; # priority does not matter.
    $eo->{$events}{$event_name}{$priority} ||= [];
    
    # add this event.
    push @{$eo->{$events}{$event_name}{$priority}}, {
        %opts,
        code => $code
    };
    
    return 1;

}

# attach several event callbacks.
sub register_events {
    my ($eo, @events) = @_;
    my @return;
    foreach my $event (@events) {
        push @return, $eo->register_event(%$event);
    }
    return @return;
}
 
# fire an event.
# returns $event.
sub fire_event {
    my ($eo, $event_name, @args) = @_;
    
    # event does not have any callbacks.
    return unless $eo->{$events}{$event_name};
 
    # create event object.
    my $event = EventedObject::EventFire->new(
        name   => $event_name,  # $event->event_name
        object => $eo,          # $event->object
        caller => [caller 1]    # $event->caller
    );
 
    my @priorities = sort { $b <=> $a } keys %{$eo->{$events}{$event_name}};
    $event->{$props}{current_priority_set} = \@priorities;
    
    # iterate through callbacks by priority (higher number is called first)
    ($event->{$props}{callback_i}, $event->{$props}{priority_i}) = (-1, -1);
    foreach my $priority (@priorities) {
    
        # if there are any listening objects, call its callbacks of this priority.
        if ($eo->{$props}{listeners}) {
            my @delete;
            my $listeners = $eo->{$props}{listeners};
            
            foreach my $i (0 .. $#$listeners) {
                my $l = $listeners->[$i] or next;
                
                my ($prefix, $obj) = @$l;
                
                # object has been deallocated by garbage disposal, so we can delete this listener.
                if (!$obj) {
                    push @delete, $i;
                    next;
                }
                
                # fire the event on the listener for this priority.
                $obj->fire_event_priority("$prefix.$event_name", $event, $priority, @args) or last;
            }
            
            # delete listener if necessary.
            if (scalar @delete) {
                my @new_listeners;
                foreach my $i (0 .. $#$listeners) {
                    next if $i ~~ @delete;
                    push @new_listeners, $listeners->[$i];
                }
                @$listeners = \@new_listeners; 
            }
            
        }
        
        # fire local callbacks of this priority.
        $eo->fire_event_priority($event_name, $event, $priority, @args) or last;
        
    }

    # dispose of things that are no longer needed.
    delete $event->{$props}{$_} foreach qw(
        callback_name callback_priority callback_data
        current_priority_set current_callback_set
        priority_i callback_i
    );

    # return the event object.
    return $event;
    
}

# fire a certain priority of an event.
# this method is for internal use only.
sub fire_event_priority {
    my ($eo, $event_name, $event, $priority, @args) = @_;
    $event->{$props}{priority_i}++;
    
    # set current callback set - used primarily for ->pending.
    $event->{$props}{current_callback_set} = $eo->{$events}{$event_name}{$priority};
    my @callbacks = @{$event->{$props}{current_callback_set}};
    
    
    # iterate through each callback in this priority.
    CALLBACK: foreach my $cb (@callbacks) {
        $event->{$props}{callback_i}++;
       
        # create info about the call.
        $event->{$props}{callback_name}     = $cb->{name};                          # $event->callback_name
        $event->{$props}{callback_priority} = $priority;                            # $event->callback_priority
        $event->{$props}{callback_data}     = $cb->{data} if defined $cb->{data};   # $event->callback_data

        # this callback has been cancelled.
        next CALLBACK if $event->{$props}{cancelled}{$cb->{name}};

        # determine callback arguments.
        
        my @cb_args = @args;
        if ($cb->{no_obj}) {
            # compat < 3.0: no_obj -> no_fire_obj - fire with only actual arguments.
            # no_obj is now deprecated.
        }
        else {
            # compat < 2.9: with_obj -> eo_obj
            # compat < 3.0: eo_obj   -> with_evented_obj
            
            # add event object unless no_obj.
            unshift @cb_args, $event unless $cb->{no_fire_obj};
            
            # add evented object if eo_obj.
            unshift @cb_args, $eo if $cb->{with_evented_obj} || $cb->{eo_obj} || $cb->{with_obj};
                                                                
        }
        
        # set return values.
        $event->{$props}{last_return}               =   # set last return value.
        $event->{$props}{return}{$cb->{name}}       =   # set this callback's return value.
        
            # call the callback with proper arguments.
            $cb->{code}(@cb_args);
        
        # set $event->called($cb) true, and set $event->last to the callback's name.
        $event->{$props}{called}{$cb->{name}} = 1;
        $event->{$props}{last_callback} = $cb->{name};
        
        # if stop is true, $event->stop was called. stop the iteration.
        if ($event->{$props}{stop}) {
            $event->{$props}{stopper} = $cb->{name}; # set $event->stopper.
            return;
        }

    }
    
    return 1;
}

# delete an event callback or all callbacks of an event.
# returns a true value if any events were deleted, false otherwise.
sub delete_event {
    my ($eo, $event_name, $name) = @_;
    my $amount = 0;
    
    # event does not have any callbacks.
    return unless $eo->{$events}{$event_name};
 
    # iterate through callbacks and delete matches.
    PRIORITY: foreach my $priority (keys %{$eo->{$events}{$event_name}}) {
    
        # if a specific callback name is specified, weed it out.
        if (defined $name) {
            my @a = @{$eo->{$events}{$event_name}{$priority}};
            @a = grep { $_->{name} ne $name } @a;
            
            # none left in this priority.
            if (scalar @a == 0) {
                delete $eo->{$events}{$event_name}{$priority};
                
                # delete this event because all priorities have been removed.
                if (scalar keys %{$eo->{$events}{$event_name}} == 0) {
                    delete $eo->{$events}{$event_name};
                    return 1;
                }
                
                $amount++;
                next PRIORITY;
                
            }
            
            # store the new array.
            $eo->{$events}{$event_name}{$priority} = \@a;
            
        }
        
        # if no callback is specified, delete all events of this type.
        else {
            $amount = scalar keys %{$eo->{$events}{$event_name}};
            delete $eo->{$events}{$event_name};
        }
 
    }

    return $amount;
}

# add an object to listen to events.
sub add_listener {
    my ($eo, $prefix, $obj) = @_;
    
    # find listeners list.
    $eo->{$props}{listeners} ||= [];
    my $listeners = $eo->{$props}{listeners};
    
    # store this listener.
    my $last_i = $#$listeners;
    $listeners->[$last_i + 1] = [$prefix, $obj];
    
    # weaken the reference to the listener.
    weaken($listeners->[$last_i + 1]);
    
    return 1;
}

# remove a listener.
sub delete_listener {
    my ($eo, $obj) = @_;
    return 1 unless my $listeners = $eo->{$props}{listeners};
    @$listeners = grep { ref $_->[1] eq 'ARRAY' and $_->[1] != $obj } @$listeners;
    return 1;
}


###############
### ALIASES ###
###############

sub on; sub del; sub fire;
*on   = *register_event;
*del  = *delete_event;
*fire = *fire_event;
 
1
