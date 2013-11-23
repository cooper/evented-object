#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 21;
use Evented::Object;

##################
### Basic test ###
##################

my $eo = Evented::Object->new;

my @results;

$eo->register_callback(hi => sub {
    push @results, 100;
}, priority => 100);

$eo->register_callback(hi => sub {
    push @results, 200;
}, priority => 200);

$eo->register_callback(hi => sub {
    push @results, -5;
}, priority => -5);

$eo->register_callback(hi => sub {
    push @results, 0;
});

$eo->fire_event('hi');

is($results[0], 200, '200 priority should be called first');
is($results[1], 100, '100 priority should be called second');
is($results[2], 0,   '0 priority should be called third');
is($results[3], -5,  '-5 priority should be called fourth');

##############################
### Deleting all callbacks ###
##############################

@results = ();
$eo->delete_event('hi');
$eo->fire_event('hi');

is(scalar @results, 0, 'deleting entire event');

##################################
### Deleting a single callback ###
##################################

my ($lost, $won);

$eo->register_callback(hi => sub {
    $won = 1;
}, priority => 100);

$eo->register_callback(hi => sub {
    $lost = 1;
}, name => 'loser');

$eo->delete_callback('hi', 'loser');
$eo->fire_event('hi');

isnt($lost, 1, 'deleted single callback');
is($won, 1, 'other callback still called');

#################################################
### Cancelling a callback from within another ###
#################################################

($lost, $won) = (undef, undef);
my ($pending_bad, $pending_good);

$eo->register_callback(hi => sub {
    shift->cancel('loser');
}, priority => 100);


$eo->register_callback(hi => sub {
    my $fire = shift;
    $won = 1;
    $pending_bad  = 1 if $fire->pending('loser');
    $pending_good = $fire->pending('pending_future');
});

$eo->register_callback(hi => sub {
    $lost = 1;
}, name => 'loser');

$eo->register_callback(hi => sub {
}, name => 'pending_future', priority => -5);


$eo->fire_event('hi');

isnt($lost, 1, 'cancel single callback');
is($won, 1, 'other callback still called');
isnt($pending_bad, 1, 'canceled callback is not still pending');
ok($pending_good, 'another callback still pending');

###########################
### Listener priorities ###
###########################

@results = ();

my $farm = Evented::Object->new;
my $cow  = Evented::Object->new;
$cow->add_listener($farm, 'cow');

$cow->on('moo' => sub {
    push @results, 'l200';
}, priority => 200);

$farm->on('cow.moo' => sub {
    push @results, -100;
}, priority => -100);

$cow->on('moo' => sub {
    push @results, 50;
}, priority => 50);

$farm->on('cow.moo' => sub {
    push @results, 'l100';
}, priority => 100);

$cow->fire_event('moo');

is($results[0], 'l200', '200 priority should be called first');
is($results[1], 'l100', '100 priority should be called second');
is($results[2], 50,     '50 priority should be called third');
is($results[3], -100,   '-100 priority should be called fourth');

############################
### Callback information ###
############################

$farm->delete_event('cow.moo');
$cow->delete_event('moo');

$cow->on(moo => sub {
    my $fire = shift;
    is($fire->event_name, 'moo', 'event name is moo');
    is($fire->object, $cow, 'evented object is cow');
    is($fire->callback_name, 'no', 'callback name is no');
}, priority => 200, name => 'no');

$farm->on('cow.moo' => sub {
    my $fire = shift;
    is($fire->event_name, 'cow.moo', 'event name is cow.moo');
    is($fire->object, $cow, 'evented object is cow');
    is($fire->callback_name, 'yes', 'callback name is yes');
}, priority => -100, name => 'yes');

$cow->fire_event('moo');