# EventedObject

This is a simple base class for evented objects in Perl. Objects of this class are not
constructed directly but are constructed by a more specific child class. This is basically
as simple as it possibly could be, but it is very useful in many places.

## Example

Example child class

```perl

package Person;

use warnings;
use strict;
use EventedObject;
use base 'EventedObject';

sub new {
    my ($class, $name, $age) = @_;
    bless { name => $name, age => $age }, $class
}

sub say_happy_birthday {
    my $self = shift;
    print "Happy $$self{age} birthday $$self{name}!\n"
}

```

Example use of that class

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

## Author

Mitchell Cooper, "cooper" <mitchell@notroll.net>
