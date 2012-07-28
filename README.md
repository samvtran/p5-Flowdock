Perl interface to the Flowdock API *REWRITE BRANCH*
==================================

A simple pimple Perl module that mimicks more or less how the Ruby Gem for the Flowdock API works.

This branch is a rewrite of the module whilst also taking advantage of new API functionality.

Current focus: REST API, moving Moose to Moo, and LWP::UserAgent to HTTP::Tiny


API Notes
---------
Have a look at the official documentation for more information on the API:
https://www.flowdock.com/api

Dependencies
------------
New work on Flowdock::REST requires only Moo, HTTP::Tiny, JSON::XS, and Email::Valid and at least Perl 5.10

(NOTE: The following have no yet been rewritten)
Flowdock::Push requires LWP::UserAgent and Moose.

Flowdock::Stream require Moose, Moose::Util::TypeConstraints, LWP::UserAgent, JSON::XS, and Email::Valid.

Usage Example
----------------------

To use this experimental module without installing it anywhere, place lib where your Perl script is and use ```-Ilib```

Pushing an anonymous message to the Team Inbox:

```
use Flowdock::Push;
my $flow = Flowdock::Push->new(
   api_token => 'YOUR_ALPHANUMERIC_TOKEN',
   source => 'myapp',
   project => 'my project',
   from => { name => 'John Doe', address => 'foo@bar.com' });
$flow->push_to_team_inbox({
   subject => 'Hello, World!',
   content => '<h2>IT'S ALIVE!</h2><p>It's sort of a pun</p>',
   tags => ['not','really'],
   link => 'http://flowdock.com'});
```

Pushing an anonymous message to the chat:

```
$flow->push_to_chat({
   content => 'How\'s it going?',
   external_user_name => 'Perlicious',
   tags => ['chat', 'api']});
```

Authenticating with username/password:

```
use Flowdock::REST;
my $flow = Flowdock::REST->new(
   username => 'foo@bar.baz',
   password => 'frumpy',
   org => 'kiteward',
   );
```

or with a token:

```
use Flowdock::REST;
my $flow = Flowdock::REST->new(
   personal_token => 'YOUR_TOKEN',
   org => 'foobar',
   );
```

Sending a message to the chat box or setting your status as an authenticated user:

```
my $response = $rest_message->send_message({
   event => 'message', #Or 'status' for status updates
   flow => 'myflow',
   content => 'Hello, how are you?!',
   tags => ["todo", "beans"]});
```

Sending a message to the Team Inbox as an authenticated user (may be broken for HTML...sorry):

```
my $response = $rest_message->send_message({
   flow => 'myflow',
   event => 'mail',
   source => 'Perl Flowdock API',
   address => 'foo@bar.baz',
   subject => 'Test message',
   content => "<h2>IT'S ALIVE</h2><p>This is only slightly crazy.</p>",
   tags => ['cool', 'beans'],
   link => 'http://flowdock.com'});
```

You can stream from a single or multiple flows:

```
use Flowdock::Stream;
my $stream = Flowdock::Stream->new(
    username => 'Pablo',            # Use a username/password combo
    password => 'Picasso',
	personal_token => 'YOUR_TOKEN', # Or use a token instead
	org => 'foobar');
my $function = sub {
             my $data = shift;
             if ($data) {
                if($data->{event} eq 'message') { print "$data->{content} \n" }
             }
             return 'true';
}
$stream->stream_flow('main', $function); #One flow
$stream->stream_flows(['foo','main'], $function); #Multiple flows
```

But wait! There's more! 
----------------------
You can send multiple messages at once:

```
my $response = $rest_message->send_message(\%one_hash, \%two_hash, \%three_hash, \%four);
```

or by separating hashes with commas:

```
my $response = $rest_message->send_message(
   {
      event => 'message',
      flow => 'myflow',
      content => 'Hello, how are you?!',
      tags => ["todo", "beans"]
   },
   {
      event => 'status',
      flow => 'myflow',
      content => 'I just set a status message too!'
   }
);
```

You can view whatever gets returned by using Data::Dumper:

```
use Data::Dumper;
print Dumper($response);
```
For Flowdock::REST, list_flows returns an array of hashes while get_flow returns a single hash of the flow.

For Flowdock::Stream, stream_flows and stream_flow return a hash of whatever was sent from the server.

License, et al.
-------
Copyright (C) 2012, Sam Tran.

This module is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0. For details, see the full text of the license in the file LICENSE.

This program is distributed in the hope that it will be useful, but it is provided "as is" and without any express or implied warranties. For details, see the full text of the license in the file LICENSE.
