Perl interface to the Flowdock API
==================================

A simple pimple Perl module that mimicks more or less how the Ruby Gem for the Flowdock API works.

This module has been rewritten(ish) and has replaced Moose with Moo and LWP::UserAgent with HTTP::Tiny


API Notes
---------
Have a look at the official documentation for more information on the API:
https://www.flowdock.com/api

Dependencies
------------

* Perl >= 5.10
* Moo
* HTTP::Tiny (Flowdock::REST and Flowdock::Push)
* Net::Curl::Easy (Flowdock::Stream)
* IO::Socket::SSL
* JSON::XS
* Email::Valid
* URI::Encode

Usage Examples
----------------------

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
   external_user_name => 'Perl Flowdock',
   tags => ['chat', 'api']});
```

Authenticating with username/password or a token:

```
use Flowdock::REST;
my $flow = Flowdock::REST->new(
   username => 'foo@bar.baz',
   password => 'PASSWORD',        # Password
   personal_token => 'YOUR_TOKEN' # or token
   org => 'path-e-tec',
   flow => 'myflow' # Optional; convenient if you're only using one flow
   );
```

Sending a message to the chat box or setting your status as an authenticated user:

```
my $response = $rest_message->send_message({
   event => 'message', # Or 'status' for status updates
   flow => 'myflow', # If you didn't specify flow in new()
   content => 'Hooray!',
   tags => ["todo", "git"],
});
```

Sending a message to the Team Inbox as an authenticated user (may be broken for HTML...sorry):

```
my $response = $rest_message->send_message({
   flow => 'myflow',
   event => 'mail',
   source => 'Perl Flowdock API',
   address => 'foo@bar.baz',
   subject => 'Test message',
   content => "<h2>Hooray!</h2><p>This is an HTML message.</p>",
   tags => ['perl'],
   link => 'http://flowdock.com'});
```

You can send multiple messages at once:

```
my $response = $rest_message->send_message(\%one_hash, \%two_hash, \%three_hash, \%four);
```

You can stream from a single or multiple flows:

```
use Flowdock::Stream;
my $stream = Flowdock::Stream->new(
   username => 'Pablo',            # Use a username/password combo
   password => 'Picasso',
	 personal_token => 'YOUR_TOKEN', # Or use a token instead
	 org => 'foobar');

my $callback = sub {
   my $data = shift;
   if($data->{event} eq 'message') { print "$data->{content} \n" };
}
$stream->stream_flow('main', $callback); #One flow
$stream->stream_flows(['foo','main'], $callback); #Multiple flows
```

https://flowdock.com/api/message-types lists what you can expect from the hashref for each mesasge type that can be parsed by your callback function.

License, et al.
-------
Copyright (C) 2012, Sam Tran.

This module is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0. For details, see the full text of the license in the file LICENSE.

This program is distributed in the hope that it will be useful, but it is provided "as is" and without any express or implied warranties. For details, see the full text of the license in the file LICENSE.
