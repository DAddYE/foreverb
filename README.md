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

You can use +every+ method to schedule repetitive tasks.

``` rb
# Taken from, examples/sample
Forever.run do
  dir File.expand_path('../', __FILE__) # Default is ../../__FILE__

  on_ready do
    puts inspect
  end

  every 1.seconds do
    puts "Every one seconds"
  end

  every 2.seconds do
    puts "Every two seconds"
  end

  every 3.seconds do
    puts "Every three seconds, long task"
    sleep 10
  end

  every 1.day, :at => "18:28" do
    puts "Every day at 18:28"
  end

  on_error do |e|
    puts "Boom raised: #{e.message}"
  end

  on_exit do
    puts "Bye bye"
  end
end
```

You should see in logs this:

```
$ examples/sample
=> Pid not found, process seems don't exist!
=> Process demonized with pid 1252 with Forever v.0.1.7
[11/07 18:27:08] #<Forever dir:/Developer/src/extras/foreverb/examples, file:/Developer/src/extras/foreverb/examples/sample, log:/Developer/src/extras/foreverb/examples/log/sample.log, pid:/Developer/src/extras/foreverb/examples/tmp/sample.pid jobs:4>
[11/07 18:27:08] Every one seconds
[11/07 18:27:08] Every two seconds
[11/07 18:27:08] Every three seconds, long task
[11/07 18:27:09] Every one seconds
[11/07 18:27:10] Every two seconds
...
[11/07 18:27:17] Every one seconds
[11/07 18:27:18] Every one seconds
[11/07 18:27:18] Every two seconds
[11/07 18:27:19] Every three seconds, long task
...
[11/07 18:27:58] Every one seconds
[11/07 18:27:59] Every one seconds
[11/07 18:28:00] Every two seconds
[11/07 18:28:00] Every one seconds
[11/07 18:28:00] Every day at 18:28
=> Found pid 1252...
=> Killing process 1252...
[11/07 18:28:18] Bye bye
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
```

That's all!

## Author

DAddYE, you can follow me on twitter [@daddye](http://twitter.com/daddye)