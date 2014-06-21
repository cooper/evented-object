#
# Copyright (c) 2011-14, Mitchell Cooper
#
# Evented::Object: a simple yet featureful base class event framework.
# https://github.com/cooper/evented-object
#
package Evented::Object::Collection; # leave this package name the same FOREVER.
 
use warnings;
use strict;
use utf8;
use 5.010;
use Scalar::Util 'weaken';

our $VERSION = '5.4';
our $events  = $Evented::Object::events;
our $props   = $Evented::Object::props;

my $dummy;
my %boolopts = map { $_ => 1 } qw(safe return_check fail_continue);

#
#   Available fire options
#   ----------------------
#
#   safe            calls all callbacks within eval blocks
#
#   return_check    causes the event to ->stop if any callback returns false
#                   BUT IT WAITS until all have been fired. so if one returns false,
#                   the rest will be called, but $fire->stopper will be true afterward.
#
#   caller          specify an alternate [caller 1] value, mostly for internal use.
#
#   fail_continue   if 'safe' is enabled and a callback raises an exception, it will
#                   by default ->stop the fire. this option tells it to continue instead.
#

sub fire {
    my ($collection, @options) = @_;
    
    # handle options.
    my $caller = $collection->{caller};
    while (@options) {
        my $opt = shift @options;
        
        # custom caller.
        if ($opt eq 'caller') { $caller = shift @options }
        
        # boolean option.
        $collection->{$opt} = 1 if $boolopts{$opt};
        
    }
    
    # create fire object.
    my $fire = Evented::Object::EventFire->new(
        caller => $caller ||= [caller 1], # $fire->caller
        $props => {}        
    );
    
    # if it hasn't been sorted, do so.
    my $callbacks = $collection->{pending} or return $fire;
    $collection->sort_callbacks if not $collection->{sorted};
    
    # if return_check is enabled, add a callback to be fired last that will
    # check the return values. this is basically hackery using a dummy object.
    push @$callbacks, [ -inf, [ $dummy ||= Evented::Object->new, 'returnCheck', [] ], {
        name   => 'eventedObject.returnCheck',
        caller => $caller,
        code   => \&_return_check
    } ] if $collection->{return_check};
    
    # call them.
    return $collection->_call_callbacks($fire);
    
}

sub sort_callbacks {
    my $collection = shift;
    my $pending_cb = $collection->{pending};
    @$pending_cb = sort { $b->[0] <=> $a->[0] } @$pending_cb;
    $collection->{sorted} = 1;
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
#       [ $priority, $group, $cb ],
#       [ $priority, $group, $cb ],
#       ...
#   )
#
#   $group =                            $cb = 
#   [ $eo, $event_name, $args ]         { code, caller, %opts }
#
# This format has several major advantages over the former one. Specifically,
# it makes it very simple to determine which callbacks will be called in the
# future, which ones have been called already, how many are left, etc.
#

# call the passed callback priority sets.
sub _call_callbacks {
    my ($collection, $fire) = @_;
    my $ef_props = $fire->{$props};
    my %called;
    
    # store the collection.
    $ef_props->{collection} = delete $collection->{pending};
    
    # call each callback.
    foreach my $callback (@{ $ef_props->{collection} }) {
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
        next if $ef_props->{called}{ $cb->{name} };
        next if $called{$cb};

        # this callback has been cancelled.
        next if $ef_props->{cancelled}{ $cb->{name} };

        
        # determine arguments.
        #
        # no compat <3.0: used to always have obj unless specified with no_obj or later no_fire_obj.
        # no compat <2.9: with_obj -> eo_obj
        # compat: all later version had a variety of with_obj-like-options below.
        #
        my @cb_args = @$args;
        my $include_obj = grep { $cb->{$_} } qw(with_eo with_obj with_evented_obj eo_obj);
        unshift @cb_args, $fire unless $cb->{no_fire_obj};
        unshift @cb_args, $eo   if $include_obj;
        
        # set return values.
        $ef_props->{last_return}            =   # set last return value.
        $ef_props->{return}{ $cb->{name} }  =   # set this callback's return value.
        
            # call the callback with proper arguments.
            $collection->{safe} ? eval { $cb->{code}(@cb_args) }
                                :        $cb->{code}(@cb_args);
        
        # set $fire->called($cb) true, and set $fire->last to the callback's name.
        $called{$cb}                       =
        $ef_props->{called}{ $cb->{name} } = 1;
        $ef_props->{last_callback}         = $cb->{name};
        
        # stop if eval failed.
        if ($collection->{safe} and my $err = $@) {
            chomp $err;
            $fire->stop($err) unless $collection->{fail_continue};
        }
        
        # if stop is true, $fire->stop was called. stop the iteration.
        if ($ef_props->{stop}) {
            $ef_props->{stopper} = $cb->{name}; # set $fire->stopper.
            last;
        }
     
    }
    
    # dispose of things that are no longer needed.
    delete @$ef_props{qw(
        callback_name callback_priority
        callback_data callback_i object
        collection
    )};

    # return the event object.
    $ef_props->{complete} = 1;
    return $fire;
    
}

sub _return_check {
    my $fire    = shift;
    my %returns = %{ $fire->{$props}{return} };
    foreach my $cb_name (keys %returns) {
        next if $returns{$cb_name};
        return $fire->stop;
    }
    return 1;
}

1;
