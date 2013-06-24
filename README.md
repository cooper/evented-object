# Evented::Object

**I doubt your objects have ever been this evented.** This concept is so incredible that we're using a noun
as a verb without being arrested by the grammar police.  
  
Evented::Object started as a basic class for registering event handlers and firing events. After many improvements
throughout several projects, Evented::Object has become far more complex and quite featureful.  
  
Evented::Object supplies an (obviously objective) interface to store and manage callbacks for events, fire events
upon objects, and more. It provides several methods for convenience and simplicity.

## Introduction

First and foremost, the goal of Evented::Object is to make your objects more evented than ever before.  
Allow us to explain what exactly it means for an object to be evented.

### Naming confusion

To clear some things up...  
  
'Evented::Object' refers to the Evented::Object package, but 'evented object' refers to an object
which is a member of the Evented::Object class or a class which inherits from the Evented::Object class.
'Event fire object' refers to an object representing an event fire.  

* __Evented::Object__: the class that provides methods for managing events.
* __Evented object__: an object that uses Evented::Object for event management.
* __Event fire object__: an object that represents an event fire.
* __Listener object__: another evented object that receives event notifications.

Evented::Object and its core packages are prefixed with `Evented::Object`.  
Packages which are specifically designed for use with Evented::Object are prefixed with `Evented::`.

### Purpose of Evented::Object

In short, Evented::Object allows you to attach event callbacks to an object (also known as a blessed hash reference)
and then fire events on that object. To relate, event fires are much like method calls. However, there can be many
handlers, many return values, and many responses rather than just one of each of these.

### Event callbacks

These handlers, known as callbacks, are called in descending order by priority. Numerically larger priorities are called
first. This allows you to place a certain callback in front of or behind another. They can modify other callbacks,
modify the evented object itself, and much more.

### Objective approach

Whereas many event systems involve globally unique event names, Evented::Object allows you to attach events to a specific
object. The event callbacks, information, and other data are stored secretly within the object itself. This is quite
comparable to the JavaScript event systems often found in browsers.

### Event fire objects
  
Another important concept of Evented::Object is the event fire object. It provides methods for fetching information relating
to the event being fired, callback being called, and more. Additionally, it provides an interface for modifying the
evented object and modifying future event callbacks.

### Listener objects

Additional evented objects can be registered as "listeners."  
  
Consider a scenario where you have a class whose objects represent a farm. You have another class which represents a cow.
You would like to use the same callback for all of the moos that occur on the farm, regardless of which cow initiated it.  
  
Rather than attaching an event callback to every cow, you can instead make the farm a listener of the cow. Then, you can
attach a single callback to your farm. If your cow's event for mooing is `moo`, your farm's event for mooing is `cow.moo`.  
  
The farm becomes a listener of the cow by using `$cow->add_listener($farm, 'cow')`.  

#### Potential looping references

The cow holds a weak reference to the farm, so you do not need to worry about deleting it later. This, however, means that
your listener object must also be referred to in another location in order for this to work. I doubt that will be a problem,
though.

#### Priorities and listeners::

Evented::Object is rather genius when it comes to callback priorities. With object listeners, it is as though
the callbacks belong to the object being listened to. Referring to the above example, if you attach a callback
on the farm object with priority 1, it will be called before your callback with priority 0 on the cow object.

#### Fire objects and listeners

When an event is fired on an object, the same event fire object is used for callbacks
belonging to both the evented object and its listening objects. Therefore, callback names
must be unique not only to the listener object but to the object being listened on as well.
  
You should also note the values of the event fire object:

* __$event->event_name__: the name of the event from the perspective of the listener; i.e. `cow.moo` (NOT `moo`)
* __$event->object__: the object being listened to; i.e. `$cow` (NOT `$farm`)

This also means that stopping the event from a listener object will cancel all remaining
callbacks, including those belonging to the evented object.

## History

Evented::Object has evolved throughout the history of multiple projects, improving in each project it passed through.
It originated as IRC::Evented::Object in NoTrollPlzDev's [libirc](https://github.com/cooper/libirc). From then on,
it was found in the [ntirc](https://github.com/cooper/ntirc) IRC client,
[Arinity](https://github.com/cooper/arinity) IRC Services, and
[foxy-java](https://github.com/cooper/foxy-java) IRC client. The Arinity IRC Services package was the first to use a standalone
Evented::Object; before then, it was only packaged with libirc.  
  
Today, Evented::Object is found in many different projects, usually included as a git submodule. A variety
of classes have been written specifically for the Evented::Object framework, including an evented configuration class,
an evented database interface, an event-driven socket protocol, and more.

### Classes designed upon Evented::Object

This is a list of classes designed exclusively upon Evented::Object.

* [__Evented::Configuration__](https://github.com/cooper/evented-configuration) - an event-driven configuration class that notifies when configuration values are modified.
* [__Evented::Database__](https://github.com/cooper/evented-database) - a package providing a database mechanism built upon Evented::Configuration.
* [__Evented::Query__](https://github.com/cooper/evented-query) - an evented database interface wrapping around DBI.
* [__Evented::Socket__](https://github.com/cooper/evented-socket) - an event-driven TCP socket protocol for networked programming.

This is a list of classes and frameworks which make major use of Evented::Object.

* [__Net::Async::Omegle__](https://github.com/cooper/net-async-omegle) - a complete, evented, and objective Perl interface to Omegle.com.
* [__libirc__](https://github.com/cooper/libirc) - an evented and objective Internet Relay Chat framework.
* [__libuic__](https://github.com/cooper/libirc) - an evented and objective Universal Internet Chat framework.

### Event-driven applications powered by Evented::Object

* [__kedler__](https://github.com/cooper/kedler) - an event-driven, modular, and excessively flexible IRC daemon written in Perl.
* [__uicd__](https://github.com/cooper/uicd) - daemon of the Univseral Internet Chat protocol based upon the libuic UIC library.
* [__simple-relay__](https://github.com/cooper/simple-relay) - a very basic IRC bot powered by libirc.
* [__foxy-java__](https://github.com/cooper/foxy-java) - a poorly named but highly extensible IRC bot powered by libirc.
* [__ntirc__](https://github.com/cooper/ntirc) - a Perl IRC client with the potential to be incredible.
* [__Arinity__](https://github.com/cooper/arinity) - an IRC services package written in Perl.
* [__ombot__](https://github.com/cooper/ombot) - an Omegle IRC bot powered by libirc and Net::Async::Omegle.
* [__PBot__](https://github.com/mattwb65/PBot) - an objective, event-driven IRC bot with a very original name.

## Author

[Mitchell Cooper](http://github.com/cooper), "cooper" <mitchell@notroll.net>  
Copyright © 2011-2013. See LICENSE file.  
  
* __IRC channel__: [irc.mac-mini.org #k](irc://irc.mac-mini.org/#k)
* __Email__: <mitchell@notroll.net>

Comments, complaints, and recommendations are accepted. IRC is my preferred communication medium.

## Compatibility notes

Evented::Object versions 0.0 to 0.7 are entirely compatible - anything that worked in
version 0.0 or even compies of Evented::Object before it was versioned also work in
version 0.7; however, some recent changes break the compatibility with these previous
versions in many cases.  

### Asynchronous improvements 1.0+
  
Evented::Object 1.* series and above are incompatible with the former versions.
Evented::Object 1.8+ is designed to be more thread-friendly and work well in asyncrhonous
programs, whereas the previous versions were not suitable for such uses.  
  
The main comptability issue is the arguments passed to the callbacks. In the earlier
versions, the evented object was *always* the first argument of *all* events,
until Evented::Object 0.6 added the ability to pass a parameter to `->attach_event()` that
would tell Evented::Object to omit the object from the callback's argument list.  
  
### Introduction of event fire objects 1.8+
  
The Evented::Object series 1.8+ passes a hash reference `$event` instead of the
Evented::Object as the first argument. `$event` contains information that was formerly held within the object
itself, such as `event_info`, `event_return`, and `event_data`. These are now accessible
through this new hash reference as `$event->{info}`, `$event->{return}`, `$event->{data}`,
etc. The object is now accessible with `$event->{object}`. (this has since been changed; see below.)  
  
Events are now stored in the `eventedObject.events` hash key instead of `events`, as
`events` was a tad bit too broad and could conflict with other libraries.  
  
In addition to these changes, the `attach_event()` method was deprecated in version 1.8
in favor of the new `register_event()`; however, it will remain in Evented::Object until at
least the late 2.* series.  
  
### Alias changes 2.0+

Version 2.0 breaks things even more because `->on()` is now an alias for `->register_event()`
rather than the former deprecated `->attach_event()`.
  
### Introduction of event methods 2.2+

Version 2.2+ introduces a new class, Evented::Object::EventFire, which provides several methods for
event fire objects. These methods such as `$event->return` and `$event->object` replace the former hash keys
`$event->{return}`, `$event->{object}`, etc. The former hash interface is no longer supported and will lead to error.

### Removal of ->attach_event() 2.9+

Version 2.9 removes the long-deprecated `->attach_event()` method in favor of the more
flexible `->register_event()`. This will break compatibility with any package still making
use of `->attach_event()`.

## Evented object methods

The Evented::Object package provides several convenient methods for managing an event-driven object.

### Evented::Object->new()

Creates a new Evented::Object. Typically, this method is overriden by a child class of Evented::Object. It is unncessary
to call `SUPER::new()`, as `Evented::Object->new()` returns nothing more than an empty hash reference blessed to Evented::Object.

```perl
my $eo = Evented::Object->new();
```

### $eo->register_event($event_name => \\&callback, %options)

Intended to be a replacement for the former `->attach_event()`.
Attaches an event callback the object. When the specified event is fired, each of the callbacks registered using this method
will be called by descending priority order (higher priority numbers are called first.)

```perl
$eo->register_event(myEvent => sub {
    ...
}, name => 'some.callback', priority => 200);
```

* __event_name__: the name of the event.
* __callback__: a CODE reference to be called when the event is fired.
* __options__: *optional*, a hash (not hash reference) of any of the below options.

#### %options - event handler options

**All of these options are optional**, but the use of a callback name is **highly recommended**.

* __name__: the name of the callback being registered. must be unique to this particular event.
* __priority__: a numerical priority of the callback.
* __data__: any data that will be stored as `$event->event_data` as the callback is fired.
* __no_fire_obj__: if true, the event fire object will not be prepended to the argument list.
* __with_evented_obj__: if true, the evented object will prepended to the argument list.
* __no_obj__: *Deprecated*. Use `no_fire_obj` instead.
* __eo_obj__: *Deprecated*. Use `with_evented_obj` instead.
* __with_obj__: *Deprecated*. Use `with_evented_obj` instead.

Note: the order of objects will always be `$eo`, `$event`, `@args`, regardless of omissions.  
By default, the argument list is `$event`, `@args`.

#### Differences from ->attach_event()

Note: `->attach_event()` by default fires the callback with the evented object as its first argument unless told not to do so.
`->register_event()`, however, functions in the opposite sense and *never* passes the evented object as the first argument unless the `with_evented_obj` option is passed.  
  
In the 1.* series and above, the event fire object is passed as the first argument unless the `no_fire_obj` option is passed. The 
evented object itself is now accessible from `$event->object`.  

### $eo->register_events(@events)

Registers several events at once. The arguments should be a list of hash references.
These references take the same options as `->register_event()`. Returns a list of return
values in the order that the events were specified.

```perl
$eo->register_events(
    { myEvent => \&my_event_1, name => 'cb.1', priority => 200 },
    { myEvent => \&my_event_2, name => 'cb.2', priority => 100 }
);
```

* __events__: an array of hash references to pass to `->register_event()`.

### $eo->delete_event($event_name => $callback_name)

Deletes an event callback from the object with the given callback name.  
If no callback name is specified, deletes all callbacks of this event.  
  
Returns a true value if any events were deleted, false otherwise.

```perl
# delete a single callback.
$eo->delete_event(myEvent => 'my.callback');

# delete all callbacks.
$eo->delete_event('myEvent');
```

* __event_name__: the name of the event.
* __callback_name__: *optional*, the name of the callback being removed.

### $eo->fire_event($event_name => @arguments)

Fires the specified event, calling each callback that was registered with `->register_event()` in descending order of
their priorities.

```perl
$eo->fire_event('some_event');
```

```perl
$eo->fire_event(some_event => $some_argument, $some_other_argument);
```

* __event_name__: the name of the event being fired.
* __arguments__: *optional*, list of arguments to pass to event callbacks.

### $eo->add_listener($other_eo, $prefix)

Makes the passed evented object a listener of this evented object. See the "listener objects" section
for more information on this feature.

```perl
$cow->add_listener($farm, 'cow');
```

* __other_eo__: the evented object that will listen.
* __prefix__: a string that event names will be prefixed with on the listener.

### $eo->delete_listener($other_eo)

Removes a listener of this evented object. See the "listener objects" section
for more information on this feature.

```perl
$cow->delete_listener($farm, 'cow');
```

* __other_eo__: the evented object that will listen.
* __prefix__: a string that event names will be prefixed with on the listener.


### $eo->on($event_name => \\&callback, %options)

Alias for `->register_event()`.

### $eo->fire($event_name => @arguments)

Alias for `->fire_event()`.

### $eo->del(...)

**Deprecated**. Alias for `->delete_event()`.  
Do not use this. It is likely to removed in the near future.

### $eo->attach_event(...)

**Removed** in version 2.9. Use `->register_event()` instead.

## Evented::Object procedural functions

The Evented::Object package provides some functions for use. These functions typically are
associated with more than one evented object or none at all.

### fire_events_together(@events)

Fires multiple events at the same time. This allows you to fire multiple similar events
on several evented objects at the same time. It essentially pretends that the callbacks
are all for the same event and all on the same object.  
  
It follows priorities throughout
all of the events and all of the objects, so it is ideal for firing similar or identical
events on multiple objects.  
  
The same event fire object is used throughout this entire routine. This means that
callback names must unique among all of these objects and events. It also means that
stopping an event from any callback will cancel all remaining callbacks, regardless to
which event or which object they belong.  
  
The function takes a list of array references in the form of:  
`[ $evented_object, event_name => @arguments ]`

```perl
Evented::Object::fire_events_together(
    [ $server,  user_joined_channel => $user, $channel ],
    [ $channel, user_joined         => $user           ],
    [ $user,    joined_channel      => $channel        ]
);
```

* __events__: an array of events in the form of `[$eo, event_name => @arguments]`.

## Event fire object methods

Event fire objects are passed to all callbacks of an Evented::Object. Event fire objects
contain information about the event itself, the callback, the caller of the event, event
data, and more.  
  
Event fire objects replace the former values stored within the Evented::Object itself. This new method
promotes asynchronous event firing.  
  
Event fire objects are specific to each firing. If you fire the same event twice in a row, the event
object passed to the callbacks the first time will not be the same as the second time. Therefore,
all modifications made by the event fire object's methods apply only to the callbacks remaining in this
particular fire. For example, `$event->cancel($callback)` will only cancel the supplied callback
once. The next time the event is fired, that cancelled callback will be called regardless.

### $event->object

Returns the evented object.

```perl
$event->object->delete_event('myEvent');
```

### $event->caller

Returns the value of `caller(1)` from within the `->fire()` method. This allows you to determine
from where the event was fired.

```perl
my $name   = $event->event_name;
my @caller = $event->caller;
say "Package $caller[0] line $caller[2] called event $name";
```

### $event->stop

Cancels all remaining callbacks. This stops the rest of the event firing. After a callback
calls `$event->stop`, it is stored as `$event->stopper`.

```perl
# ignore messages from trolls
if ($user eq 'noah') {
    # user is a troll.
    # stop further callbacks.
    return $event->stop;
}
```

### $event->stopper

Returns the callback which called `$event->stop`.

```perl
if ($event->stopper) {
    say 'Event was stopped by '.$event->stopper;
}
```

### $event->called($callback)

If no argument is supplied, returns the number of callbacks called so far, including the current one.
If a callback argument is supplied, returns whether that particular callback has been called.

```perl
say $event->called, 'callbacks have been called so far.';
```

```perl
if ($event->called('some.callback')) {
    say 'some.callback has been called already.';
}
```

* __callback__: *optional*, the callback being checked.

### $event->pending($callback)

If no argument is supplied, returns the number of callbacks pending to be called, excluding the current one.
If a callback argument is supplied, returns whether that particular callback is pending for being called.

```perl
say $event->pending, 'callbacks are left.';
```

```perl
if ($event->pending('some.callback')) {
    say 'some.callback will be called soon.';
}
```

* __callback__: *optional*, the callback being checked.

### $event->cancel($callback)

Cancels the supplied callback once.

```perl
if ($user eq 'noah') {
    # we don't love noah!
    $event->cancel('send.hearts');
}
```

* __callback__: the callback to be cancelled.

### $event->return_of($callback)

Returns the return value of the supplied callback.

```perl
if ($event->return('my.callback')) {
    say 'my.callback returned a true value';
}
```

* __callback__: the desired callback.

### $event->last

Returns the most recent previous callback called.  
This is also useful for determining which callback was the last to be called.

```perl
say $event->last, ' was called before this one.';
```

```perl
my $event = $eo->fire_event('myEvent');
say $event->last, ' was the last callback called.';
```

### $event->last_return

Returns the last callback's return value.

```perl
if ($event->last_return) {
    say 'the callback before this one returned a true value.';
}
else {
    die 'the last callback returned a false value.';
}
```

### $event->event_name

Returns the name of the event.

```perl
say 'the event being fired is ', $event->event_name;
```

### $event->callback_name

Returns the name of the current callback.

```perl
say 'the current callback being called is ', $event->callback_name;
```

### $event->callback_priority

Returns the priority of the current callback.

```perl
say 'the priority of the current callback is ', $event->callback_priority;
```

### $event->callback_data

Returns the data supplied to the callback when it was registered, if any.

```perl
say 'my data is ', $event->callback_data;
```

## Example

This example demonstrates basic Evented::Object subclasses,
priorities of event callbacks, as well as event fire objects and their methods.

```perl
package Person;

use warnings;
use strict;
use feature 'say';
use parent 'Evented::Object';

use Evented::Object;
```

Creates a new person object. This is nothing special. Evented::Object does not require any specific constructor to be called.

```perl
sub new {
    my ($class, %opts) = @_;
    bless \%opts, $class;
}
```

Fire birthday event and increment age.

```perl
# have a birthday.
sub have_birthday {
    my $person = shift;
    $person->fire(birthday => ++$person->{age});
}

```

In some other package...

```perl
package main;
```

Create a person named Jake at age 19.

```perl
my $jake = Person->new(name => 'Jake', age => 19);
```

Add an event callback that assumes Jake is under 21.

```perl
$jake->on(birthday => sub {
    my ($event, $new_age) = @_;

    say 'not quite 21 yet...';

}, name => '21-soon');
```

Add an event callback that checks if Jake is 21 and cancels the above callback if he is.

```perl
$jake->on(birthday => sub {
    my ($event, $new_age) =  @_;

    if ($new_age == 21) {
        say 'time to get drunk!';
        $event->cancel('21-soon');
    }

}, name => 'finally-21', priority => 1);
```

Jake has two birthdays.

```perl
# Jake's 20th birthday.
$jake->have_birthday;

# Jake's 21st birthday.
$jake->have_birthday;

# Because 21-soon has a lower priority than finally-21,
# finally-21 will cancel 21-soon if Jake is 21.
```

The result is as follows:

```
not quite 21 yet...
time to get drunk!
```
