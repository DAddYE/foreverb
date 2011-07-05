# Forever

Small daemon framework for ruby, with logging, error handler

## Example usage

```rb
#!/usr/bin/ruby
require 'rubygems' unless defined?(Gem)
require 'forever'

Forever.on_error do |e|
  Mail.deliver do
    delivery_method :sendmail, :location => `which sendmail`.chomp
    to      "d.dagostino@lipsiasoft.com"
    from    "exceptions@lipsiasoft.com"
    subject "[GitHub Watcher] #{e.message}"
    body    "%s\n  %s" % [e.message, e.backtrace.join("\n  ")]
  end
end

Forever.run do
  require 'bundler/setup'
  require 'githubwatcher'
  Githubwatcher.start!
end
```