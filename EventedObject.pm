#
# Copyright (c) 2011-13, Mitchell Cooper
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
#   Major problem-causing changes listed in README.md.
#

package EventedObject;
 
use warnings;
use strict;
use utf8;

our $VERSION = '3.0';

our $events = 'eventedObject.events';
our $props  = 'eventedObject.props';

# create a new evented object
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
        my @caller = caller;
        $opts{name} = "$event_name.$caller[0]($caller[2], ".int(rand 9001).q[)];
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
# $event = {
#     object        => the evented object,
#     name          => the name of the event,
#     callback      => the callback currently being called (CODE),
#     callback_name => the name of the callback currently being called,
#     priority      => the priority of the current callback,
#     caller        => the caller of fire_event,
#     return        => a hashref of name:value return values,
#     last_return   => the return value of the last-called event,
# };
# returns $event.
sub fire_event {
    my ($eo, $event_name, @args) = (shift, shift);
    
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
    my ($priority_index, $callback_index) = (-1, -1);
    PRIORITY: foreach my $priority (@priorities) {
        $priority_index++;
        
        # set current callback set - used primarily for ->pending.
        $event->{$props}{current_callback_set} = $eo->{$events}{$event_name}{$priority};
        my @callbacks = @{$event->{$props}{current_callback_set}};
        
        # set current priority index.
        $event->{$props}{priority_i} = $priority_index;
        
        # iterate through each callback in this priority.
        CALLBACK: foreach my $cb (@callbacks) {
            $callback_index++;
            
            # set current callback index.
            $event->{$props}{callback_i} = $callback_index;
            
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
                unshift @cb_args, $eo    unless $cb->{with_evented_obj} || $cb->{eo_obj} || $cb->{with_obj};
                                                                    
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
                last PRIORITY;
            }

        }
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

#####################
### EVENT OBJECTS ###
#####################

package EventedObject::EventFire;

our $VERSION = $EventedObject::VERSION;

our $events = $EventedObject::events;
our $props  = $EventedObject::props;

# create a new event object.
sub new {
    my ($class, %opts) = @_;
    return bless { $props => \%opts }, $class;
}

# cancel all future callbacks once.
sub stop {
    shift->{$props}{stop} = 1;
}

# returns a true value if the given callback has been called.
# with no argument, returns number of callbacks called so far.
sub called {
    my ($event, $callback) = @_;
    
    # return the number of callbacks called.
    # this includes the current callback.
    if (!defined $callback) {
        return scalar(keys %{$event->{$props}{called}}) + 1;
    }
    
    # return whether the specified callback was called.
    return $event->{$props}{called}{$callback};
    
}

# returns a true value if the given callback will be called soon.
# with no argument, returns number of callbacks pending.
sub pending {
    my ($event, $callback) = @_;
    
    # return number of callbacks remaining.
    if (!defined $callback) {
        return scalar $event->_pending_callbacks;
    }

    # return whether the specified callback is pending.
    return scalar grep { $_->callback_name eq $callback } $event->_pending_callbacks;
    
}

# cancels a future callback once.
sub cancel {
    my ($event, $callback) = @_;
    $event->{$props}{cancelled}{$callback} = 1;
    $event->{$props}{cancellor}{$callback} = $event->callback_name;
    return 1;
}

# returns the return value of the given callback.
# if it has not yet been called, this will return undef.
# if the return value has a possibility of being undef,
# the only way to be sure is to first test ->callback_called.
sub return_of {
    my ($event, $callback) = @_;
    return $event->{$props}{return}{$callback};
}

# returns the callback that was last called.
sub last {
    shift->{$props}{last_callback};
}

# returns the return value of the last-called callback.
sub last_return {
    shift->{$props}{last_return};
}

# returns the callback that stopped the event.
sub stopper {
    shift->{$props}{stopper};
}

# returns the name of the event being fired.
sub event_name {
    shift->{$props}{name};
}

# returns the name of the callback being called.
sub callback_name {
    shift->{$props}{callback_name};
}

# returns the caller(1) value of ->fire_event().
sub caller {
    my @a = shift->{$props}{caller};
}

# returns the priority of the callback being called.
sub callback_priority {
    shift->{$props}{callback_priority};
}

# returns the value of the 'data' option when the callback was registered.
sub callback_data {
    shift->{$props}{callback_data};
}

# returns the evented object.
sub object {
    shift->{$props}{object};
}

# internal use only.
# returns an array of the callbacks to come.
sub _pending_callbacks {
    my ($event, @pending) = shift;
    
    # fetch iteration values.
    my ($priority_index, $callback_index) = ($event->{$props}{priority_i}, $event->{$props}{callback_i});
    my @callbacks  = @{$event->{$props}{current_callback_set}};
    my @priorities = @{$event->{$props}{current_priority_set}};
    
    # if $callback_index != $#callbacks, there are more callbacks in this priority.
    if ($callback_index < $#callbacks) {
        push @pending, @callbacks[$callback_index + 1 .. $#callbacks];
    }
    
    # this is the last priority.
    return @pending if $priority_index >= $#priorities;
    
    # for each remaining priority, insert all callbacks.
    foreach my $priority (@priorities[$priority_index + 1 .. $#priorities]) {
        push @pending, @{$event->object->{$events}{$event->event_name}{$priority}};
    }
    
    # return the pending callbacks.
    return @pending;
    
}


###############
### ALIASES ###
###############

package EventedObject;

sub on; sub del; sub fire;
*on   = *register_event;
*del  = *delete_event;
*fire = *fire_event;
 
1
