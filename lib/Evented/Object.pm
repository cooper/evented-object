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
# Evented::Object can be found in its latest version at https://github.com/cooper/evented-object.
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

our $VERSION = '3.55';

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
 
1;

=head1 NAME

B<Evented::Object> - a base class that allows you to attach event callbacks to an object and then fire events on that object.

=head1 SYNOPSIS
 
Demonstrates basic Evented::Object subclasses, priorities of event callbacks,
and event fire objects and their methods.
 
 package Person;
 
 use warnings;
 use strict;
 use feature 'say';
 use parent 'Evented::Object';
 
 use Evented::Object;
 
 # Creates a new person object. This is nothing special.
 # Evented::Object does not require any specific constructor to be called.
 sub new {
     my ($class, %opts) = @_;
     bless \%opts, $class;
 }
 
 # Fires birthday event and increments age.
 sub have_birthday {
     my $person = shift;
     $person->fire(birthday => ++$person->{age});
 }

In some other package...

 package main;

 # Create a person named Jake at age 19.
 my $jake = Person->new(name => 'Jake', age => 19);

 # Add an event callback that assumes Jake is under 21.
 $jake->on(birthday => sub {
     my ($event, $new_age) = @_;
 
     say 'not quite 21 yet...';
 
 }, name => '21-soon');
 
 # Add an event callback that checks if Jake is 21 and cancels the above callback if he is.
 $jake->on(birthday => sub {
     my ($event, $new_age) =  @_;
 
     if ($new_age == 21) {
         say 'time to get drunk!';
         $event->cancel('21-soon');
     }
 
 }, name => 'finally-21', priority => 1);
 
 # Jake has two birthdays.
 
 # Jake's 20th birthday.
 $jake->have_birthday;
 
 # Jake's 21st birthday.
 $jake->have_birthday;
 
 # Because 21-soon has a lower priority than finally-21,
 # finally-21 will cancel 21-soon if Jake is 21.
 
 # The result:
 #
 #   not quite 21 yet...
 #   time to get drunk!
 
=head1 DESCRIPTION

B<I doubt your objects have ever been this evented.> This concept is so incredible that we're using a noun as a verb without being arrested by the grammar police.

Evented::Object started as a basic class for registering event handlers and firing events. After many improvements throughout several projects, Evented::Object has become far more complex and quite featureful.

Evented::Object supplies an (obviously objective) interface to store and manage callbacks for events, fire events upon objects, and more. It provides several methods for convenience and simplicity.

=head2 Introduction

First and foremost, the goal of Evented::Object is to make your objects more evented than ever before.
Allow us to explain what exactly it means for an object to be evented.

=head2 Naming confusion

To clear some things up...

'Evented::Object' refers to the Evented::Object package, but 'evented object' refers to an object which is a member of the Evented::Object class or a class which inherits from the Evented::Object class. 'Event fire object' refers to an object representing an event fire.

=over 4

=item *

B<Evented::Object>: the class that provides methods for managing events.

=item *

B<Evented object>: an object that uses Evented::Object for event management.

=item *

B<Event fire object>: an object that represents an event fire.

=item *

B<Listener object>: another evented object that receives event notifications.

=back

Evented::Object and its core packages are prefixed with C<Evented::Object>.
Packages which are specifically designed for use with Evented::Object are prefixed with C<Evented::>.

=head2 Purpose of Evented::Object

In short, Evented::Object allows you to attach event callbacks to an object (also known as a blessed hash reference) and then fire events on that object. To relate, event fires are much like method calls. However, there can be many handlers, many return values, and many responses rather than just one of each of these.

=head2 Event callbacks

These handlers, known as callbacks, are called in descending order by priority. Numerically larger priorities are called first. This allows you to place a certain callback in front of or behind another. They can modify other callbacks, modify the evented object itself, and much more.

=head2 Objective approach

Whereas many event systems involve globally unique event names, Evented::Object allows you to attach events to a specific object. The event callbacks, information, and other data are stored secretly within the object itself. This is quite comparable to the JavaScript event systems often found in browsers.

=head2 Event fire objects

Another important concept of Evented::Object is the event fire object. It provides methods for fetching information relating to the event being fired, callback being called, and more. Additionally, it provides an interface for modifying the evented object and modifying future event callbacks.

=head2 Listener objects

Additional evented objects can be registered as "listeners."

Consider a scenario where you have a class whose objects represent a farm. You have another class which represents a cow. You would like to use the same callback for all of the moos that occur on the farm, regardless of which cow initiated it.

Rather than attaching an event callback to every cow, you can instead make the farm a listener of the cow. Then, you can attach a single callback to your farm. If your cow's event for mooing is C<moo>, your farm's event for mooing is C<cow.moo>.

=head3 Potential looping references

The cow holds a weak reference to the farm, so you do not need to worry about deleting it later. This, however, means that your listener object must also be referred to in another location in order for this to work. I doubt that will be a problem, though.

=head3 Priorities and listeners

Evented::Object is rather genius when it comes to callback priorities. With object listeners, it is as though the callbacks belong to the object being listened to. Referring to the above example, if you attach a callback on the farm object with priority 1, it will be called before your callback with priority 0 on the cow object.

=head3 Fire objects and listeners

When an event is fired on an object, the same event fire object is used for callbacks belonging to both the evented object and its listening objects. Therefore, callback names must be unique not only to the listener object but to the object being listened on as well.

You should also note the values of the event fire object:

=over 4

=item *

B<$event-E<gt>event_name>: the name of the event from the perspective of the listener; i.e. C<cow.moo> (NOT C<moo>)

=item *

B<$event-E<gt>object>: the object being listened to; i.e. C<$cow> (NOT C<$farm>)

=back

This also means that stopping the event from a listener object will cancel all remaining callbacks, including those belonging to the evented object.

=head1 COMPATIBILITY

Evented::Object versions 0.0 to 0.7 are entirely compatible - anything that worked in version 0.0 or even compies of Evented::Object before it was versioned also work in version 0.7; however, some recent changes break the compatibility with these previous versions in many cases.

=head2 Asynchronous improvements 1.0+

Evented::Object 1.* series and above are incompatible with the former versions. Evented::Object 1.8+ is designed to be more thread-friendly and work well in asyncrhonous programs, whereas the previous versions were not suitable for such uses.

The main comptability issue is the arguments passed to the callbacks. In the earlier versions, the evented object was always the first argument of all events, until Evented::Object 0.6 added the ability to pass a parameter to C<-E<gt>attach_event()> that would tell Evented::Object to omit the object from the callback's argument list.

=head2 Introduction of event fire objects 1.8+

The Evented::Object series 1.8+ passes a hash reference C<$event> instead of the Evented::Object as the first argument. C<$event> contains information that was formerly held within the object itself, such as C<event_info>, C<event_return>, and C<event_data>. These are now accessible through this new hash reference as C<$event-E<gt>{info}>, C<$event-E<gt>{return}>, C<$event-E<gt>{data}>, etc. The object is now accessible with C<$event-E<gt>{object}>. (this has since been changed; see below.)

Events are now stored in the C<eventedObject.events> hash key instead of C<events>, as C<events> was a tad bit too broad and could conflict with other libraries.

In addition to these changes, the C<-E<gt>attach_event()> method was deprecated in version 1.8 in favor of the new C<-E<gt>register_event()>; however, it will remain in Evented::Object until at least the late 2.* series.

=head2 Alias changes 2.0+

Version 2.0 breaks things even more because C<-E<gt>on()> is now an alias for C<-E<gt>register_event()> rather than the former deprecated C<-E<gt>attach_event()>.

=head2 Introduction of event methods 2.2+

Version 2.2+ introduces a new class, Evented::Object::EventFire, which provides several methods for event fire objects. These methods such as C<$event-E<gt>return> and C<$event-E<gt>object> replace the former hash keys C<$event-E<gt>{return}>, C<$event-E<gt>{object}>, etc. The former hash interface is no longer supported and will lead to error.

=head2 Removal of ->attach_event() 2.9+

Version 2.9 removes the long-deprecated C<-E<gt>attach_event()> method in favor of the more flexible C<-E<gt>register_event()>. This will break compatibility with any package still making use of C<-E<gt>attach_event()>.

=head1 EVENTED OBJECT METHODS

The Evented::Object package provides several convenient methods for managing an event-driven object.

=head2 Evented::Object->new()

Creates a new Evented::Object. Typically, this method is overriden by a child class of Evented::Object. It is unncessary to call C<SUPER::new()>, as C<Evented::Object-E<gt>new()> returns nothing more than an empty hash reference blessed to Evented::Object.

 my $eo = Evented::Object->new();

=head2 $eo->register_event($event_name => \&callback, %options)

Intended to be a replacement for the former C<-E<gt>attach_event()>. Attaches an event callback the object. When the specified event is fired, each of the callbacks registered using this method will be called by descending priority order (higher priority numbers are called first.)

 $eo->register_event(myEvent => sub {
     ...
 }, name => 'some.callback', priority => 200);

B<Parameters>

=over 4

=item *

B<event_name>: the name of the event.

=item *

B<callback>: a CODE reference to be called when the event is fired.

=item *

B<options>: I<optional>, a hash (not hash reference) of any of the below options.

=back

B<%options - event handler options>

B<All of these options are optional>, but the use of a callback name is B<highly recommended>.

=over 4

=item *

B<name>: the name of the callback being registered. must be unique to this particular event.

=item *

B<priority>: a numerical priority of the callback.

=item *

B<data>: any data that will be stored as C<$event-E<gt>event_data> as the callback is fired.

=item *

B<no_fire_obj>: if true, the event fire object will not be prepended to the argument list.

=item *

B<with_evented_obj>: if true, the evented object will prepended to the argument list.

=item *

B<no_obj>: I<Deprecated>. Use C<no_fire_obj> instead.

=item *

B<eo_obj>: I<Deprecated>. Use C<with_evented_obj> instead.

=item *

B<with_obj>: I<Deprecated>. Use C<with_evented_obj> instead.

=back

Note: the order of objects will always be C<$eo>, C<$event>, C<@args>, regardless of omissions.
By default, the argument list is C<$event>, C<@args>.

=head2 $eo->register_events(@events)

Registers several events at once. The arguments should be a list of hash references. These references take the same options as C<-E<gt>register_event()>. Returns a list of return values in the order that the events were specified.

 $eo->register_events(
     { myEvent => \&my_event_1, name => 'cb.1', priority => 200 },
     { myEvent => \&my_event_2, name => 'cb.2', priority => 100 }
 );

B<Parameters>

=over 4

=item *

B<events>: an array of hash references to pass to C<-E<gt>register_event()>.

=back

=head2 $eo->delete_event($event_name => $callback_name)

Deletes an event callback from the object with the given callback name. If no callback
name is specified, deletes all callbacks of this event.

Returns a true value if any events were deleted, false otherwise.

 # delete a single callback.
 $eo->delete_event(myEvent => 'my.callback');
 
 # delete all callbacks.
 $eo->delete_event('myEvent');

B<Parameters>

=over 4

=item *

B<event_name>: the name of the event.

=item *

B<callback_name>: I<optional>, the name of the callback being removed.

=back

=head2 $eo->fire_event($event_name => @arguments)

Fires the specified event, calling each callback that was registered with C<-E<gt>register_event()> in descending order of their priorities.

 $eo->fire_event('some_event');

 $eo->fire_event(some_event => $some_argument, $some_other_argument);

B<Parameters>

=over 4

=item *

B<event_name>: the name of the event being fired.

=item *

B<arguments>: I<optional>, list of arguments to pass to event callbacks.

=back

=head2 $eo->add_listener($other_eo, $prefix)

Makes the passed evented object a listener of this evented object. See the "listener objects" section for more information on this feature.

 $cow->add_listener($farm, 'cow');

B<Parameters>

=over 4

=item *

B<other_eo>: the evented object that will listen.

=item *

B<prefix>: a string that event names will be prefixed with on the listener.

=back

=head2 $eo->delete_listener($other_eo)

Removes a listener of this evented object. See the "listener objects" section for more information on this feature.

 $cow->delete_listener($farm, 'cow');

B<Parameters>

=over 4

=item *

B<other_eo>: the evented object that will listen.

=item *

B<prefix>: a string that event names will be prefixed with on the listener.

=back

=head2 $eo->on($event_name => \&callback, %options)

Alias for C<-E<gt>register_event()>.

=head2 $eo->fire($event_name => @arguments)

Alias for C<-E<gt>fire_event()>.

=head2 $eo->del(...)

B<Deprecated>. Alias for C<-E<gt>delete_event()>.
Do not use this. It is likely to removed in the near future.

=head2 $eo->attach_event(...)

B<Removed> in version 2.9. Use C<-E<gt>register_event()> instead.

=head1 EVENTED::OBJECT PROCEDURAL FUNCTIONS

The Evented::Object package provides some functions for use. These functions typically are associated with more than one evented object or none at all.

=head2 fire_events_together(@events)

Fires multiple events at the same time. This allows you to fire multiple similar events on several evented objects at the same time. It essentially pretends that the callbacks are all for the same event and all on the same object.

It follows priorities throughout all of the events and all of the objects, so it is ideal for firing similar or identical events on multiple objects.

The same event fire object is used throughout this entire routine. This means that callback names must unique among all of these objects and events. It also means that stopping an event from any callback will cancel all remaining callbacks, regardless to which event or which object they belong.

The function takes a list of array references in the form of:
C<[ $evented_object, event_name =E<gt> @arguments ]>

 Evented::Object::fire_events_together(
     [ $server,  user_joined_channel => $user, $channel ],
     [ $channel, user_joined         => $user           ],
     [ $user,    joined_channel      => $channel        ]
 );

B<Parameters>

=over 4

=item *

B<events>: an array of events in the form of C<[$eo, event_name =E<gt> @arguments]>.

=back

=head1 EVENT FIRE OBJECT METHODS

Event fire objects are passed to all callbacks of an Evented::Object (unless the silent parameter was specified.) Event fire objects contain information about the event itself, the callback, the caller of the event, event data, and more.

Event fire objects replace the former values stored within the Evented::Object itself. This new method promotes asynchronous event firing.

Event fire objects are specific to each firing. If you fire the same event twice in a row, the event object passed to the callbacks the first time will not be the same as the second time. Therefore, all modifications made by the event fire object's methods apply only to the callbacks remaining in this particular fire. For example, C<$event-E<gt>cancel($callback)> will only cancel the supplied callback once. The next time the event is fired, that cancelled callback will be called regardless.

=head2 $event->object

Returns the evented object.

 $event->object->delete_event('myEvent');

=head2 $event->caller

Returns the value of C<caller(1)> from within the C<-E<gt>fire()> method. This allows you to determine from where the event was fired.

 my $name   = $event->event_name;
 my @caller = $event->caller;
 say "Package $caller[0] line $caller[2] called event $name";

=head2 $event->stop

Cancels all remaining callbacks. This stops the rest of the event firing. After a callback calls $event->stop, it is stored as C<$event-E<gt>stopper>.

 # ignore messages from trolls
 if ($user eq 'noah') {
     # user is a troll.
     # stop further callbacks.
     return $event->stop;
 }

=head2 $event->stopper

Returns the callback which called C<$event-E<gt>stop>.

 if ($event->stopper) {
     say 'Event was stopped by '.$event->stopper;
 }

=head2 $event->called($callback)

If no argument is supplied, returns the number of callbacks called so far, including the current one. If a callback argument is supplied, returns whether that particular callback has been called.

 say $event->called, 'callbacks have been called so far.';
 
 if ($event->called('some.callback')) {
     say 'some.callback has been called already.';
 }
 
B<Parameters>

=over 4

=item *

B<callback>: I<optional>, the callback being checked.

=back

=head2 $event->pending($callback)

If no argument is supplied, returns the number of callbacks pending to be called, excluding the current one. If a callback  argument is supplied, returns whether that particular callback is pending for being called.
 
 say $event->pending, 'callbacks are left.';
 
 if ($event->pending('some.callback')) {
     say 'some.callback will be called soon.';
 }

B<Parameters>

=over 4

=item *

B<callback>: I<optional>, the callback being checked.

=back

=head2 $event->cancel($callback)

Cancels the supplied callback once.

 if ($user eq 'noah') {
     # we don't love noah!
     $event->cancel('send.hearts');
 }

=over 4

=item *

B<callback>: the callback to be cancelled.

=back

=head2 $event->return_of($callback)

Returns the return value of the supplied callback.

 if ($event->return('my.callback')) {
     say 'my.callback returned a true value';
 }

=over 4

=item *

B<callback>: the desired callback.

=back

=head2 $event->last

Returns the most recent previous callback called.
This is also useful for determining which callback was the last to be called.

 say $event->last, ' was called before this one.';
 
 my $event = $eo->fire_event('myEvent');
 say $event->last, ' was the last callback called.';

=head2 $event->last_return

Returns the last callback's return value.

 if ($event->last_return) {
     say 'the callback before this one returned a true value.';
 }
 else {
     die 'the last callback returned a false value.';
 }

=head2 $event->event_name

Returns the name of the event.

 say 'the event being fired is ', $event->event_name;

=head2 $event->callback_name

Returns the name of the current callback.

 say 'the current callback being called is ', $event->callback_name;

=head2 $event->callback_priority

Returns the priority of the current callback.

 say 'the priority of the current callback is ', $event->callback_priority;

=head2 $event->callback_data

Returns the data supplied to the callback when it was registered, if any.

 say 'my data is ', $event->callback_data;

