# Copyright (c) 2011-14, Mitchell Cooper
# Evented::Object: a simple yet featureful base class event framework.
package Evented::Object::Collection; # leave this package name the same FOREVER.
 
use warnings;
use strict;
use utf8;
use 5.010;
use Scalar::Util 'weaken';

our $VERSION = $Evented::Object::VERSION;
our $events  = $Evented::Object::events;
our $props   = $Evented::Object::props;

sub fire {
    my ($collection, @options) = @_;

    # handle options.
    my $caller = $collection->{caller};
    while (@options) {
        my $opt = shift @options;
        
        # custom caller.
        if ($opt eq 'caller') { $caller = shift @options }
        
    }
    
    # create event object.
    my $fire = Evented::Object::EventFire->new(
        caller => $caller || [caller 1], # $fire->caller
        $props => {}        
    );
        
    # call them.
    return unless $collection->{pending};
    return _call_callbacks($fire, @{ $collection->{pending} });
    
}

# Nov. 22, 2013 revision:
# -----------------------
#
#   collection      a set of callbacks about to be fired. they might belong to multiple
#                   objects or maybe even multiple events. they can each have their own
#                   arguments, and they all have their own options, code references, etc.
#
#        group      represents the group to which a callback belongs. a group consists of
#                   the associated evented object, event name, and arguments.
#
# This revision eliminates all of these nested structures by reworking the way
# a callback collection works. A collection should be an array of callbacks.
# This array, unlike before, will contain an additional element: an array
# reference representing the "group."
#
#   @collection = (
#       [ $priority, $group, $cb ]
#   )
#
# where $group is
#   [ $eo, $event_name, $args ]
#
# This format has several major advantages over the former one. Specifically,
# it makes it very simple to determine which callbacks will be called in the
# future, which ones have been called already, how many are left, etc.
#

# call the passed callback priority sets.
sub _call_callbacks {
    my ($fire, @collection) = @_;
    my $ef_props = $fire->{$props};
    my %called;
    
    # sort by priority.
    @collection = sort { $b->[0] <=> $a->[0] } @collection;
    
    # store the collection.
    $ef_props->{collection} = \@collection;
    
    # call each callback.
    foreach my $callback (@collection) {
        my ($priority, $group, $cb)  = @$callback;
        my ($eo, $event_name, $args) = @$group;
        
        $ef_props->{callback_i}++;
        
        # set the evented object of this callback.
        # set the event name of this callback.
        $ef_props->{object} = $eo; weaken($ef_props->{object});
        $ef_props->{name}   = $event_name;
        
        # create info about the call.
        $ef_props->{callback_name}     = $cb->{name};                          # $fire->callback_name
        $ef_props->{callback_priority} = $priority;                            # $fire->callback_priority
        $ef_props->{callback_data}     = $cb->{data} if defined $cb->{data};   # $fire->callback_data

        # this callback has been called already.
        next if $ef_props->{called}{$cb->{name}};
        next if $called{$cb};

        # this callback has been cancelled.
        next if $ef_props->{cancelled}{$cb->{name}};

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
            unshift @cb_args, $fire unless $cb->{no_fire_obj};
            
            # add evented object if eo_obj.
            unshift @cb_args, $eo if $cb->{with_evented_obj} || $cb->{eo_obj} || $cb->{with_obj};
                                                                
        }
        
        # set return values.
        $ef_props->{last_return}               =   # set last return value.
        $ef_props->{return}{$cb->{name}}       =   # set this callback's return value.
        
            # call the callback with proper arguments.
            $cb->{code}(@cb_args);
        
        # set $fire->called($cb) true, and set $fire->last to the callback's name.
        $called{$cb}                     =
        $ef_props->{called}{$cb->{name}} = 1;
        $ef_props->{last_callback}       = $cb->{name};
        
        # if stop is true, $fire->stop was called. stop the iteration.
        if ($ef_props->{stop}) {
            $ef_props->{stopper} = $cb->{name}; # set $fire->stopper.
            last;
        }

     
    }
    
    # dispose of things that are no longer needed.
    delete $fire->{$props}{$_} foreach qw(
        callback_name callback_priority
        callback_data callback_i object
        collection
    );

    # return the event object.
    $fire->{complete} = 1;
    return $fire;
    
}

1
