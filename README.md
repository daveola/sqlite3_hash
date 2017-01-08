# Sqlite3Hash

A persistent simple Hash backed by sqlite3

Contains (almost) the same features/API as the Ruby 2.0.0 Hash object

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sqlite3_hash'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sqlite3_hash

## Usage

SQLite3Hash is a persistent simple Hash backed by sqlite3.

You can use it like a Hash object, but all data is stored in SQLite3,
which can be re-used over multiple instantiations of ruby.

Example case:

    require 'sqlite3_hash'
    
    shash = SQLite3Hash.new('tmpfile.db')
    shash['int'] = 42
    shash[:sym] = { a: 12, b: 32 }
    shash[99.1] = [1,[10,20],3]  
    shash = nil

    # Some point later..  or even in another ruby instance:
    shash = SQLite3Hash.new('tmpfile.db')
    shash['int']   # => 42
    shash.to_s     # => {"int"=>42, :sym=>{:a=>12, :b=>32}, 99.1=>[1, [10, 20], 3]}

Handles values of String, Fixnum, Float, and anything that can be Marshalled

Keys are anything that can be Marshalled.

This means, for example, that you *cannot* store Procs in an SQLite3Hash

Contains all the Hash class methods from 2.0.0 except:

1. No deprecated methods
2. Methods not implemented:  rehash, compare_by_identity, SQLite3Hash[]

3. Methods that are supposed to return a hash do so (instead of returning an SQLite3Hash), for example 'to_h'

4. try_convert also requires db and other parameters as per SQLite3Hash.new

5. Uses the value of an object instead of the object as a key, i.e.:

    a = [ "a", "b" ]
    h = { a => 100 }
    sh = SQLite3Hash('tmp.db')
    a[0] = 'z'
    h	 # => {["z", "b"]=>100}
    sh  # => {["a", "b"]=>100}


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/daveola/sqlite3_hash.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

