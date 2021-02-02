# Escalate

A simple and lightweight gem to help with escalating errors

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

1. Log an error containing the exception and any additional information about the current environment that is specified
2. Trigger any `escalation_callbacks` configured on the `Escalate` gem
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/invoca/escalate.
