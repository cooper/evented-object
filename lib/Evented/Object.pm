# Copyright (c) 2011-17, Mitchell Cooper
#
# Evented::Object: a simple yet featureful base class event framework.
#
# Evented::Object is based on the libuic UIC::Evented::Object:
# ... which is based on Evented::Object from foxy-java IRC Bot,
# ... which is based on Evented::Object from Arinity IRC Services,
# ... which is based on Evented::Object from ntirc IRC Client,
# ... which is based on IRC::Evented::Object from libirc IRC Library.
#
# Evented::Object and its very detailed documentation can be found
# in their latest versions at https://github.com/cooper/evented-object.
#
package Evented::Object;

use warnings;
use strict;
use utf8;
use 5.010;

# these must be set before loading EventFire.
our ($events, $props, %monitors);
BEGIN {
    $events = 'eventedObject.events';
    $props  = 'eventedObject.props';
}

use Scalar::Util qw(weaken blessed);
use Evented::Object::EventFire;
use Evented::Object::Collection;

# always use 2 decimals. change other packages too.
our $VERSION = '5.63';

# creates a new evented object.
sub new {
    my ($class, %opts) = @_;
    bless \%opts, $class;
}

#############################
### REGISTERING CALLBACKS ###
#############################

# ->register_callback()
#
# aliases: ->register_event(), ->on()
# attaches an event callback.
#
# $eo->register_callback(myEvent => sub {
#     ...
# }, 'some.callback.name', priority => 200);
#
sub register_callback {
    my ($eo, $event_name, $code, @opts_) = @_;

    # if there is an odd number of options, the first is the callback name.
    # this also implies with_eo.
    my %opts;
    if (@opts_ % 2) {
        %opts = (
            name    => shift @opts_,
            with_eo => 1,
            @opts_
        );
    }
    else {
        %opts = @opts_;
    }

    # no name was provided, so we shall construct one using pure hackery.
    # this is one of the most criminal things I've ever done.
    my @caller = caller;
    if (!defined $opts{name}) {
        state $c    = -1; $c++;
        $opts{name} = "$event_name:$caller[0]($caller[2],$c)";
    }

    # determine the event store.
    my $event_store = _event_store($eo);

    # before/after a callback.
    my $priority = delete $opts{priority} || 0;
    if (defined $opts{before} or defined $opts{after}) {
        $priority = 'nan';
        # nan priority indicates it should be determined at a later time.
    }

    # add the callback.
    my $callbacks = $event_store->{$event_name}{$priority} ||= [];
    push @$callbacks, my $cb = {
        %opts,
        code   => $code,
        caller => \@caller
    };

    # tell class monitor.
    _monitor_fire(
        $opts{_caller} // $caller[0],
        register_callback => $eo, $event_name, $cb
    );

    return $cb;
}

# ->register_callbacks()
#
# attaches several event callbacks at once.
#
sub register_callbacks {
    my $eo = shift;
    return map { $eo->register_callback(%$_, _caller => caller) } @_;
}

##########################
### DELETING CALLBACKS ###
##########################

# ->delete_callback(event_name => 'callback.name')
# ->delete_event('event_name')
#
# deletes an event callback or all callbacks of an event.
# returns a true value if any events were deleted, false otherwise.
# more specifically, it returns the number of callbacks deleted.
#
sub delete_callback {
    my ($eo, $event_name, $name, $caller) = @_;
    my @caller      = $caller && ref $caller eq 'ARRAY' ? @$caller : caller;
    my $amount      = 0;
    my $event_store = _event_store($eo);

    # event does not have any callbacks.
    return 0 unless $event_store->{$event_name};

     # if no callback is specified, delete all events of this type.
    if (!$name) {
        $amount = scalar keys %{ $event_store->{$event_name} };
        delete $event_store->{$event_name};
        _monitor_fire($caller[0], delete_event => $eo, $event_name);
        return $amount;
    }

    # iterate through callbacks and delete matches.
    PRIORITY: foreach my $priority (keys %{ $event_store->{$event_name} }) {
        my $callbacks = $event_store->{$event_name}{$priority};
        my @goodbacks;

        CALLBACK: foreach my $cb (@$callbacks) {

            # don't want this one.
            if (ref $cb ne 'HASH' || $cb->{name} eq $name) {
                $amount++;
                next CALLBACK;
            }

            push @goodbacks, $cb;
        }

        # no callbacks left in this priority.
        if (!scalar @goodbacks) {
            delete $event_store->{$event_name}{$priority};
            next PRIORITY;
        }

        # keep these callbacks.
        @$callbacks = @goodbacks;

    }

    return $amount;
}

# ->delete_all_events()
#
# deletes all the callbacks of EVERY event.
# useful when you're done with an object to ensure any possible self-referencing
# callbacks are properly destroyed for garbage collection to work.
#
sub delete_all_events {
    my ($eo, $amount) = (shift, 0);
    my $event_store   = _event_store($eo) or return;
    ref $event_store eq 'HASH'            or return;

    # delete one-by-one.
    # we can't simply set an empty list because monitor events must be fired.
    foreach my $event_name (keys %$event_store) {
        $eo->delete_event($event_name);
        $amount++;
    }

    # just clear it to be safe.
    %$event_store = ();
    delete $eo->{$events};
    delete $eo->{$props};

    return $amount;
}

########################
### PREPARING EVENTS ###
########################

# ->prepare()
#
# automatically guesses whether to use
# ->prepare_event() or ->prepare_together().
#
sub prepare {
    my ($eo_maybe, $eo) = $_[0];
    $eo = shift if blessed $eo_maybe && $eo_maybe->isa(__PACKAGE__);
    if (ref $_[0] && ref $_[0] eq 'ARRAY') {
        return $eo->prepare_together(@_);
    }
    return $eo->prepare_event(@_);
}

# ->prepare_event()
#
# prepares a single event fire by creating a callback collection.
# returns the collection.
#
sub prepare_event {
    my ($eo, $event_name, @args) = @_;
    return $eo->prepare_together([ $event_name, @args ]);
}

# ->prepare_together()
#
# prepares several events fire by creating a callback collection.
# returns the collection.
#
sub prepare_together {
    my $obj;
    my $collection = Evented::Object::Collection->new;
    foreach my $set (@_) {
        my $eo;

        # called with evented object.
        if (blessed $set) {
            $set->isa(__PACKAGE__) or return;
            $obj = $set;
            next;
        }

        # okay, it's an array ref of
        # [ $eo (optional), $event_name => @args ]
        ref $set eq 'ARRAY' or next;
        my ($eo_maybe, $event_name, @args);

        # was an object specified?
        $eo_maybe = shift @$set;
        if (blessed $eo_maybe && $eo_maybe->isa(__PACKAGE__)) {
            $eo = $eo_maybe;
            ($event_name, @args) = @$set;
        }

        # no object; fall back to $obj.
        else {
            $eo = $obj or return;
            ($event_name, @args) = ($eo_maybe, @$set);
        }

        # add to the collection.
        my ($callbacks, $names) =
            _get_callbacks($eo, $event_name, @args);
        $collection->push_callbacks($callbacks, $names);

    }

    return $collection;
}

#####################
### FIRING EVENTS ###
#####################

# ->fire_event()
#
# prepares an event and then fires it.
#
sub fire_event {
    shift->prepare_event(shift, @_)->fire(caller => [caller 1]);
}

# ->fire_events_together()
# fire_events_together()
#
# prepares several events and then fires them together.
#
sub fire_events_together {
    prepare_together(@_)->fire(caller => [caller 1]);
}

# ->fire_once()
#
# prepares an event, fires it, and deletes all callbacks afterward.
#
sub fire_once {
    my ($eo, $event_name, @args) = @_;

    # fire with this caller.
    my $fire = $eo->prepare_event($event_name, @args)->fire(
        caller => [caller 1]
    );

    # delete the event.
    $eo->delete_event($event_name);
    return $fire;

}

########################
### LISTENER OBJECTS ###
########################

# ->add_listener()
#
# adds an object as a listener of another object's events.
# see "listeners" in the documentation.
#
sub add_listener {
    my ($eo, $obj, $prefix) = @_;

    # find listeners list.
    my $listeners = $eo->{$props}{listeners} ||= [];

    # store this listener.
    push @$listeners, [$prefix, $obj];

    # weaken the reference to the listener.
    weaken($listeners->[$#$listeners][1]);

    return 1;
}

# ->delete_listener()
#
# removes an object which was listening to another object's events.
# see "listeners" in the documentation.
#
sub delete_listener {
    my ($eo, $obj) = @_;
    return 1 unless my $listeners = $eo->{$props}{listeners};
    @$listeners = grep {
        ref $_->[1] eq 'ARRAY' and $_->[1] != $obj
    } @$listeners;
    return 1;
}

######################
### CLASS MONITORS ###
######################

# for objective use $eo->monitor_events($pkg)
sub monitor_events  {    add_class_monitor(reverse @_) }
sub stop_monitoring { delete_class_monitor(reverse @_) }

# add_class_monitor()
#
# set the monitor object of a class.
#
# TODO: honestly class monitors need to track individual callbacks so that the
# monitor is notified of all deletes of callbacks added by the class being
# monitored even if the delete action was not committed by that package.
#
sub add_class_monitor {
    my ($pkg, $obj) = @_;

    # ensure it's an evented object.
    return unless $obj->isa(__PACKAGE__);

    # it's already in the list.
    my $m = $monitors{$pkg} ||= [];
    return if grep { $_ == $obj } @$m = grep { defined } @$m;

    # hold a weak reference to the monitor.
    push @$m, $obj;
    weaken($monitors{$pkg}[$#$m]);

    return 1;
}

# delete_class_monitor()
#
# remove a class monitor object from a class.
#
sub delete_class_monitor {
    my ($pkg, $obj) = @_;
    my $m = $monitors{$pkg} or return;
    @$m   = grep { defined && $_ != $obj } @$m;
}

#######################
### CLASS FUNCTIONS ###
#######################

# safe_fire($obj, event => ...)
#
# checks that an object is blessed and that it is an evented object.
# if so, prepares and fires an event with optional arguments.
#
sub safe_fire {
    my $obj = shift;
    return if !blessed $obj || !$obj->isa(__PACKAGE__);
    return $obj->fire_event(@_);
}

#########################
### INTERNAL ROUTINES ###
#########################

# access package storage.
sub _package_store {
    my $package = shift;
    no strict 'refs';
    my $ref = "${package}::__EO__";
    if (!keys %$ref) {
        %$ref = ();
    }
    return *$ref{HASH};
}

# fetch the event store of object or package.
sub _event_store {
    my $eo    = shift;
    return $eo->{$events}   ||= {} if blessed $eo;
    my $store = _package_store($eo);
    return $store->{events} ||= {} if not blessed $eo;
}

# fetch the property store of object or package.
sub _prop_store {
    my $eo    = shift;
    return $eo->{$props}   ||= {} if blessed $eo;
    my $store = _package_store($eo);
    return $store->{props} ||= {} if not blessed $eo;
}

# fetch a callback from its name.
sub _get_callback_named {
    my ($eo, $event_name, $callback_name) = @_;
    foreach my $callback (@{ _get_callbacks($eo, $event_name) }) {
        return $callback if $callback->[2]{name} eq $callback_name
    }
    return;
}

# fetches callbacks of an event.
# internal use only.
sub _get_callbacks {
    my ($eo, $event_name, @args) = @_;
    my (%callbacks, %callback_names);

    # start out with two stores: the object and the package.
    my @stores = (
        [ $event_name => $eo->{$events}             ],
        [ $event_name => _event_store(blessed $eo)  ]
    );


    # if there are any listening objects, add those stores.
    if (my $listeners = $eo->{$props}{listeners}) {
        my @delete;

        LISTENER: foreach my $i (0 .. $#$listeners) {
            my $l = $listeners->[$i] or next;
            my ($prefix, $lis) = @$l;
            my $listener_event_name = $prefix.q(.).$event_name;

            # object has been deallocated by garbage disposal,
            # so we can delete this listener.
            if (!$lis) {
                push @delete, $i;
                next LISTENER;
            }


            push @stores, [ $listener_event_name => $lis->{$events} ];

        }

        # delete listeners if necessary.
        splice @$listeners, $_, 1 foreach @delete;

    }

    # add callbacks from each store.
    foreach my $st (@stores) {
        my ($event_name, $event_store) = @$st;
        my $store = $event_store->{$event_name} or next;
        foreach my $priority (keys %$store) {

            # create a group reference.
            my $group_id = "$eo/$event_name";
            my $group    = [ $eo, $event_name, \@args, $group_id ];
            weaken($group->[0]);

            # add each callback set. inject callback name.
            foreach my $cb_ref (@{ $store->{$priority} }) {
                my %cb = %$cb_ref; # make a copy
                $cb{id} = "$group_id/$cb{name}";
                $callbacks{ $cb{id} } = [ $priority, $group, \%cb ];
                $callback_names{$group_id}{ $cb{name} } = $cb{id};
            }

        }
    }

    return wantarray ? (\%callbacks, \%callback_names) : \%callbacks;
}

# fire a class monitor event.
sub _monitor_fire {
    my ($pkg, $event_name, @args) = @_;
    my $m = $monitors{$pkg} or return;
    safe_fire($_, "monitor:$event_name" => @args) foreach @$m;
}

sub DESTROY { shift->delete_all_events }

###############
### ALIASES ###
###############

sub register_event;
sub register_events;
sub delete_event;

sub on;
sub del;
sub fire;

BEGIN {
    *register_event     = *register_callback;
    *register_events    = *register_callbacks;
    *delete_event       = *delete_callback;
    *on                 = *register_callback;
    *del                = *delete_callback;
    *fire               = *fire_event;
}

1;
