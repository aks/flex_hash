# FlexHash

The `FlexHash` class provides a `hash`-like object which self-initializes
sub-keys on new indexes.  It also allows for array indexes, doing the Right
Thing, with successive indexing.

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'flex_hash'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install flex_hash

## Usage

Let's create a `FlexHash` on which indexes of `:versions` keys will be arrays, indexes
matching `/path/` will be String values, and all other indexes self-initializing as `FlexHash`es.

    fh = FlexHash.new(:versions => [], /path/ => String)
    fh['dev', :versions] << 'new_path_1'
    fh['dev', :versions] << 'new_path_2'
    fh['dev', :path] = '/path/to/a/folder'

Array indexing works on both assignments and fetches:

    fh['dev', :tags, :tag1] = 'val1'
    puts fh['dev', :tags, :tag1]
    ax1 = ['dev', :tags, :tag1]
    ax2 = ['dev', :tags, :tag2]
    fh[ax2] = 'val2'
    fh[ax1] != fh[ax2]

Indexes chains are automatically handled _(unless `:DEFAULT => nil`)_:

    fh['dev'][:tags][:tag1] = 'val1'
    fh['dev'][:tags][:tag2] = 'val2'

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/aks/flex_hash.

## Author

Alan K. Stebbens <alan.stebbens@procore.com> || <aks@stebbens.org>

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
