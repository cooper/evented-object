# EventedObject

EventedObject started as a basic class in ntirc for registering event handlers and firing events. after being used in ntirc IRC client, Arinity IRC services package, foxy-java modular IRC bot, and other projects, EventedObject has become more complex and quite featureful.  
  
EventedObject supplies an (obviously objective) interface to store callbacks for events, fire events, and more. It provides
several methods for convenience and simplicity.

# Compatibility notes

EventedObject versions 0.0 to 0.7 are entirely compatible - anything that worked in
version 0.0 or even compies of EventedObject before it was versioned also work in
version 0.7; however, some recent changes break the compatibility with these previous
versions in many cases.  
  
EventedObject 1.* series and above are incompatible with the former versions.
EventedObject 1.8+ is designed to be more thread-friendly and work well in asyncrhonous
programs, whereas the previous versions were not suitable for such uses.  
  
The main comptability issue is the arguments passed to the callbacks. In the earlier
versions, the EventedObject instance was *always* the first argument of *all* events,
until EventedObject 0.6 added the ability to pass a parameter to `attach_event()` that
would tell EventedObject to omit the object from the callback's argument list.  
  
The new EventedObject series, 1.8+, passes a hash reference `$event` instead of the
EventedObject. `$event` contains information that was formerly held within the object
itself, such as `event_info`, `event_return`, and `event_data`. These are now accessible
through this new hash reference as `$event->{info}`, `$event->{return}`, `$event->{data}`,
etc. The object is now accessible with `$event->{object}`.  
  
Events are now stored in the `eventedObject.events` hash key instead of `events`, as
`events` was a tad bit too broad and could conflict with other libraries.  
  
In addition to these changes, the `attach_event()` method was deprecated in version 1.8
in favor of the new `register_event()`; however, it will remain in EventedObject until at
least the late 2.* series.  
  
# Event objects

Event objects are passed to all callbacks of EventedObject (unless the silent parameter was specified.) Event objects contain
information about the event itself, the callback, the caller of the event, event data, and more. Event objects replace the
former values stored within the EventedObject itself.

## Values in event objects

The following values are accessible through event objects, but some are only useful during certain times.

### General

These values may be accessed at any time.

* __object:__ (hashref) the EventedObject instance.
* __name:__ (string) the name of the event.
* __caller:__ (arrayref) the caller() information from fire_event().
* __return:__ (hashref) callback_name:return_value hash reference containing the return values of each callback called so far.
* __count:__ (integer) the number of callbacks called so far (or the total number if completed.)

### Callback-specific

These values are specific to callback being called currently and are only useful from
within callbacks themselves.

* __last_return:__ (any) the return value of the callback directly before the one being fired.
* __callback:__ (coderef) the code reference of the callback being fired.
* __callback_name:__ (string) the name of the callback being fired.
* __priority:__ (integer) the priority of the callback being fired.
* __data:__ (any) the data passed to `->register_event` when the callback was registered.
* __stop:__ (boolean) stops the firing of the event. if set to true within a callback, no later callbacks will be called.

### Post-fire

These values are intended to be used after all callbacks have been fired.

* __last_return:__ (any) the return value of the last callback.
* __stop:__ (boolean) true if the event firing was stopped.
* __stopper:__ (string) the name of the callback that stopped the firing of the event.

# Methods

EventedObject provides several convenient methods for firing and storing events.

## EventedObject->new()

Creates a new EventedObject. Typically, this method is overriden by a child class of EventedObject. It is unncessary
to call SUPER::new(), as EventedObject->new returns nothing more than an empty hash reference blessed to EventedObject.

```perl
my $obj = EventedObject->new();
```

## $obj->register_event($event_name => \\&callback, %options)

Intended to be a replacement for the former `->attach_event`.
Attaches an event callback the object. When the specified event is fired, each of the callbacks registered using this method
will be called by descending priority order (higher priority numbers are called first).

```perl
$obj->register_event(myEvent => sub {
    ...
}, name => 'some.callback', priority => 200, silent => 1);
```

### Parameters

* __event_name:__ the name of the event.
* __callback:__ a CODE reference to be called when the event is fired.
* __options:__ *optional*, a hash (not hash reference) of any of the below options.

### %options - event handler options

**All of these options are optional**, but the use of a callback name is **highly recommended**.

* __name:__ the name of the callback being registered. must be unique to this particular event.
* __priority:__ a numerical priority of the callback.
* __silent:__ if true, the $event object will be omitted from the callback argument list.
* __data:__ any data that will be stored as 'event_data' as the callback is fired.

Note: `->attach_event` by default fires the callback with the EventedObject as its first argument unless told not to do so.
`->register_event` in the 0.* series, however, functions in the opposite sense and *never* passes the EventedObject as the first argument
unless the `with_obj` option is passed.  
In the 1.* series and above, the event object is passed as the first argument unless the `silent` option is passed. The EventedObject
instance itself is now accessible through `$event->{object}`.

### Parameters

* __event_name:__ the name of the event.
* __callback:__ a CODE reference to be called when the event is fired.
* __callback_name:__ *optional*, the name of the callback being registered.
* __priority:__ *optional*, a numerical priority of the callback.
* __silent:__ *optional*, true if this callback should be called without the EventedObject as its first argument.
* __data:__ *optional*, any data that will be stored as 'event_data' as the callback is fired.

## $obj->delete_event($event_name, $callback_name)

Deletes an event callback from the object with the given callback name.  
If no callback name is specified, deletes all callbacks of this event.  
Note: If a callback name is not specified in `->attach_event`, it is impossible to delete the event.  
  
Returns a true value if any events were deleted, false otherwise.

### Parameters

* __event_name:__ the name of the event.
* __callback_name:__ *optional*, the name of the callback being removed.

## $obj->fire_event($event_name)

Fires the specified event, calling each callback that was registered with `->attach_event` in descending order of
their priorities.

```perl
$obj->fire_event('some_event');
```

### Parameters

* __event_name:__ the name of the event being fired.

## $obj->on($event_name, \\&callback, $callback_name, $priority)

Alias to `->attach_event`.

## $obj->del($event_name, $callback_name)

Alias to `->delete_event`.

## $obj->fire($event_name)

Alias to `->fire_event`.

# Example

Example child class.

```perl

package Person;

use warnings;
use strict;
use EventedObject;
use parent 'EventedObject';

sub new {
    my ($class, %options) = @_;
    return bless \%options, $class;
}

sub say_happy_birthday {
    my $self = shift;
    print "Happy $$self{age} birthday $$self{name}!\n";
}

```

Example use of that class.

```perl

use warnings;
use strict;
use Person;

my $jake = Person->new(name => 'Jake', age => 20);
$jake->attach_event(had_birthday => sub {
    $jake->{age}++;
    $jake->say_happy_birthday;
});

$jake->fire_event('had_birthday');

```

# History

EventedObject has evolved throughout the history of multiple projects, improving in each project it passed through.
It originated as IRC::EventedObject in NoTrollPlzDev's libirc. From then on, it was found in ntirc IRC client,
Arinity IRC Services, and foxy-java IRC client. Arinity IRC Services package was the first to use a standalone
EventedObject: before then, it was only packaged with libirc. Today, EventedObject is found in all of the official
UIC software, including the libuic UIC library and the UICd Universal Internet Chat server daemon.

# Author

Mitchell Cooper, "cooper" <mitchell@notroll.net>
