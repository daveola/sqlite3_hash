require "sqlite3_hash/version"

# Filename:	sqlite3hash.rb
# Author:	David Ljung Madison <DaveSource.com>
# See License:	http://MarginalHacks.com/License/
# Description:	An sqlite3 backed simple hash in ruby
#
# Handles values of String, Fixnum, Float, and anything that can be Marshalled
# Keys are anything that can be Marshalled
# This means, for example, that you cannot store Procs in an SQLite3Hash
#
# Contains all the Hash class methods from 2.0.0 except:
# 1) No deprecated methods
# 2) Methods not implemented:  rehash, compare_by_identity, SQLite3Hash[]
# 3) Methods that are supposed to return a hash do so (instead of
#    returning an SQLite3Hash), for example 'to_h'
# 4) try_convert also requires db and other parameters as per SQLite3Hash.new
# 5) Uses the value of an object instead of the object as a key, i.e.:
#    a = [ "a", "b" ]
#    h = { a => 100 }
#    sh = SQLite3Hash('tmp.db', h)
#    a[0] = 'z'   # This only effects 'h' not 'sh'
#    h	 # => {["z", "b"]=>100}
#    sh  # => {["a", "b"]=>100}

require 'sqlite3'

class SQLite3Hash
	class MissingDBPath < StandardError
		def initialize(msg="Need to specify DB path for SQLite3Hash") super; end
	end

	# new(db)
	# new(db, default_obj)
	# new(db, hash)
	# new(db, default_obj, table_name)
	# new(db, hash, table_name)
	#   All of the above with block specified (default_proc)
	def initialize(db=nil, init=nil, table='sqlite3hash', &default_proc)
		raise SQLite3Hash::MissingDBPath unless db
		@db = db

		@sqldb = SQLite3::Database.open(@db)

		# Handle args
		@default = (init.class==Hash) ? nil : init
		@default_proc = block_given? ? default_proc : nil

		# Safely quote table
		@table = table
		@table = table.gsub( /'/, "''" )

		createTable

		# Init from hash
		init.each { |k,v| set(k,v) } if init.class==Hash
	end

	# Like 'new' but we call try_convert
	def SQLite3Hash.try_convert(incoming, *args)
		shash = SQLite3Hash.new(*args)
		return shash unless incoming
		h = Hash.try_convert(incoming)
		return shash unless h
		h.each { |k,v| shash[k]=v }
		shash
	end

	def [](key)
		return nil unless @sqldb
		row = @sqldb.get_first_row( "select * from '#{@table}' where key = ?", Marshal.dump(key))
		row ? (row2value(row)) : default(key)
	end
	alias :get :[]
	alias :read :[]
	def default(key=nil)
		(key && @default_proc) ? @default_proc.call(self,key) : @default
	end
	def default=(v)
		@default = v
	end
	def default_proc
		@default_proc
	end
	def assoc(key)
		has_key?(key) ? [key,get(key)] : nil
	end
	def rassoc(value)
		key = key(value)
		key ? [key,value] : nil
	end

	def []=(key,value)
		return unless @sqldb
		# Unlike a Hash, can't store with key nil, we could use quoting to change this if needed
		return unless key

		rows = {
			'valueString' => nil,
			'valueSymbol' => nil,
			'valueFixnum' => nil,
			'valueFloat' => nil,
			'valueMarshal' => nil,
		}
		rowname,value = rowValue(value)
		rows[rowname] = value
		keys = ['key']
		# Key is always marshalled - it can be many types and needs to be a unique index
		values = [Marshal.dump(key)]
		rows.each { |k,v|
			keys.push(k)
			values.push(v)
		}
		@sqldb.execute("insert or replace into '#{@table}'(#{keys.join(',')}) VALUES(#{(['?']*values.size).join(',')})",*values)
	end
	alias :set :[]=
	alias :write :[]=
	alias :hsh :[]=
	alias :store :[]=

	def fetch(key,default = nil)
		v = get(key)
		return v if v
		return default if default
		return yield(key) if block_given?
		return raise KeyError
	end

	def each
		return Enumerator.new { |y| rows { |row| y.yield(Marshal.load(row[0]),row2value(row)) } } unless block_given?
		rows { |row| yield(Marshal.load(row[0]),row2value(row)) }
	end
	alias :each_pair :each

	def each_key
		return Enumerator.new { |y| rows { |row| y.yield(Marshal.load(row[0])) } } unless block_given?
		rows { |row| yield(Marshal.load(row[0])) }
	end
	def each_value
		return Enumerator.new { |y| rows { |row| y.yield(row2value(row)) } } unless block_given?
		rows { |row| yield(row2value(row)) }
	end
	def keys
		rows.map { |row| Marshal.load(row[0]) }
	end
	def values
		rows.map { |row| row2value(row) }
	end
	# Values for a given set of keys
	def values_at(*keys)
		keys.map { |key| get(key) }
	end

	def flatten(level=1)
		arr = []
		each { |k,v| arr.push([k,v]) }
		arr.flatten(level)
	end

	def size
		got = @sqldb.get_first_row("select count(*) from '#{@table}'")
		return got && got.class==Array ? got[0] : nil
	end
	alias :length :size
	def empty?
		size==0 ? true : false
	end

	def del(key)
#puts "delete key #{key}"
		return unless @sqldb
		@sqldb.execute("delete from '#{@table}' where key = ?",Marshal.dump(key))
	end
	alias :delete :del
	def keep_if
		return Enumerator.new { |y|
			each { |k,v| delete(k) unless y.yield(k,v) }
			self
		} unless block_given?
		each { |k,v| delete(k) unless yield(k,v) }
		return self
	end
	def delete_if
		return Enumerator.new { |y|
			each { |k,v| delete(k) if y.yield(k,v) }
			self
		} unless block_given?
		each { |k,v| delete(k) if yield(k,v) }
		return self
	end
	def reject
		hash = Hash.new
		each { |k,v| hash[k] = v unless yield(k,v) }
		return hash
	end
	def reject!
		changes = 0
		en = Enumerator.new { |y|
			each { |k,v|
				next unless y.yield(k,v)
				delete(k)
				changes += 1
			}
			changes==0 ? nil : self
		}
		return en unless block_given?
		en.each { |k,v| yield(k,v) }
	end
	def select
		hash = Hash.new
		each { |k,v| hash[k] = v if yield(k,v) }
		return hash
	end
	def select!
		changes = 0
		en = Enumerator.new { |y|
			each { |k,v|
				next if y.yield(k,v)
				delete(k)
				changes += 1
			}
			changes==0 ? nil : self
		}
		return en unless block_given?
		en.each { |k,v| yield(k,v) }
	end

	def clear(replaceHash = nil)
		@sqldb.execute("drop table '#{@table}'")
		createTable(replaceHash)
	end
	alias :replace :clear

	def has_key?(k)
		@sqldb.get_first_row( "select * from '#{@table}' where key = ?", Marshal.dump(k)) ? true : false
	end
	alias :include? :has_key?
	alias :key? :has_key?
	alias :member? :has_key?

	def index(value)
		rowname,value = rowValue(value)
		row = @sqldb.get_first_row( "select * from '#{@table}' where #{rowname} = ?", value)
		row ? Marshal.load(row[0]) : nil
	end
	alias :key :index
	def has_value?(v)
		index(v) ? true : false
	end
	alias :value? :has_value?

	def shift
		row = @sqldb.get_first_row("select * from '#{@table}'")
# TODO - what if we have a default_proc and we shift out?
		return default(nil) unless row
		key = Marshal.load(row[0])
		value = row2value(row)
		delete(key)
		[key,value]
	end

	def to_h
		h = Hash.new
		return h unless @sqldb
		each { |k,v| h[k] = v }
		h
	end
	alias :to_hash :to_h
	def ==(otherHash)
		to_hash.==(otherHash)
	end
	alias :eql? :==
	def hash
		to_hash.hash
	end
	def invert
		to_hash.invert
	end
	def merge(otherHash,&block)
		to_hash.merge(otherHash,&block)
	end
	def merge!(otherHash)
		if block_given?
			otherHash.each { |key,newval|
				oldval = get(key)
				set(key,oldval ? yield(key,oldval,newval) : newval)
			}
		else
			otherHash.each { |k,v| set(k,v) }
		end
	end
	alias :update :merge!
	def replace(otherHash)
		clear
		merge!(otherHash)
	end

	def to_a
		a = Array.new
		return a unless @sqldb
		each { |k,v| a.push([k,v]) }
		a
	end
	def sort
		to_a.sort
	end

	def inspect
		inspect = "SQLite3Hash[#{@db}:#{@table}]"
		return "#<#{inspect} - no database connection>" unless @sqldb
		return "#<#{inspect} #{to_hash.inspect}>"
	end
	def to_s
		to_hash.to_s
	end

	# For debug
	def dumpTable
		h = Hash.new
		return puts "NO CONNECTION" unless @sqldb
		@sqldb.execute("select * from '#{@table}'") { |row|
			row[0] = Marshal.load(row[0])
			p row
		}
		h
	end

	# Not implemented
	def rehash
		raise NotImplementedError
	end
	def compare_by_identity
		raise NotImplementedError
	end
	def compare_by_identity?
		false
	end
	def self.[](*a)
		raise NotImplementedError
	end


	private
		def rows
			return @sqldb.execute("select * from '#{@table}'") unless block_given?
			@sqldb.execute("select * from '#{@table}'") { |row|
				yield row
			}
		end
		def rowValue(value)
			c = value.class
			return ["value#{c.to_s}",value] if c==Fixnum || c==String || c==Float
			return ["value#{c.to_s}",value.to_s] if c==Symbol
			return ["valueMarshal",Marshal.dump(value)]
		end
		def row2value(row)
			row[1] || row[2] || row[3] || (row[4] ? row[4].to_sym : Marshal.load(row[5]))
		end

		def createTable(h=Hash.new)
			# Check if table exists
			return if @sqldb.get_first_value( %{select name from sqlite_master where name = :name}, {:name => @table} )
			@sqldb.execute("create table '#{@table}' (key TEXT not null unique, valueString TEXTS, valueFixnum INTEGER, valueFloat REAL, valueSymbol TEXTS, valueMarshal TEXTS)")
			h.each { |k,v| set(k,v) } if h
		end
end

