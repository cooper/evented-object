#
# Copyright (c) 2011-14, Mitchell Cooper
#
# Evented::Object: a simple yet featureful base class event framework.
# https://github.com/cooper/evented-object
#
package Evented::Object::EventFire; # leave this package name the same FOREVER.
 
use warnings;
use strict;
use utf8;
use 5.010;

##########################
### EVENT FIRE OBJECTS ###
##########################

our $VERSION = '5.47';
our $events  = $Evented::Object::events;
our $props   = $Evented::Object::props;

# create a new event object.
sub new {
    my ($class, %opts) = @_;
    $opts{callback_i} ||= 0;
    return bless { $props => \%opts }, $class;
}

# cancel all future callbacks once.
# if stopped already, returns the reason.
sub stop {
    my ($fire, $reason) = @_;
    $fire->{$props}{stop} ||= $reason || 'unspecified';
}

# returns a true value if the given callback has been called.
# with no argument, returns number of callbacks called so far.
sub called {
    my ($fire, $callback) = @_;
    
    # return the number of callbacks called.
    # this includes the current callback.
    if (!defined $callback) {
        my $called = scalar keys %{ $fire->{$props}{called} };
        $called++ unless $fire->{$props}{complete};
        return $called;
    }
    
    # return whether the specified callback was called.
    return $fire->{$props}{called}{$callback};
    
}

# returns a true value if the given callback will be called soon.
# with no argument, returns number of callbacks pending.
sub pending {
    my ($fire, $cb_name) = @_;
    
    # return number of callbacks remaining.
    if (!defined $cb_name) {
        return scalar $fire->_pending_callbacks;
    }

    # return whether the specified callback is pending.
    foreach my $callback ($fire->_pending_callbacks) {
        return 1 if $callback->[2]{name} eq $cb_name;
    }
    
    return;
}

# cancels a future callback once.
sub cancel {
    my ($fire, $callback) = @_;
    
    # if there is no argument given, we will just
    # treat this like a ->stop on the event.
    defined $callback or return $fire->stop;
    
    $fire->{$props}{cancelled}{$callback} = 1;
    $fire->{$props}{cancellor}{$callback} = $fire->callback_name;
    return 1;
}

# returns the return value of the given callback.
# if it has not yet been called, this will return undef.
# if the return value has a possibility of being undef,
# the only way to be sure is to first test ->callback_called.
sub return_of {
    my ($fire, $callback) = @_;
    return $fire->{$props}{return}{$callback};
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
    @{ shift->{$props}{caller} };
}

# returns the priority of the callback being called.
sub callback_priority {
    shift->{$props}{callback_priority};
}

# returns the value of the 'data' option when the callback was registered.
# if an argument is provided, it is used as the key to the data hash.
sub callback_data {
    my $data = shift->{$props}{callback_data};
    my $key_maybe = shift;
    if (ref $data eq 'HASH') {
        return $data->{$key_maybe} if defined $key_maybe;
        return $data->{data} // $data;
    }
    return $data;
}

# returns the value of the 'data' option on the ->fire().
# if an argument is provided, it is used as the key to the data hash.
sub data {
    my $data = shift->{$props}{data};
    my $key_maybe = shift;
    if (ref $data eq 'HASH') {
        return $data->{$key_maybe} if defined $key_maybe;
        return $data->{data} // $data;
    }
    return $data;
}

# returns the evented object.
sub object {
    shift->{$props}{object};
}

# returns the exception from 'safe' option, if any.
sub exception {
    shift->{$props}{exception};
}

# internal use only.
# returns an array of the callbacks to come.
sub _pending_callbacks {
    my ($fire, @pending) = shift;
    my $ef_props   = $fire->{$props};
    my $collection = $ef_props->{collection};
    my @remaining  = @{ $collection->{pending} };
    
    # this is the last callback.
    return @remaining if !@remaining;
    
    # return the pending callbacks, filtering out canceled callbacks.
    return grep { not $ef_props->{cancelled}{ $_->[2]{name} } } @remaining;
    
}

###############
### ALIASES ###
###############

sub object;

BEGIN {
    *eo = *object;
}

1;
