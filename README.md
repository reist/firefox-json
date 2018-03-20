# FirefoxJson

`firefox-json` is a library to view and/or manipulate the json files in Firefox profiles.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'firefox-json'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install firefox-json

## Usage

For now, all the library can do is manipulate sessions - the window and tab collections.

### Getting a session

```ruby
FirefoxJson.available_profiles
=> ["default", "some-other-profile"]
session = FirefoxJson.load_profile('default').session
=> #<Firefox::Session# windows=1 closed=1>
```

### Digging in

```ruby
session.closed_windows
=> [#<Firefox::Window closed! tabs=1 selected="Some Title">]
_[0].tabs
=> [#<Firefox::Tab entries=1 selected="Some Title">]
e = _[0].entries[0]
=> #<Firefox::Entry http://www.site.com/a-page>
e.public_methods - Object.methods
=> [:url, :title, :referrer, :domain, :dump, :path, :path=, :save, :required_key, :reload]
e.referrer
=> "https://www.google.com/long-search-string"
e.domain
=> "www.site.com"
```

### Recovering a closed window

```ruby
session.windows << session.closed_windows.shift # you can add `.tap { |w| w.is_closed = false }` to remove the `closed!` part
=> [#<Firefox::Window tabs=15 closed=2 selected="Google">, #<Firefox::Window closed! tabs=3 selected="Ruby Programming Language">]
session
=> #<Firefox::Session# windows=2>
session.save # or session.save('some_other_file.js')
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/reist/firefox-json.

## License

The gem is available as open source under the terms of the [ISC License](https://opensource.org/licenses/ISC).

