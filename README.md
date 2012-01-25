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
* no blocking jobs
* no blocking queue

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

  before :each do # or if you prefer before :all
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
`:at`: can be nil, a string or an array of formatted strings. Default is nil.

``` rb
every 1.second,   :at => '19:30'            # => every second since 19:30
every 1.minute,   :at => ':30'              # => every minute but first call wait xx:30
every 5.minutes,  :at => '18:'              # => every five minutes but first call was at 18:xx
every 1.day,      :at => ['18:30', '20:30'] # => every day only at 18:30 and 20:30
every 60.seconds, :last => Time.now         # => will be fired 60 seconds after you launch the app
```

Remember that `:at`:

* accept only 24h format
* you must always provide the colon `:`

So looking our [example](https://github.com/DAddYE/foreverb/blob/master/examples/sample):

``` rb
Forever.run do
  dir File.expand_path('../', __FILE__) # Default is ../../__FILE__

  before :all do
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
    # This doesn't block other jobs and your queue !!!!!!!
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
$ examples/sample; tail -f -n 150 examples/log/sample.log; examples/sample stop
```

you should see:

```
=> Pid not found, process seems doesn't exist!
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

## Filters

In foreverb we have a couple of filters, `before` and `after`, like rspec you should be able to filter `before :all` or `before :each`.

``` rb
before :all do
  puts "This will be ran only at start"
end

before :each do
  puts "Do that before each job"
end

# ...  here jobs ...

after :all do
  puts "This will be ran only at shutdown"
end

after :each do
  puts "Do that after each job"
end
```

## CLI

### Help:

``` sh
$ foreverb help
Tasks:
  foreverb help [TASK]                       # Describe available tasks or one specific task
  foreverb list                              # List Forever running daemons
  foreverb restart [DAEMON] [--all] [--yes]  # Restart one or more matching daemons
  foreverb start [DAEMON] [--all] [--yes]    # Start one or more matching daemons
  foreverb stop [DAEMON] [--all] [--yes]     # Stop one or more matching daemons
  foreverb tail [DAEMON]                     # Tail log of first matching daemon
  foreverb update [DAEMON] [--all] [--yes]   # Update config from one or more matching daemons
  foreverb version                           # show the version number
```

### List daemons:

``` sh
$ foreverb list
     RUNNING  /Developer/src/Extras/githubwatcher/bin/githubwatcher
     RUNNING  /Developer/src/Extras/foreverb/examples/sample
Reading config from: /Users/DAddYE/.foreverb
```

### Monitor daemons (with ps):

``` sh
$ foreverb list -m
PID   RSS     CPU    CMD
5528  168 Mb  0.1 %  Forever: /Developer/src/Extras/githubwatcher/bin/githubwatcher
5541  18 Mb   0.0 %  Forever: /Developer/src/Extras/foreverb/examples/sample
```

### Stop daemon(s):

``` sh
$ foreverb stop foo
Do you want really stop Forever: bin/foo  with pid 19538? y
Killing process Forever: bin/foo  with pid 19538...

$ foreverb stop --all -y
Killing process Forever: /usr/bin/githubwatcher with pid 2824
Killing process Forever: examples/sample with pid 2836
```

### Start daemon(s):

``` sh
$ foreverb start github
Do you want really start /Developer/src/Extras/githubwatcher/bin/githubwatcher? y
=> Found pid 5528...
=> Killing process 5528...
=> Process demonized with pid 14925 with Forever v.0.2.2
```

as for stop we allow `--all` and `-y`

### Restart daemon(s)

``` sh
$ foreverb restart github
Do you want really restart /Developer/src/Extras/githubwatcher/bin/githubwatcher? y
=> Found pid 5528...
=> Killing process 5528...
=> Process demonized with pid 14925 with Forever v.0.2.2
```

as for stop we allow `--all` and `-y`

### Tail logs

``` sh
$ foreverb tail github
[22/07 11:22:17] Quering git://github.com/DAddYE/lipsiadmin.git...
[22/07 11:22:17] Quering git://github.com/DAddYE/lightbox.git...
[22/07 11:22:17] Quering git://github.com/DAddYE/exception-notifier.git...
[22/07 11:22:17] Quering git://github.com/DAddYE/lipsiablog.git...
[22/07 11:22:17] Quering git://github.com/DAddYE/purple_ruby.git...
```

you can specify how many lines show with option `-n`, default is `150`

### Update config

This command would be helpful if you change `pid` `log` path, in this way the global config file `~/.foreverb` will be update
using latest informations from yours deamons

Note that you can personalize the config file setting `FOREVER_PATH` matching your needs.

``` sh
$ foreverb update github
Do you want really update config from /Developer/src/Extras/githubwatcher/bin/githubwatcher? y
```

as for stop we allow `--all` and `-y`

## HACKS

### Bundler

Bundler has the bad behavior to load `Gemfile` from your current path, so if your `daemons` (ex: [githubwatcher](https://github.com/daddye/githubwatcher))
is shipped with their own `Gemfile` to prevent errors you must insert that line:

``` ruby
ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__) # edit matching your Gemfile path
```

### Rails/Padrino prevent memory leaks

I highly suggest to use `fork` and `before` filters when you are using `forever` with frameworks, this since running same job on our ruby will eat a lot of
ram, so the better way that I found is that:

```rb
Forever.run :fork => true do
  before :each do
    require '/config/boot' # here the rails/padrino environment
  end

  every 10.seconds, :at => ['12:00', '00:00'] do
    Project.all(&:perform_long_task)
  end

  every 1.minute do
    Account.all.map(&:send_emails)
  end
end
```

This is similar to create a new process i.e.:

```rb
Process.fork do
  require '/config/boot'
  my_long_jobs
  Project.all(&:perform_long_task)
end
Process.waitall
```

## /etc/init.d script sample

Use the following script if you want **foreverb** to fire up all of your daemons at boot time in Linux:

```#!/bin/sh
### BEGIN INIT INFO
# Provides:          foreverb
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      S 0 1 6
# Short-Description: foreverb initscript
# Description:       foreverb
### END INIT INFO

# Do NOT "set -e"

DAEMON="foreverb"
USER="username"
SCRIPT_NAME="/etc/init.d/foreverb-username"

case "$1" in
  start)
  su -l $USER -c "$DAEMON start --all --yes"
  ;;
  stop)
  su -l $USER -c "$DAEMON stop --all --yes"
  ;;
  restart)
  su -l $USER -c "$DAEMON restart --all --yes"
  ;;
  *)
  echo "Usage: $SCRIPT_NAME {start|stop|restart}" >&2
  exit 3
  ;;
esac

:
```

You'll have to create one script per each user foreverb runs on.
After creating the file, make it executable:
```chmod +x /etc/init.d/foreverb-username
```
and add it to the system's boot:

* RedHat:
  ```sudo /sbin/chkconfig --level 345 foreverb-username on
  ```
* Debian/Ubuntu:
  ```sudo /usr/sbin/update-rc.d -f foreverb-username defaults
  ```
* Gentoo:
  ```sudo rc-update add foreverb-username default
  ```

## Extras

To see a most comprensive app running _foreverb_ + _growl_ see [githubwatcher gem](https://github.com/daddye/githubwatcher)

## Author

DAddYE, you can follow me on twitter [@daddye](http://twitter.com/daddye) or take a look at my site [daddye.it](http://www.daddye.it)

## Copyright

Copyright (C) 2011 Davide D'Agostino - [@daddye](http://twitter.com/daddye)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the “Software”), to deal in the Software without restriction, including without
limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
