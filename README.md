Perl interface to the Flowdock API
==================================

A simple pimple Perl module that mimicks more or less how the Ruby Gem for the Flowdock API works.

A **HUGE** work in progress, so please help me make it not suck.

API Notes
---------
Have a look at the official documentation for more information on the API:
https://www.flowdock.com/api

Dependencies
------------
Flowdock::Push requires LWP::UserAgent and Moose.

Flowdock::REST and Flowdock::Stream requires Moose, Moose::Util::TypeConstraints, LWP::UserAgent, JSON::XS, and Email::Valid.

Known Issues
------------
HTML currently doesn't work when sending a message to the Team Inbox via Flowdock::REST. It works fine through Flowdock::Push, however, so use that if you can.

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

Sending a message to the Team Inbox as an authenticated user (may be broken...sorry):

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

You can stream from a single or multiple flows as such:

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
      event => 'message', #Or 'status' for status updates
      flow => 'myflow',
      content => 'Hello, how are you?!',
      tags => ["todo", "beans"]
   },
   {
      event => 'status'
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