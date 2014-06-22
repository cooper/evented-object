# NAME

**Evented::Object** - a base class that allows you to attach event callbacks to an object
and then fire events on that object.

# SYNOPSIS

Demonstrates basic Evented::Object subclasses, priorities of event callbacks,
and fire objects and their methods.

    package Person;
    
    use warnings;
    use strict;
    use 5.010;
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
        my ($fire, $new_age) = @_;
    
        say 'not quite 21 yet...';
    
    }, name => '21-soon');
    
    # Add an event callback that checks if Jake is 21 and cancels the above callback if he is.
    $jake->on(birthday => sub {
        my ($fire, $new_age) =  @_;
    
        if ($new_age == 21) {
            say 'time to get drunk!';
            $fire->cancel('21-soon');
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
    

# DESCRIPTION

**I honestly doubt your objects have ever been this evented in your entire life.** This
concept is so incredible that we're using a noun as a verb without being arrested by the
grammar police.

Evented::Object started as a basic class for registering event handlers and firing events.
After many improvements throughout several projects, Evented::Object has become far more
complex and quite featureful.

Evented::Object supplies an (obviously objective) interface to store and manage callbacks
for events, fire events upon objects, and more. It provides several methods for
convenience and simplicity.

## Naming confusion

To clear some things up...

'Evented::Object' refers to the Evented::Object package, but 'evented object' refers to an
object which is a member of the Evented::Object class or a class which inherits from the
Evented::Object class. 'Fire object' refers to an object representing an event fire.

- **Evented::Object**: this class that provides methods for managing events.
- **Evented object**: `$eo` - refers to an object that uses Evented::Object for event management.
- **Fire object**: `$fire` or `$event` - an object that represents an event fire.
- **Collection**: `$col` or `$collection` - represents a group of callbacks about to be fired.
- **Listener object**: another evented object that receives event notifications.

Evented::Object and its core packages are prefixed with `Evented::Object`.
Packages which are specifically designed for use with Evented::Object are prefixed with
`Evented::`.

## Purpose of Evented::Object

In short, Evented::Object allows you to attach event callbacks to an object (also known as
a blessed hash reference) and then fire events on that object. To relate, event fires are
much like method calls. However, there can be many handlers, many return values, and many
responses rather than just one of each of these.

## Event callbacks

These handlers, known as callbacks, are called in descending order by priority.
Numerically larger priorities are called first. This allows you to place a certain
callback in front of or behind another. They can modify other callbacks, modify the
evented object itself, and much more.

## Objective approach

Whereas many event systems involve globally unique event names, Evented::Object allows
you to attach events to a specific object. The event callbacks, information, and other
data are stored secretly within the object itself. This is quite comparable to the
JavaScript event systems often found in browsers.

## Fire objects

Another important concept of Evented::Object is the fire object. It provides methods
for fetching information relating to the event being fired, callback being called, and
more. Additionally, it provides an interface for modifying the evented object and
modifying future event callbacks. Fire objects belong to the
Evented::Object::EventFire class.

Fire objects are specific to each firing. If you fire the same event twice in a row,
the event object passed to the callbacks the first time will not be the same as the second
time. Therefore, all modifications made by the fire object's methods apply only to
the callbacks remaining in this particular fire. For example,
`$fire->cancel($callback)` will only cancel the supplied callback once. The next
time the event is fired, that cancelled callback will be called regardless.

See ["Fire object methods"](#fire-object-methods) for more information.

## Listener objects

Additional evented objects can be registered as "listeners."

Consider a scenario where you have a class whose objects represent a farm. You have
another class which represents a cow. You would like to use the same callback for all of
the moos that occur on the farm, regardless of which cow initiated it.

Rather than attaching an event callback to every cow, you can instead make the farm a
listener of the cow. Then, you can attach a single callback to your farm. If your cow's
event for mooing is `moo`, your farm's event for mooing is `cow.moo`.

### Potential looping references

The cow holds a weak reference to the farm, so you do not need to worry about deleting it
later. This, however, means that your listener object must also be referred to in another
location in order for this to work. I doubt that will be a problem, though.

### Priorities and listeners

Evented::Object is rather genius when it comes to callback priorities. With object
listeners, it is as though the callbacks belong to the object being listened to. Referring
to the above example, if you attach a callback on the farm object with priority 1, it will
be called before your callback with priority 0 on the cow object.

### Fire objects and listeners

When an event is fired on an object, the same fire object is used for callbacks
belonging to both the evented object and its listening objects. Therefore, callback names
must be unique not only to the listener object but to the object being listened on as
well.

You should also note the values of the fire object:

- **$fire->event\_name**: the name of the event from the perspective of the listener;
i.e. `cow.moo` (NOT `moo`)
- **$fire->object**: the object being listened to; i.e. `$cow` (NOT `$farm`)

This also means that stopping the event from a listener object will cancel all remaining
callbacks, including those belonging to the evented object.

## Registering callbacks to classes

Evented::Object 3.9 adds the ability to register event callbacks to a subclass of
Evented::Object. The methods `->register_callback()`, `->delete_event()`,
`->delete_callback`, etc. can be called in the form of `MyClass->method()`.
Evented::Object will store these callbacks in a special hash hidden in the package's
symbol table.  

Any object of this class will borrow these callbacks from the class. They will be
incorporated into the callback collection as though they were registered directly on the
object.

Note: Events cannot be fired on a class.

### Prioritizing

When firing an event, any callbacks on the class will sorted by priority just as if they
were registered on the object. Whether registered on the class or the object, a callback
with a higher priority will be called before one of a lower priority.

### Subclassing

If an evented object is blessed to a subclass of a class with callbacks registered to it,
the object will NOT inherit the callbacks associated with the parent class. Callbacks
registered to classes ONLY apply to objects directly blessed to the class.

## Class monitors

Evented::Object 4.0 introduces a "class monitor" feature. This allows an evented object to
be registered as a "monitor" of a specific class/package. Any event callbacks that are
added from that class to any evented object of any type will trigger an event on the
monitor object - in other words, the \`caller\` of \`->register\_callback()\`, regardless of
the object.

An example scenario of when this might be useful is an evented object for debugging all
events being registered by a certain package. It would log all of them, making it easier
to find a problem.

## Collections

Sometimes it is useful to prepare an event fire before actually calling it. The group
of callbacks that are about to be called are represented by a collection object.
Collections are returned by the 'prepare' methods.

Collections are especially useful for firing events with special options. This usually
looks something like:

    $eo->prepare(event_name => @args)->fire(some_fire_option => $value);

See ["Collection methods"](#collection-methods) for more information.

# COMPATIBILITY

Evented::Object versions 0.0 to 0.7 are entirely compatible - anything that worked in
version 0.0 or even compies of Evented::Object before it was versioned also work in
version 0.7; however, some recent changes break the compatibility with these previous
versions in many cases.

## Asynchronous improvements 1.0+

Evented::Object 1.\* series and above are incompatible with the former versions.
Evented::Object 1.8+ is designed to be more thread-friendly and work well in asyncrhonous
programs, whereas the previous versions were not suitable for such uses.

The main comptability issue is the arguments passed to the callbacks. In the earlier
versions, the evented object was always the first argument of all events, until
Evented::Object 0.6 added the ability to pass a parameter to `->attach_event()` that
would tell Evented::Object to omit the object from the callback's argument list.

## Introduction of fire info 1.8+

The Evented::Object series 1.8+ passes a hash reference `$fire` instead of the
Evented::Object as the first argument. `$fire` contains information that was formerly
held within the object itself, such as `event_info`, `event_return`, and `event_data`.
These are now accessible through this new hash reference as `$fire->{info}`,
`$fire->{return}`, `$fire->{data}`, etc. The object is now accessible with
`$fire->{object}`. (this has since been changed; see below.)

Events are now stored in the `eventedObject.events` hash key instead of `events`, as
`events` was a tad bit too broad and could conflict with other libraries.

In addition to these changes, the `->attach_event()` method was deprecated in version
1.8 in favor of the new `->register_callback()`; however, it will remain in
Evented::Object until at least the late 2.\* series.

## Alias changes 2.0+

Version 2.0 breaks things even more because `->on()` is now an alias for
`->register_callback()` rather than the former deprecated `->attach_event()`.

## Introduction of fire objects 2.2+

Version 2.2+ introduces a new class, Evented::Object::EventFire, which provides several
methods for fire objects. These methods such as `$fire->return` and
`$fire->object` replace the former hash keys `$fire->{return}`,
`$fire->{object}`, etc. The former hash interface is no longer supported and will
lead to error.

## Removal of ->attach\_event() 2.9+

Version 2.9 removes the long-deprecated `->attach_event()` method in favor of the
more flexible `->register_callback()`. This will break compatibility with any package
still making use of `->attach_event()`.

## Rename to Evented::Object 3.54+

In order to correspond with other 'Evented' packages, EventedObject was renamed to
Evented::Object. All packages making use of EventedObject will need to be modified to use
Evented::Object instead. This change was made pre-CPAN.

## Removal of deprecated options 5.0+

Long-deprecated callback options may no longer behave as expected in older versions.
Specifically, Evented::Object used to try to guess whether it should insert the event
fire object and evented object to the callback arguments. Now, it does not try to guess
but instead only listens to the explicit options.

# Evented object methods

The Evented::Object package provides several convenient methods for managing an
event-driven object.

## Evented::Object->new()

Creates a new Evented::Object. Typically, this method is overriden by a child class of
Evented::Object. It is unncessary to call `SUPER::new()`, as
`Evented::Object->new()` returns nothing more than an empty hash reference blessed to
Evented::Object.

    my $eo = Evented::Object->new();

## $eo->register\_callback($event\_name => \\&callback, %options)

Attaches an event callback the object. When the specified event is fired, each of the
callbacks registered using this method will be called by descending priority order
(numerically higher priority numbers are called first.)

    $eo->register_callback(myEvent => sub {
        ...
    }, name => 'some.callback', priority => 200);

**Parameters**

- **event\_name**: the name of the event.
- **callback**: a CODE reference to be called when the event is fired.
- **options**: _optional_, a hash (not hash reference) of any of the below options.

**%options - event handler options**

All of these options are **optional**, but the use of a callback name is **highly
recommended**.

- **name**: the name of the callback being registered. must be unique to this particular
event.
- **priority**: a numerical priority of the callback.
- **before**: the name of a callback to precede.
- **after**: the name of a callback to succeed.
- **data**: any data that will be stored as `$fire->event_data` as the callback is
fired.
- **with\_eo**: if true, the evented object will prepended to the argument list.
- **no\_fire\_obj**: if true, the fire object will not be prepended to the argument list.

Note: the order of objects will always be `$eo`, `$fire`, `@args`, regardless of
omissions. By default, the argument list is `$fire`, `@args`.

Note: only one of `priority`, `before`, and `after` will be respected. Although more
complex prioritization is in the works, Evented::Object is not currently capable of
resolving priority conflicts with before and after.

## $eo->register\_callbacks(@events)

Registers several events at once. The arguments should be a list of hash references. These
references take the same options as `->register_callback()`. Returns a list of return
values in the order that the events were specified.

    $eo->register_callbacks(
        { myEvent => \&my_event_1, name => 'cb.1', priority => 200 },
        { myEvent => \&my_event_2, name => 'cb.2', priority => 100 }
    );

**Parameters**

- **events**: an array of hash references to pass to `->register_callback()`.

## $eo->delete\_event($event\_name)

Deletes all callbacks registered for the supplied event.

Returns a true value if any events were deleted, false otherwise.

    $eo->delete_event('myEvent');

**Parameters**

- **event\_name**: the name of the event.

## $eo->delete\_callback($event\_name)

Deletes an event callback from the object with the given callback name.

Returns a true value if any events were deleted, false otherwise.

    $eo->delete_callback(myEvent => 'my.callback');

**Parameters**

- **event\_name**: the name of the event.
- **callback\_name**: the name of the callback being removed.

## $eo->fire\_event($event\_name => @arguments)

Fires the specified event, calling each callback that was registered with
`->register_callback()` in descending order of their priorities.

    $eo->fire_event('some_event');

    $eo->fire_event(some_event => $some_argument, $some_other_argument);

**Parameters**

- **event\_name**: the name of the event being fired.
- **arguments**: _optional_, list of arguments to pass to event callbacks.

## $eo->fire\_once($event\_name => @arguments)

Fires the specified event, calling each callback that was registered with
`->register_callback()` in descending order of their priorities.

Then, all callbacks for the event are deleted. This method is useful for situations where
an event will never be fired more than once.

    $eo->fire_once('some_event');
    $eo->fire_event(some_event => $some_argument, $some_other_argument);
    # the second does nothing because the first deleted the callbacks

**Parameters**

- **event\_name**: the name of the event being fired.
- **arguments**: _optional_, list of arguments to pass to event callbacks.

## $eo->add\_listener($other\_eo, $prefix)

Makes the passed evented object a listener of this evented object. See the "listener
objects" section for more information on this feature.

    $cow->add_listener($farm, 'cow');

**Parameters**

- **other\_eo**: the evented object that will listen.
- **prefix**: a string that event names will be prefixed with on the listener.

## $eo->fire\_events\_together(@events)

Since Evented::Object 5.0, the `fire_events_together()` function can be used as a method
on evented objects. See the documentation for the function in ["Procedural functions"](#procedural-functions).

## $eo->delete\_listener($other\_eo)

Removes a listener of this evented object. See the "listener objects" section for more
information on this feature.

    $cow->delete_listener($farm, 'cow');

**Parameters**

- **other\_eo**: the evented object that will listen.
- **prefix**: a string that event names will be prefixed with on the listener.

## $eo->delete\_all\_events()

Deletes all events and all callbacks from the object. If you know that an evented object
will no longer be used in your program, by calling this method you can be sure that no
cyclical references from within callbacks will cause the object to be leaked.

# Preparation methods

Evented::Object 5.0 introduces a means by which callbacks can be prepared before being
fired. This is most useful for firing events with special fire options.

## $eo->prepare\_event(event\_name => @arguments)

Prepares a single event for firing. Returns a collection object representing the callbacks
for the event.

    # an example using the fire option return_check.
    $eo->prepare_event(some_event => @arguments)->fire('return_check');

## $eo->prepare\_together(@events)

The preparatory method equivalent to `->fire_events_together`. 

## $eo->prepare(...)

A smart method that uses the best guess between `->prepare_event` and
`->prepare_together`.

    # uses ->prepare_event()
    $eo->prepare(some_event => @arguments);
    
    # uses ->prepare_together()
    $eo->prepare(
       [ some_event => @arguments ],
       [ some_other => @other_arg ]
    );

# Procedural functions

The Evented::Object package provides some functions for use. These functions typically are
associated with more than one evented object or none at all.

## fire\_events\_together(@events)

Fires multiple events at the same time. This allows you to fire multiple similar events on
several evented objects at the same time. It essentially pretends that the callbacks are
all for the same event and all on the same object.

It follows priorities throughout all of the events and all of the objects, so it is ideal
for firing similar or identical events on multiple objects.

The same fire object is used throughout this entire routine. This means that
callback names must unique among all of these objects and events. It also means that
stopping an event from any callback will cancel all remaining callbacks, regardless to
which event or which object they belong.

The function takes a list of array references in the form of:
`[ $evented_object, event_name => @arguments ]`

    Evented::Object::fire_events_together(
        [ $server,  user_joined_channel => $user, $channel ],
        [ $channel, user_joined         => $user           ],
        [ $user,    joined_channel      => $channel        ]
    );
    

Since Evented::Object 5.0, `->fire_events_together` can be used as a method on any
evented object.

    $eo->fire_events_together(
        [ some_event => @arguments ],
        [ some_other => @other_arg ]
    );
    

The above example would formerly be achieved as:

    Evented::Object::fire_events_together(
        [ $eo, some_event => @arguments ],
        [ $eo, some_other => @other_arg ]
    );
    

However, other evented objects may be specified even when this is used as a method.
Basically, anywhere that an object is missing will fall back to the object on which
the method was called.

    $eo->fire_events_together(
        [ $other_eo, some_event => @arguments ],
        [            some_other => @other_arg ] # no object, falls back to $eo
    );
    

**Parameters**

- **events**: an array of events in the form of `[$eo, event_name => @arguments]`.

## safe\_fire($eo, $event\_name, @args)

Safely fires an event. In other words, if the \`$eo\` is not an evented object or is not
blessed at all, the call will be ignored. This eliminates the need to use `blessed()`
and `->isa()` on a value for testing whether it is an evented object.

    Evented::Object::safe_fire($eo, myEvent => 'my argument');

**Parameters**

- **eo**: the evented object.
- **event\_name**: the name of the event. 
- **args**: the arguments for the event fire.

## add\_class\_monitor($pkg, $some\_eo)

Registers an evented object as the class monitor for a specific package. See the
section above for more details on class monitors and their purpose.

    my $some_eo  = Evented::Object->new;
    my $other_eo = Evented::Object->new;
    
    $some_eo->on('monitor:register_callback', sub {
        my ($event, $eo, $event_name, $cb) = @_;
        # $eo         == $other_eo
        # $event_name == "blah"
        # $cb         == callback hash from ->register_callback()
        say "Registered $$cb{name} to $eo for $event_name"; 
    });
    
    Evented::Object::add_class_monitor('Some::Class', $some_eo);
    
    package Some::Class;
    $other_eo->on(blah => sub{}); # will trigger the callback above

- **pkg**: a package whose event activity you wish to monitor.
- **some\_eo**: some arbitrary event object that will respond to that activity.

## delete\_class\_monitor($pkg, $some\_eo)

Removes an evented object from its current position as a monitor for a specific package.
See the section above for more details on class monitors and their purpose.

    Evented::Object::delete_class_monitor('Some::Class', $some_eo)

- **pkg**: a package whose event activity you're monitoring.
- **some\_eo**: some arbitrary event object that is responding to that activity.

# Collection methods

["Collections"](#collections) are returned by the 'prepare' methods. They represent a group of callbacks
that are about to be fired.

## $col->fire(@options)

Fires the pending callbacks with the specified options, if any. If the callbacks have not
yet been sorted, they are sorted before the event is fired.

    $eo->prepare(some_event => @arguments)->fire('safe');
    

**Parameters**

- **options**: _optional_, a mixture of boolean and key:value options for the event fire.

**@options**

- **caller**: _requires value_, use an alternate `[caller 1]` value for the event fire.
This is typically only used internally.
- **return\_check**: _boolean_, if true, the event will yield that it was stopped if any
of the callbacks return a false value. Note however that if one callbacks returns false,
the rest will still be called. The fire object will only yield stopped status after all
callbacks have been called and any number of them returned false.
- **safe**: _boolean_, wrap all callback calls in `eval` for safety. if any of them fail,
the event will be stopped at that point with the error.
- **fail\_continue**: _boolean_, if `safe` above is enabled, this tells the fire to continue
even if one of the callbacks fails. This could be dangerous if any of the callbacks
expected a previous callback to be done when it actually failed.

## $col->sort\_callbacks

Sorts the callbacks according to `priority`, `before`, and `after` options.

# Fire object methods

["Fire objects"](#fire-objects) are passed to all callbacks of an Evented::Object (unless the silent
parameter was specified.) Fire objects contain information about the event itself,
the callback, the caller of the event, event data, and more.

## $fire->object

Returns the evented object.

    $fire->object->delete_event('myEvent');

## $fire->caller

Returns the value of `caller(1)` from within the `->fire()` method. This allows you
to determine from where the event was fired.

    my $name   = $fire->event_name;
    my @caller = $fire->caller;
    say "Package $caller[0] line $caller[2] called event $name";

## $fire->stop($reason)

Cancels all remaining callbacks. This stops the rest of the event firing. After a callback
calls $fire->stop, the name of that callback is stored as `$fire->stopper`.

If the event has already been stopped, this method returns the reason for which the
fire was stopped or "unspecified" if no reason was given.

    # ignore messages from trolls
    if ($user eq 'noah') {
        # user is a troll.
        # stop further callbacks.
        return $fire->stop;
    }

- **reason**: _optional_, the reason for stopping the event fire.

## $fire->stopper

Returns the callback which called `$fire->stop`.

    if ($fire->stopper) {
        say 'Fire was stopped by '.$fire->stopper;
    }

## $fire->called($callback)

If no argument is supplied, returns the number of callbacks called so far, including the
current one. If a callback argument is supplied, returns whether that particular callback
has been called.

    say $fire->called, 'callbacks have been called so far.';
    
    if ($fire->called('some.callback')) {
        say 'some.callback has been called already.';
    }
    

**Parameters**

- **callback**: _optional_, the callback being checked.

## $fire->pending($callback)

If no argument is supplied, returns the number of callbacks pending to be called,
excluding the current one. If a callback  argument is supplied, returns whether that
particular callback is pending for being called.

    say $fire->pending, ' callbacks are left.';
    
    if ($fire->pending('some.callback')) {
        say 'some.callback will be called soon (unless it gets canceled)';
    }

**Parameters**

- **callback**: _optional_, the callback being checked.

## $fire->cancel($callback)

Cancels the supplied callback once.

    if ($user eq 'noah') {
        # we don't love noah!
        $fire->cancel('send.hearts');
    }

**Parameters**

- **callback**: the callback to be cancelled.

## $fire->return\_of($callback)

Returns the return value of the supplied callback.

    if ($fire->return_of('my.callback')) {
        say 'my.callback returned a true value';
    }

**Parameters**

- **callback**: the desired callback.

## $fire->last

Returns the most recent previous callback called.
This is also useful for determining which callback was the last to be called.

    say $fire->last, ' was called before this one.';
    
    my $fire = $eo->fire_event('myEvent');
    say $fire->last, ' was the last callback called.';

## $fire->last\_return

Returns the last callback's return value.

    if ($fire->last_return) {
        say 'the callback before this one returned a true value.';
    }
    else {
        die 'the last callback returned a false value.';
    }

## $fire->event\_name

Returns the name of the event.

    say 'the event being fired is ', $fire->event_name;

## $fire->callback\_name

Returns the name of the current callback.

    say 'the current callback being called is ', $fire->callback_name;

## $fire->callback\_priority

Returns the priority of the current callback.

    say 'the priority of the current callback is ', $fire->callback_priority;

## $fire->callback\_data($key)

Returns the data supplied to the callback when it was registered, if any. If the data
is a hash reference, an optional key parameter can specify a which value to fetch.

    say 'my data is ', $fire->callback_data;
    say 'my name is ', $fire->callback_data('name');

**Parameters**

- **key**: _optional_, a key to fetch a value if the data registered was a hash. 

## $fire->data($key)

Returns the data supplied to the collection when it was fired, if any. If the data
is a hash reference, an optional key parameter can specify a which value to fetch.

    say 'fire data is ', $fire->data;
    say 'fire time was ', $fire->data('time');

**Parameters**

- **key**: _optional_, a key to fetch a value if the data registered was a hash. 

# Aliases

A number of aliases exist for convenience, but some of the names are rather broad. For
that reason, they are only recommended for use when you are sure that other subclassing
will not interfere.

## $eo->on(...)

Alias for `$eo->register_callback()`.

## $eo->del(...)

If one argument provided, alias for `$eo->delete_event`.

If two arguments provided, alias for `$eo->delete_callback`.

## $eo->fire(...)

Alias for `$eo->fire_event()`.

## $eo->register\_event(...)

Alias for `$eo->register_callback()`.

## $eo->register\_events(...)

Alias for `$eo->register_callbacks()`.

## $fire->eo

Alias for `$fire->object`.

# AUTHOR

[Mitchell Cooper](https://github.com/cooper) <cooper@cpan.org>

Copyright � 2011-2013. Released under BSD license.

- **IRC**: [irc.notroll.net #k](irc://irc.notroll.net/k)
- **Email**: [cooper@cpan.org](mailto:cooper@cpan.org)
- **CPAN**: [COOPER](http://search.cpan.org/~cooper/)
- **GitHub**: [cooper](https://github.com/cooper)

Comments, complaints, and recommendations are accepted. IRC is my preferred communication
medium. Bugs may be reported on
[RT](https://rt.cpan.org/Public/Dist/Display.html?Name=Evented-Object).
