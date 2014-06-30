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

our $VERSION = '5.48';
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
#   data            some data to fire with the event. esp. good for things that might be
#                   useful at times but not accessed frequently enough to be an argument.
#
sub fire {
    my ($collection, @options) = @_;
    
    # handle options.
    my ($caller, $data) = $collection->{caller};
    while (@options) {
        my $opt = shift @options;
        
        if ($opt eq 'caller')   { $caller = shift @options } # custom caller
        if ($opt eq 'data')     { $data   = shift @options } # fire data
        
        # boolean option.
        $collection->{$opt} = 1 if $boolopts{$opt};
        
    }
    
    # create fire object.
    my $fire = Evented::Object::EventFire->new(
        caller     => $caller ||= [caller 1], # $fire->caller
        data       => $data,                  # $fire->data
        collection => $collection
    );
    
    # if it hasn't been sorted, do so.
    my $callbacks = $collection->{pending} or return $fire;
    $collection->sort if not $collection->{sorted};
    
    # if return_check is enabled, add a callback to be fired last that will
    # check the return values. this is basically hackery using a dummy object.
    my $cb = {
        name   => 'eventedObject.returnCheck',
        caller => $caller,
        code   => \&_return_check
    };
    push @$callbacks, [
        -inf,                                                       # [0] $priority
        [ $dummy ||= Evented::Object->new, 'returnCheck', [] ],     # [1] $group
        $cb                                                         # [2] $cb
    ] if $collection->{return_check};
    
    # call them.
    return $collection->_call_callbacks($fire);
    
}

# sorts the callbacks, trying its best to listen to before and after.
# perhaps one day this could be done more efficiently - it currently must
# loop through twice: once for before and after, once for numerical sort.
sub sort : method {
    my $collection = shift;
    my @remaining  = @{ $collection->{pending} };
    my @sorted;
    
    # sort by before/after.
    my (%waited, %done);
    while (@remaining) {
        my $item = shift @remaining;
        my $cb   = $item->[2];
        
        # already did this one.
        next if defined $done{ $cb->{name} };
                
        # there is no defined priority, but there is before/after.
        if ($item->[0] eq 'nan' and my $ref_cb_name = $cb->{before} // $cb->{after}) {
        
            # have we dealt with the referred callback already?
            if (defined(my $ref_priority = $done{$ref_cb_name})) {
                $item->[0] = ++$ref_priority if $cb->{before};
                $item->[0] = --$ref_priority if $cb->{after};
            }
            
            # no, the referred callback is probably pending. maybe.
            else {
            
                # if we've not waited on this callback already, append it to remaining.
                # then maybe by the next time we get around to it, the callback will exist.
                if (!$waited{ $cb->{name} }) {
                    $waited{ $cb->{name} } = 1;
                    push @remaining, $item;
                    next;
                }
                
                # if we have waited on the callback, this is the point at which we give up.
                $item->[0] = 0;
                                
            }
        }
        
        # if we have a priority, we're done with this one.
        $done{ $cb->{name} } = $item->[0];
        push @sorted, $item;
        
    }

    # the final sort by numerical priority.
    @{ $collection->{pending} } = sort { $b->[0] <=> $a->[0] } @sorted;
    
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
    my $remaining = $collection->{pending} or return;
    $ef_props->{collection} = $collection;
    
    # call each callback.
    while (my $entry = shift @$remaining) {
        my ($priority, $group, $cb)  = @$entry;
        my ($eo, $event_name, $args) = @$group;
        ref $eo && $eo->isa('Evented::Object') or return;
        
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
            $ef_props->{error}{ $cb->{name} } = $err;
            $ef_props->{exception} = $err;
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
    my %returns = %{ $fire->{$props}{return} || {} };
    foreach my $cb_name (keys %returns) {
        next if $returns{$cb_name};
        return $fire->stop("$cb_name returned false with return_check enabled");
    }
    return 1;
}

1;
