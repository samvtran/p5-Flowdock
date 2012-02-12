Perl interface to the Flowdock API
==================================

A simple pimple Perl module that mimicks more or less how the Ruby Gem for the Flowdock API works.

A **HUGE** work in progress, so please help me make it not suck.

API Notes
---------
Have a look at the official documentation for more information on the API:
https://www.flowdock.com/help/api_documentation

Usage Example
----------------------

```
use Flowdock;
my $flow = Flowdock->new(
   api_token => 'YOUR_ALPHANUMERIC_TOKEN',
   source => 'myapp',
   project => 'my project',
   from => { name => 'John Doe', address => 'foo@bar.com' });

$flow->send_message({
   subject => 'Hello, World!',
   content => '<h2>IT'S ALIVE!</h2><p>It's sort of a pun</p>',
   tags => ['not','really'],
   link => 'http://flowdock.com'});
```