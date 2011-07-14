# Foreverb

Small daemon framework **for ruby**, with logging, error handler, scheduling and much more.

My inspiration was [forever for node.js](https://raw.github.com/indexzero/forever) written by Charlie Robbins.
My scheduling inspiration was taken from [clockwork](https://github.com/adamwiggins/clockwork) written by Adam Wiggins.

## Why?

There are some alternatives, one of the best is [resque](https://github.com/defunkt/resque), so why another daemons framework?
In my servers I've several daemons and what I need is:

* easily watch the process (memory, cpu)
* easily manage exceptions
* easily see logs
* easily start/stop/restart daemon

As like [sinatra](https://github.com/sinatra/sinatra) and [padrino](https://github.com/padrino/padrino-framework) I need a
**thin** framework to do these jobs in few seconds. This mean that:

* I can create a new job quickly
* I can watch, start, stop it quickly

So, if you have my needs, **Forever** can be the right choice for you.

## Install:

``` sh
$ gem install foreverb
```

## Deamon Example:

Place your script under your standard directory, generally on my env is _bin_ or _scripts_.

In that case is: ```bin/foo```

``` rb
#!/usr/bin/ruby
require 'rubygems' unless defined?(Gem)
require 'forever'
require 'mail'

Forever.run do
  ##
  # You can set these values:
  #
  # dir  "foo"     # Default: File.expand_path('../../', __FILE__)
  # file "bar"     # Default: __FILE__
  # log  "bar.log" # Default: File.expand_path(dir, '/log/[file_name].log')
  # pid  "bar.pid" # Default: File.expand_path(dir, '/tmp/[file_name].pid')
  #

  on_error do |e|
    Mail.deliver do
      delivery_method :sendmail, :location => `which sendmail`.chomp
      to      "d.dagostino@lipsiasoft.com"
      from    "exceptions@lipsiasoft.com"
      subject "[Foo Watcher] #{e.message}"
      body    "%s\n  %s" % [e.message, e.backtrace.join("\n  ")]
    end
  end

  on_ready do
    require 'bundler/setup'
    require 'foo'
    Foo.start_loop
  end
end
```

Assign right permission:

``` sh
$ chmod +x bin/foo
```

start the daemon:

``` sh
$ bin/foo
```

you should see an output like:

``` sh
$ bin/foo
=> Process demonized with pid 19538
```

you can stop it:

``` sh
$ bin/foo stop
=> Found pid 19538...
=> Killing process 19538...
```

## Scheduling

You can use `every` method to schedule repetitive tasks.

Every allow the option `:at` to specify hour or minute and the option `:last` to specify when the `every` must start to loop.

`:last`: can be nil or a Time class. Default is 0.<br />
`:at`: can be nil, a string or an array. Default is nil.

``` rb
every 1.second, :at => '19:30'         # => every second since 19:30
every 1.minute, :at => ':30'           # => every minute but first call wait xx:30
every 5.minutes, :at => '18:'          # => every five minutes but first call was at 18:xx
every 1.day, :at => ['18:30', '20:30'] # => every day only at 18:30 and 20:30
every 60.second, :last => Time.now     # => will be fired 60 seconds after you launch the app
```

Remember that `:at`:

* accept only 24h format
* you must always provide the colon `:`

So looking our [example](https://github.com/DAddYE/foreverb/blob/master/examples/sample):

``` rb
Forever.run do
  dir File.expand_path('../', __FILE__) # Default is ../../__FILE__

  on_ready do
    puts "All jobs will will wait me for 1 second"; sleep 1
  end

  every 10.seconds, :at => "#{Time.now.hour}:00" do
    puts "Every 10 seconds but first call at #{Time.now.hour}:00"
  end

  every 1.seconds, :at => "#{Time.now.hour}:#{Time.now.min+1}" do
    puts "Every one second but first call at #{Time.now.hour}:#{Time.now.min}"
  end

  every 10.seconds do
    puts "Every 10 second"
  end

  every 20.seconds do
    puts "Every 20 second"
  end

  every 15.seconds do
    puts "Every 15 seconds, but my task require 10 seconds"; sleep 10
  end

  every 10.seconds, :at => [":#{Time.now.min+1}", ":#{Time.now.min+2}"] do
    puts "Every 10 seconds but first call at xx:#{Time.now.min}"
  end

  on_error do |e|
    puts "Boom raised: #{e.message}"
  end

  on_exit do
    puts "Bye bye"
  end
end
```

Running the example with the following code:

``` sh
$ examples/sample; tail examples/log/sample.log; examples/sample stop
```

you should see:

```
=> Pid not found, process seems don't exist!
=> Process demonized with pid 11509 with Forever v.0.2.0
[14/07 15:46:56] All jobs will will wait me for 1 second
[14/07 15:46:57] Every 10 second
[14/07 15:46:57] Every 20 second
[14/07 15:46:57] Every 15 seconds, but my task require 10 seconds
[14/07 15:47:00] Every one second but first call at 15:47
[14/07 15:47:00] Every 10 seconds but first call at xx:47
[14/07 15:47:01] Every one second but first call at 15:47
[14/07 15:47:02] Every one second but first call at 15:47
[14/07 15:47:03] Every one second but first call at 15:47
[14/07 15:47:04] Every one second but first call at 15:47
[14/07 15:47:05] Every one second but first call at 15:47
[14/07 15:47:06] Every one second but first call at 15:47
[14/07 15:47:07] Every 10 second
[14/07 15:47:07] Every one second but first call at 15:47
[14/07 15:47:08] Every one second but first call at 15:47
[14/07 15:47:09] Every one second but first call at 15:47
[14/07 15:47:10] Every 10 seconds but first call at xx:47
[14/07 15:47:10] Every one second but first call at 15:47
[14/07 15:47:11] Every one second but first call at 15:47
[14/07 15:47:12] Every 15 seconds, but my task require 10 seconds
...
[14/07 15:47:42] Every 15 seconds, but my task require 10 seconds
[14/07 15:47:42] Every one second but first call at 15:47
[14/07 15:47:43] Every one second but first call at 15:47
[14/07 15:47:44] Every one second but first call at 15:47
[14/07 15:47:45] Every one second but first call at 15:47
[14/07 15:47:46] Every one second but first call at 15:47
[14/07 15:47:47] Every 10 second
^C
=> Found pid 11509...
=> Killing process 11509...
[14/07 15:48:40] Bye bye
```

## Monitor your daemon(s):

List daemons:

``` sh
$ foreverb list
PID     RSS     CPU   CMD
19838   32512   1.6   Forever: bin/githubwatcher
```

Stop daemon(s):

``` sh
$ foreverb stop foo
Do you want really stop Forever: bin/foo  with pid 19538? y
Killing process Forever: bin/foo  with pid 19538...

$ foreverb stop --all -y
Killing process Forever: /usr/bin/githubwatcher with pid 2824
Killing process Forever: examples/sample with pid 2836
```

That's all!

## Extras

To see a most comprensive app running _foreverb_ + _growl_ see [githubwatcher gem](https://github.com/daddye/githubwatcher)

## Author

DAddYE, you can follow me on twitter [@daddye](http://twitter.com/daddye)