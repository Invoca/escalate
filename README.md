# Escalate

A simple and lightweight gem to escalate rescued exceptions. This implementation
is an abstract interface that can be used on it's own, or attached to more concrete
implementations like Honeybadger, Airbrake, or Sentry in order to not just log
exceptions in an easy to parse way, but also escalate the appropriate information
to third party systems.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'escalate'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install escalate

## Usage

### Adding Escalate to Your Gem

All you need to do is extend `Escalate.mixin` within your gem and you're all set.

```ruby
module SomeGem
  include Escalate.mixin
end
```

This will expose the `Escalate#escalate` method within your gem to be used instead
of using `logger.error`.

```ruby
module SomeGem
  include Escalate.mixin

  class << self
    attr_accessor :logger
  end

  class SomeClass
    def something_dangerous
      # ...
    rescue => ex
      SomeGem.escalate(ex, "I was doing something dangerous and an exception was raised")
    end
  end
end
```

When `SomeGem.escalate` above is triggered, it will use the logger returned by `SomeGem.logger` or
default to a `STDERR` logger and do the following:

1. [optional] Log an error containing the exception, location_message, and context hash
2. Trigger any `on_escalate_callbacks` configured on the `Escalate` gem

Step (1) is optional. It will happen if either of these is true:
 - by default if no `on_escalate_callbacks` have been registered; or
 - if any of the `on_escalate_callbacks` was registered with `on_escalate(log_first: true)`.

### Registering an Escalate Callback

If you are using an error reporting service, you can register an `on_escalate` callback to escalate exceptions.
You have the option to handle logging yourself, or to let `escalate` log first, before calling your callback.

#### Leave the Logging to the Escalate Gem
Here is an example that uses the default `log_first: true` so that logging is handled by the `Escalate` gem first:
```
Escalate.on_escalate do |exception, location_message, **context|
  # send exception, location_message, **context to the error reporting service here
end
```

#### Handle the Logging in the `on_escalate` Callback
Here is an example that handles logging itself with `log_first: false`:
```
Escalate.on_escalate(log_first: false) do |exception, location_message, **context|
  # log here first
  # send exception, location_message, **context to the error reporting service here
end
```
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/invoca/escalate.
