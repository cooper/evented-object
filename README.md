# EventedObject

I doubt your objects have never been this evented. This concept is so incredible that we're using a noun
as a verb without being arrested by the grammar police.  
  
EventedObject started as a basic class in ntirc for registering event handlers and firing events. after being used in ntirc IRC client, Arinity IRC services package, foxy-java modular IRC bot, and other projects, EventedObject has become more complex and quite featureful.  
  
EventedObject supplies an (obviously objective) interface to store callbacks for events, fire events, and more. It provides
several methods for convenience and simplicity.

## History

EventedObject has evolved throughout the history of multiple projects, improving in each project it passed through.
It originated as IRC::EventedObject in NoTrollPlzDev's libirc. From then on, it was found in ntirc IRC client,
Arinity IRC Services, and foxy-java IRC client. The Arinity IRC Services package was the first to use a standalone
EventedObject; before then, it was only packaged with libirc.  
  
Today, EventedObject is found in all many different projects, usually included as a git submodule. A variety
of classes have been written specifically for the EventedObject framework, including a configuration classe,
an evented database interface, an event-driven socket protocol, and more.

## Author

Mitchell Cooper, "cooper" <mitchell@notroll.net>  
Copyright © 2011-2013. See LICENSE file.

## Compatibility notes

EventedObject versions 0.0 to 0.7 are entirely compatible - anything that worked in
version 0.0 or even compies of EventedObject before it was versioned also work in
version 0.7; however, some recent changes break the compatibility with these previous
versions in many cases.  

### Asynchronous improvements 1.0+
  
EventedObject 1.* series and above are incompatible with the former versions.
EventedObject 1.8+ is designed to be more thread-friendly and work well in asyncrhonous
programs, whereas the previous versions were not suitable for such uses.  
  
The main comptability issue is the arguments passed to the callbacks. In the earlier
versions, the evented object was *always* the first argument of *all* events,
until EventedObject 0.6 added the ability to pass a parameter to `->attach_event()` that
would tell EventedObject to omit the object from the callback's argument list.  
  
### Introduction of event objects 1.8+
  
The EventedObject series 1.8+ passes a hash reference `$event` instead of the
EventedObject as the first argument. `$event` contains information that was formerly held within the object
itself, such as `event_info`, `event_return`, and `event_data`. These are now accessible
through this new hash reference as `$event->{info}`, `$event->{return}`, `$event->{data}`,
etc. The object is now accessible with `$event->{object}`. (this has since been changed; see below.)  
  
Events are now stored in the `eventedObject.events` hash key instead of `events`, as
`events` was a tad bit too broad and could conflict with other libraries.  
  
In addition to these changes, the `attach_event()` method was deprecated in version 1.8
in favor of the new `register_event()`; however, it will remain in EventedObject until at
least the late 2.* series.  
  
### Alias changes 2.0+

Version 2.0 breaks things even more because `->on()` is now an alias for `->register_event()`
rather than the new deprecated `->attach_event()` as it always has been.
  
### Introduction of event methods 2.2+

Version 2.2+ introduces a new class, EventedObject::Event, which provides several methods for
event objects. These methods such as `$event->return` and `$event->object` replace the former hash keys
`$event->{return}`, `$event->{object}`, etc. The former hash interface is no longer supported and will lead to error.

## EventedObject methods

The EventedObject package provides several convenient methods for managing an event-driven object.

### EventedObject->new()

Creates a new EventedObject. Typically, this method is overriden by a child class of EventedObject. It is unncessary
to call SUPER::new(), as EventedObject->new returns nothing more than an empty hash reference blessed to EventedObject.

```perl
my $eo = EventedObject->new();
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
* __silent__: if true, the $event object will be omitted from the callback argument list.
* __data__: any data that will be stored as `$event->event_data` as the callback is fired.

#### Differences from ->attach_event()

Note: `->attach_event()` by default fires the callback with the evented object as its first argument unless told not to do so.
`->register_event()`, however, functions in the opposite sense and *never* passes the evented object as the first argument unless the `with_obj` option is passed.  
  
In the 1.* series and above, the event object is passed as the first argument unless the `silent` option is passed. The 
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

### $eo->delete_event($event_name, $callback_name)

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

### $eo->fire_event($event_name, @arguments)

Fires the specified event, calling each callback that was registered with `->attach_event()` in descending order of
their priorities.

```perl
$eo->fire_event('some_event');
```

* __event_name__: the name of the event being fired.
* __arguments__: *optional*, list of arguments to pass to event callbacks.

### $eo->on($event_name, \\&callback, $callback_name, $priority)

Alias for `->attach_event()`.

### $eo->fire($event_name)

Alias for `->fire_event()`.

### $eo->del($event_name, $callback_name)

**Deprecated**. Alias for `->delete_event()`.  
Do not use this. It is likely to removed in the near future.

### $eo->attach_event(...)

**Deprecated**. Use `->register_event()` instead.  
Do not use this. It is likely to removed in the near future.

## Event objects

Event objects are passed to all callbacks of an EventedObject (unless the `silent` parameter
was specified.) Event objects contain information about the event itself, the callback, the caller
of the event, event data, and more.  
  
Event objects replace the former values stored within the EventedObject itself. This new method
promotes asynchronous event firing.  
  
Event objects are specific to each firing. If you fire the same event twice in a row, the event
object passed to the callbacks the first time will not be the same as the second time. Therefore,
all modifications made by the event object's methods apply only to the callbacks remaining in this
particular fire. For example, `$event->cancel($callback)` will only cancel the supplied callback
once. The next time the event is fired, that cancelled callback will be called regardless.

### $event->object

Returns the evented object.

```perl
$event->object->delete_event('myEvent');
```

### $event->caller

Returns the value of `caller()` from within the `->fire()` method. This allows you to determine
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

### $event->called([$callback])

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

### $event->pending([$callback])

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

Coming soon.
