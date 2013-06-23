# Copyright (c) 2011-13, Mitchell Cooper
# Evented::Object: a simple yet featureful base class event framework.
package Evented::Object::EventFire;
 
use warnings;
use strict;
use utf8;
use 5.010;

##########################
### EVENT FIRE OBJECTS ###
##########################

our $VERSION = $Evented::Object::VERSION;

our $events  = $Evented::Object::events;
our $props   = $Evented::Object::props;

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
    @{shift->{$props}{caller}};
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
    
    # filter out any cancelled callbacks.
    my @filtered;
    foreach my $cb (@callbacks) {
        push @filtered, $cb unless $event->{$props}{cancelled}{$cb->{name}};
    }
    
    # return the pending callbacks.
    return @filtered;
    
}

1
