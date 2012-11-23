# EventedObject

EventedObject started as a basic class in ntirc for registering event handlers and firing events. after being used in ntirc IRC client, Arinity IRC services package, foxy-java modular IRC bot, and other projects, EventedObject has become more complex and quite featureful.  
  
EventedObject supplies an (obviously objective) interface to store callbacks for events, fire events, and more. It provides
several methods for convenience and simplicity.

# Methods

EventedObject provides several convenient methods for firing and storing events.

## EventedObject->new()

Creates a new EventedObject. Typically, this method is overriden by a child class of EventedObject. It is unncessary
to call SUPER::new(), as EventedObject->new returns nothing more than an empty hash reference blessed to EventedObject.

```perl
my $obj = EventedObject->new();
```

## $obj->attach_event($event_name, \&callback, $callback_name, $priority)

Attaches an event callback the object. When the specified event is fired, each of the callbacks registered using this method
will be called by descending priority order (higher priority numbers are called first).

```perl
$obj->attach_event(some_event => \&my_callback, 'my.name', 20);
```

### Parameters

* __event_name:__ the name of the event.
* __callback:__ a CODE reference to be called when the event is fired.
* __callback_name:__ *optional*, the name of the callback being registered.
* __priority:__ *optional*, a numerical priority of the callback.

## $obj->delete_event($event_name, $callback_name)

Deletes an event callback from the object with the given callback name.  
Note: If a callback name is not specified in `->attach_event`, it is impossible to delete the event.

### Parameters

* __event_name:__ the name of the event.
* __callback_name:__ the name of the callback being removed.

## $obj->fire_event($event_name)

Fires the specified event, calling each callback that was registered with `->attach_event` in descending order of
their priorities.

```perl
$obj->fire_event('some_event');
```

### Parameters

* __event_name:__ the name of the event being fired.

## $obj->on($event_name, \&callback, $callback_name, $priority)

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
