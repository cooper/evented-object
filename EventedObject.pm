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
# Version 2.0 breaks things even more because ->on() is now an alias for ->register_event()
# rather than ->attach_event() as it always has been.
#
# Version 2.2 introduces new incompatibilities. The former values fetched as hash elements
# from event objects are now fetched by methods instead. $event->{stop} has been replaced
# by $event->stop, $event->{return}{$callback} by $event->return_of($callback), etc.
#

package EventedObject;
 
use warnings;
use strict;
use utf8;

our $VERSION = '2.7';

my $events = 'eventedObject.events';
my $props  = 'eventedObject.props';

# create a new evented object
sub new {
    bless {}, shift;
}

# attach an event callback. deprecated. do not use directly.
sub attach_event {
    my ($eo, $event_name, $code, $name, $priority, $silent, $data) = @_;
    
    # no name was provided, so we shall construct
    # one using the power of pure hackery.
    if (!defined $name) {
        my @caller = caller;
        $name = "$event_name.$caller[0]($caller[2])";
    }
    
    $priority ||= 0; # priority does not matter.
    $eo->{$events}{$event_name}{$priority} ||= [];
    
    # store this event callback.
    push @{$eo->{$events}{$event_name}{$priority}}, {
        name   => $name,
        code   => $code,
        silent => $silent,
        data   => $data
    };
    
    return 1;
}

# attach an event callback.
# $eo->register_event(myEvent => sub {
#     ...
# }, name => 'some.callback', priority => 200, with_obj => 1);
# note: no_obj fires callback without $event as first argument.
sub register_event {
    my ($eo, $event_name, $code, %opts) = @_;
    my $silent = $opts{no_obj} ? undef : 1;
    
    # the good old ->attach_event().
    return $eo->attach_event(
        $event_name => $code,
        $opts{name},
        $opts{priority},
        $silent,
        $opts{data}
    );

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
#     count         => the number of callbacks called,
# };
# returns $event.
sub fire_event {
    my ($eo, $event_name) = (shift, shift);
    
    # event does not have any callbacks.
    return unless $eo->{$events}{$event_name};
 
    # create event object.
    my $event = EventedObject::Event->new(
        name   => $event_name,  # $event->event_name
        object => $eo,          # $event->object
        caller => [caller 1],   # $event->caller
        count  => 0             # $event->called
    );
 
    my @priorities = sort { $b <=> $a } keys %{$eo->{$events}{$event_name}};
    $event->{current_priority_set} = \@priorities;
    
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
 
            # set last return value.
            $event->{$props}{last_return} =
            
            # set this callback's return value.
            $event->{return}{$cb->{name}} =
            
            # silent really makes no sense - not even I am sure what it does anymore.
            $cb->{silent} ? $cb->{code}($event, @_) : $cb->{code}(@_);
            
            # increase the number of callbacks called for $event->called.
            $event->{$props}{count}++;
            
            # this callback has been called, yes.
            $event->{$props}{called}{$cb->{name}} = 1;
            
            # $event->last
            $event->{$props}{last_callback} = $cb->{name};
            
            # if $event->{stop} is true, $event->stop was called. stop the iteration.
            if ($event->{$props}{stop}) {
                $event->{stopper} = $event->{callback_name}; # set $event->stopper.
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

package EventedObject::Event;

# create a new event object.
sub new {
    my ($class, %opts) = @_;
    return bless { $props => \%opts }, $class;
}

# cancel all future callbacks once.
sub stop {
    shift->{stop} = 1;
}

# returns a true value if the given callback has been called.
# with no argument, returns number of callbacks called so far.
sub called {
    my ($event, $callback) = @_;
    
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
    my ($priority_index, $callback_index) = ($event->{priority_i}, $event->{callback_i});
    my @callbacks  = @{$event->{current_callback_set}};
    my @priorities = @{$event->{current_priority_set}};
    
    # if $callback_index != $#callbacks, there are more callbacks in this priority.
    if ($callback_index < $#callbacks) {
        push @pending, @callbacks[$callback_index..$#callbacks];
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

sub on   { &register_event }
sub del  { &delete_event   }
sub fire { &fire_event     }
 
1
