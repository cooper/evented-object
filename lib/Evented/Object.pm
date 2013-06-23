#
# Copyright (c) 2011-13, Mitchell Cooper
#
# Evented::Object: a simple yet featureful base class event framework.
#
# Evented::Object 0.2+ is based on the libuic UIC::Evented::Object:
# an event system based on the Evented::Object class from foxy-java IRC Bot,
# ... which is based on Evented::Object from Arinity IRC Services,
# ... which is based on Evented::Object from ntirc IRC Client,
# ... which is based on IRC::Evented::Object from libirc IRC Library.
#
# Evented::Object can be found in its latest version at https://github.com/cooper/eventedobject.
#
# COMPATIBILITY NOTES:
#   See README.md.
#

package Evented::Object;
 
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

use Scalar::Util qw(weaken blessed);

use Evented::Object::EventFire;

our $VERSION = '3.54';

# create a new evented object.
sub new {
    bless {}, shift;
}

##########################
### MANAGING CALLBACKS ###
##########################

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
    my $callbacks = $eo->{$events}{$event_name}{$priority};
    push @$callbacks, {
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
    
    # create event object.
    my $event = Evented::Object::EventFire->new(
        name   => $event_name,  # $event->event_name
        object => $eo,          # $event->object
        caller => [caller 1],   # $event->caller
        $props => {}        
    );
    
    # priority number : array of callbacks.
    my %collection = %{ _get_callbacks(@_) };
        
    # call them.
    return _call_callbacks($event, %collection);
    
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

########################
### LISTENER OBJECTS ###
########################

# add an object to listen to events.
sub add_listener {
    my ($eo, $obj, $prefix) = @_;
    
    # find listeners list.
    $eo->{$props}{listeners} ||= [];
    my $listeners = $eo->{$props}{listeners};
    
    # store this listener.
    push @$listeners, [$prefix, $obj];
    
    # weaken the reference to the listener.
    weaken($listeners->[$#$listeners][1]);
    
    return 1;
}

# remove a listener.
sub delete_listener {
    my ($eo, $obj) = @_;
    return 1 unless my $listeners = $eo->{$props}{listeners};
    @$listeners = grep { ref $_->[1] eq 'ARRAY' and $_->[1] != $obj } @$listeners;
    return 1;
}

#######################
### CLASS FUNCTIONS ###
#######################

# fire multiple events on multiple objects as a single event.
sub fire_events_together {
    my @collections;

    # create event object.
    my $event = Evented::Object::EventFire->new(
      # name   => $event_name,  # $event->event_name    # set before called
      # object => $eo,          # $event->object        # set before called
        caller => [caller 1],   # $event->caller
        $props => {}        
    );
    
    # form of [ $object, name => @args ]
    foreach my $e (@_) {

        # must be an array reference.
        if (!ref $e || ref $e ne 'ARRAY') {
            next;
        }

        my ($eo, $event_name, @args) = @$e;
        
        # must be an evented object.
        if (!blessed $eo || !$eo->isa('Evented::Object')) {
            next;
        }
        
        # add this collection of callbacks to the queue.
        push @collections, $eo->_get_callbacks($event_name, @args);

    }
    
    # organize into a single collection.
    my %collection;
    foreach my $c (@collections) {

        # I hate nested loops.
        foreach my $priority (keys %$c) {
            $collection{$priority} ||= [];
            push @{ $collection{$priority} }, @{ $c->{$priority} };
        }
        
    }
    
    # call them.
    return _call_callbacks($event, %collection);
    
}

#########################
### INTERNAL ROUTINES ###
#########################

# fetches callbacks of an event.
# internal use only.
sub _get_callbacks {
    my ($eo, $event_name, @args) = @_;
    my %collection;
    
    # if there are any listening objects, call its callbacks of this priority.
    if ($eo->{$props}{listeners}) {
        my @delete;
        my $listeners = $eo->{$props}{listeners};
        
        LISTENER: foreach my $i (0 .. $#$listeners) {
            my $l = $listeners->[$i] or next;
            my ($prefix, $obj) = @$l;
            my $listener_event_name = $prefix.q(.).$event_name;
            
            # object has been deallocated by garbage disposal, so we can delete this listener.
            if (!$obj) {
                push @delete, $i;
                next LISTENER;
            }
            
            # add the callbacks from this priority.
            foreach my $priority (keys %{$obj->{$events}{$listener_event_name}}) {
                $collection{$priority} ||= [];
                push @{$collection{$priority}}, [
                    $eo,
                    $listener_event_name,
                    $obj->{$events}{$listener_event_name}{$priority},
                    \@args
                ];
            }
            
        }
        
        # delete listeners if necessary.
        if (scalar @delete) {
            my @new_listeners;
            foreach my $i (0 .. $#$listeners) {
                next if $i ~~ @delete;
                push @new_listeners, $listeners->[$i];
            }
            @$listeners = \@new_listeners; 
        }
       
    }

    # add the local callbacks from this priority.
    if ($eo->{$events}{$event_name}) {
        foreach my $priority (keys %{$eo->{$events}{$event_name}}) {
            $collection{$priority} ||= [];
            push @{ $collection{$priority} }, [
                $eo,
                $event_name,
                $eo->{$events}{$event_name}{$priority},
                \@args
            ];
        }
    }
    
    return \%collection;
}

# This is the structure of a collection:
#   %collection = (
#
#       # priorities are keys.
#
#       # priority 0
#       0 => [
#           
#           $eo,                                            # evented object
#           'my_event_name',                                # event name
#           [ \&some_callback, \&some_other_callback ],     # callbacks
#           [ 'my_argument', 'my_other_argument'     ]      # arguments
#
#       ],
#
#       # priority 1
#       1 => [
#           ...
#       ]
#
#   )

# call the passed callback priority sets.
sub _call_callbacks {
    my ($event, %collection) = @_;
    my $ef_props = $event->{$props};
    my %called;
    
    # call each callback.
    PRIORITY:   foreach my $priority (sort { $b <=> $a } keys %collection)  { 
    COLLECTION: foreach my $col      (@{ $collection{$priority} }        )  { my ($eo, $event_name, $callbacks, $args) = @$col;
    CALLBACK:   foreach my $cb       (@$callbacks                        )  {
        $ef_props->{callback_i}++;
        
        # set the evented object of this callback.
        # set the event name of this callback.
        $ef_props->{object} = $eo; weaken($ef_props->{object});
        $ef_props->{name}   = $event_name;
        
        # create info about the call.
        $ef_props->{callback_name}     = $cb->{name};                          # $event->callback_name
        $ef_props->{callback_priority} = $priority;                            # $event->callback_priority
        $ef_props->{callback_data}     = $cb->{data} if defined $cb->{data};   # $event->callback_data

        # this callback has been called already.
        next CALLBACK if $ef_props->{called}{$cb->{name}};
        next CALLBACK if $called{$cb};

        # this callback has been cancelled.
        next CALLBACK if $ef_props->{cancelled}{$cb->{name}};

        # determine callback arguments.
        
        my @cb_args = @$args;
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
        $ef_props->{last_return}               =   # set last return value.
        $ef_props->{return}{$cb->{name}}       =   # set this callback's return value.
        
            # call the callback with proper arguments.
            $cb->{code}(@cb_args);
        
        # set $event->called($cb) true, and set $event->last to the callback's name.
        $called{$cb}                     =
        $ef_props->{called}{$cb->{name}} = 1;
        $ef_props->{last_callback}       = $cb->{name};
        
        # if stop is true, $event->stop was called. stop the iteration.
        if ($ef_props->{stop}) {
            $ef_props->{stopper} = $cb->{name}; # set $event->stopper.
            last PRIORITY;
        }

     
    } } } # ew.
    
    # dispose of things that are no longer needed.
    delete $event->{$props}{$_} foreach qw(
        callback_name callback_priority callback_data
        priority_i callback_i object
    );

    # return the event object.
    return $event;
    
}

###############
### ALIASES ###
###############

sub on; sub del; sub fire;

BEGIN {
    *on   = *register_event;
    *del  = *delete_event;
    *fire = *fire_event;
}
 
1
