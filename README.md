# Forever

Small daemon framework **for ruby**, with logging, error handler watcher and much more.

The idea of the name and some concept was taken by [forever for node.js](https://raw.github.com/indexzero/forever) written by Charlie Robbins.

## Why?

There are a lot of alternatives, one of the best is [resque](https://github.com/defunkt/resque), so why another daemons framework?
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
$ gem install forever
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

## Monitor your daemon(s):

List daemons:

``` sh
$ forever list
PID     RSS     CPU   CMD
19838   32512   1.6   Forever: bin/githubwatcher
```

Stop daemon(s):

``` sh
$ forever stop foo
Do you want really stop Forever: bin/foo  with pid 19538? y
Killing process Forever: bin/foo  with pid 19538...
```

That's all!