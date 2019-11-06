# frozen_string_literal: true

require 'flex_hash/version'
require 'awesome_print'
require_relative 'seen_mixin'

# FlexHash is a subclass of a Hash, with the added features of:
# - automatically initializing nested hashes
# - array indexing for stores and fetches
#
# The first level is always an `FlexHash`, and multiple levels will be
# `FlexHash`es by default, unless overridden with the `keymap` on the
# initializer.
#
# An example will help with understanding the new features:
#
#     fh = FlexHash.new(versions: [], path: '')
#     fh['some_file.xml', :versions] << '~/src/repo/templates/some_file.xml,v1'
#     fh['some_file.xml', :versions] << '~/src/repo/templates/some_file.xml,v2'
#     fh['some_file.xml', :versions] << '~/src/repo/templates/some_file.xml,v3'
#     fh['some_file.xml', :tags, :locked] = 'true'
#     fh['some_file.xml', :tags, :migrated] = 'false'
#     fh['some_file.xml', :path] = '~/src/repo/templates/some_file.xml'
#
#     ofv = ['some_other_file.xml', :versions]
#     oft = ['some_other_file.xml', :tags]
#     ofp = ['some_other_file.xml', :path]
#     fh[ofv] << '~/src/repo/templates/some_other_file.xml,v1'
#     fh[ofv] << '~/src/repo/templates/some_other_file.xml,v2'
#     fh[oft, :locked] = 'true'
#     fh[oft, :migrated] = 'false'
#     fh[ofp] = '~/src/repo/templates/some_other_file.xml'
#
#     newfh = FlexHash.new
#     newfh.default = nil
#     newfh[:key1] == nil
#     newfh[:key1, :key2] == nil
#     newfh[:key1] == { :key1 => {} }
#
# Notes on the examples:
#
# 1. The `FlexHash` object is created with a _mapping_ of `:versions` to an array, and of `:path`
#    to a string.
#
# 2. The value associated with the first index is auto-initialized by default to a sub-FlexHash;
#    in other words, `ah[key]` is a nested FlexHash object.
#
# 3. The values associated with the second index varies by key:
#    - an array for the `:versions` key
#    - a string for the `:path` key
#    - a nested FlexHash for the `:tags` key.
#
# 4. The `FlexHash` class used the _mapping_ provided on the `.new` method to decide how to
#    initialize all new (unknown) key values.
#
# 5. The array indexes cause _true_ nesting<sup>[1]</sup>.
#
# 6. Because the _default_ initialization is a nested `FlexHash` instance, this
#    allows for _chained indexing_. For example: `ah[key1][key2][key3] =
#    value`.  This works because the first index expression `ah[key1]` returns
#    a `FlexHash` instance as its value, which is then indexed with `[key2]`,
#    which returns another `FlexHash` instance, which is then indexed with
#    `[key3]`, which returns its automatically-initialized `FlexHash` index.
#
# 7. The "downside" of auto-initializtion is that indexing with unknown keys does
#    not result in a `nil` _(as with regular hashes)_; instead it returns the
#    new `FlexHash` instance that is associated with the new key.
#
# 8. Keys can be tested without causing auto-initializing by using the usual Hash
#    methods: `.key?` or `member?`
#
# 9. Array indexes are flattened before iterating over them, so they can be
#    provided either as a single argument, or as combinations of arrays and/or
#    scalars.
#
# 10. The `ah[array]` syntax above would fail if `ah` were a normal Hash.
#
# 11. The default behavior of initializing final values with FlexHash instances
#     can be changed by explicitly setting `.default`; e.g.: `fh.default = nil`.
#
# 12. Intermediate new index keys are always initialized to FlexHash instances,
#     unless mapped.
#
# ### Array Indexing and Nested Hashes
#
# FlexHash objects support true, nested array indexes, with each element
# of the array being indexed with auto-initialization separately.
#
# Normal hashes _can_ use array keys, but the array elements are treated as a
# whole, and indexed at the top-level.  In other words, arrays on normal hashes
# do not cause _nested_ indexes.  Nested hashes must be managed manually on
# normal hashes.  A `FlexHash` object manages it automatically.
#
#     Compare Hash:                   Versus FlexHash:
#
#     ah = {}                         ah = FlexHash.new
#     ah[['a', 'b']] = 'a b'          ah['a', 'b'] = 'a b'
#     ah[['a', 'c']] = 'a c'          ah['a', 'c'] = 'a c'
#     ah[['a', 'd', 'e']] = 'a d e'   ah['a', 'd', 'e'] = 'a d e'
#
#     results in:                     results in:
#
#     { ["a", "b"] => "a b",          { "a" => {
#       ["a", "c"] => "a c",              "b" => "a b",
#       ["a", "d", "e"] => "a d e"        "c" => "a c",
#     }                                   "d" => {
#                                           "e" => "a d e"
#                                         }
#                                       }
#                                     }
#
#     No nesting:                     Nested hashes:
#
#     ah['a'] yields nil              ah['a'] => { "b" => ...,
#                                                  "c" => ...,
#                                                  "d" => ... }
#
# [1]: In regard to nested array indexing, the value of `ah['some_file.xml']`
#      is a `FlexHash`, which looks like this:
#
# ```ruby
#   ah['some_file.xml'] => {
#     :versions => [
#        '~/src/repo/.../some_file.xml,v1',
#        '~/src/repo/.../some_file.xml,v2',
#        '~/src/repo/.../some_file.xml,v3'
#     ],
#     :tags => {
#        :locked   => 'true',
#        :migrated => 'false'
#     },
#     :path => '~/src/repo/.../some_file.xml'
#   }
# ```
#
# ## Mappings:
#
# `keymap` is an optional hash mapping specific strings, symbols, or regexps to
# a corresponding data type to be used with their index.  By default, all keys
# not specifically mapped will have their associated values initialized to a
# new `FlexHash` instance.
#
# The keymap can map symbols, strings, or regexps to collection classes or
# literals.  Example:
#
#     ah = FlexHash.new( :versions => Array, :path => String )
#
# or
#
#     ah = FlexHash.new( :versions => [], /path/ => '')
#
# In the above example, keys of `:versions` will be initialized with an array,
# and any key matching the regexp `/path/` will have their associated value
# initialized to the empty string.
#
# Intermediate keys not explicitly mapped will have an associated
# `FlexHash.new` value.
#
# ### Auto-Initialization and Array Indexing
#
# The default initializtion is to use a new `FlexHash` value; this enables the
# _chained indexing_, and the _auto-initialization_ of new indexes.
#
# With normal hashes, it is typical to simply reference a hash value by
# `ah[key]` and have it either return the assigned value, or `nil`, when there
# is no such key.  On normal hashes, in the case where the key did not exist,
# the key will *not* added to the hash by just referencing it.
#
# With `FlexHash` objects, because of the auto-initialization, simply
# referencing a new key will cause it to be added to the underlying hash data
# associated with a new `FlexHash` instance.
#
# In other words, this auto-initialization is what makes the code below possible:
#
#     ah = FlexHash.new
#     aj = FlexHash.new
#     ah[:k1][:k2][:k3] = aj[:k1, :k2, :k3] = 'foo'
#     ah[:k1]           == aj[:k1]
#     ah[:k1][:k2]      == aj[:k1, :k2]
#     ah[:k1][:k2][:k3] == aj[:k1, :k2, :k3]
#
# The index chain `ah[:k1][:k2][:k3]` works _only_ because of the
# auto-initialization with FlexHash instances.
#
# With normal hashes, the above code would not work.  To make it work would
# require something like this:
#
#     ah ||= {}
#     ah[:k1] ||= {}
#     ah[:k1][:k2] ||= {}
#     ah[:k1][:k2][:k3] = 'foo'
#
# The array syntax of `:k1, :k2, :k3` is not even possible.
#
# The syntax of `ah[[:k1, :k2, :k3]] = 'foo'` _is_ possible, but it only adds
# an array index to the top-level hash, and does *no* nested indexing at all.
#
# ### Overriding the Default Initialization
#
# If it is undesireable to have new indexes auto-initialize to an `FlexHash`
# value, then explicitly setting the `default` attribute to `nil` will prevent
# this.
#
# The default of a `FlexHash` node can be overridden with:
#
#     (ah = FlexHash.new).default = nil
#
# The only limitation with setting the default initializtion to `nil` is that
# _chained indexes_ will not work.  Array indexes will still work fine.  In
# other words, given the above definition of `ah`, the following will cause an
# error:
#
#     ah[:k1][:k2] = 'oops'
#
# However, even with a mapping of `default = nil`, array index assignments work
# fine:
#
#     ah[:k1, :k2] = 'yay'
#
# or:
#
#     ah.store(:k1, :k2, 'yay')
#
# Array index references also works fine, and still correctly auto-initializes
# the first key, even if the 2nd key is unknown:
#
#     > ah[:k1, :k2]
#     nil
#     > ah
#     { :k1 => {} }
#
#
# `FlexHash`:
#
# a hash which maps _keys_ _(as strings, symbols, or regexps)_ to literals or
# classes.  The mapping keys are matched against new `FlexHash` index keys and
# the associated value is used to automatically initialize the value.  When no
# mapping exists, the default initialization value is a new instance of
# `FlexHash`.
#
# Mappings are only needed when the default initialization of `FlexHash` is
# incorrect.  For example, if a particular index key were to be used to collect
# information in an _array_, then a mapping for that key name or a regexp
# matching its string name would be needed.
#
# For example, if it were desired to have any keys with the string `list` in
# the name be automatically mapped to an array, then the mapping would be:
#
#     /list/ => []
#
# @return [Hash, nil] hash of mappings, possibly empty or nil.
class FlexHash < Hash
  include SeenMixin

  attr_accessor :mapping

  # set the instance name (for reporting)
  attr_writer :name

  class << self
    def [](*values)
      new.replace(Hash[*values])
    end
  end

  def initialize(mapping = nil)
    @mapping = mapping || {}
    @default_set = false
  end

  # @overload default
  #   the default value for final indexes, which is usually `FlexHash.new(mapping)`.
  # @overload default=(new_default)
  #   explicitly sets the default value for new keys on final index associations.
  #   This does not affect intermediate indexes, which are always initialized to
  #   an indexable collection (or as mapped).
  def default
    if @default_set
      @default.class == Class ? @default.new : @default
    else
      FlexHash.new(mapping)
    end
  end

  def default=(new_default)
    @default = new_default
    @default_set = true
  end

  # aliases to the original Hash methods (before we override them)
  alias __key__?         key?
  alias __include__?     include?
  alias __store__        store
  alias __fetch__        fetch
  alias __fetch_values__ fetch_values
  alias __delete__       delete
  alias __replace__      replace
  alias __merge__        merge
  alias __update__       update
  alias __values_at__    values_at

  # given a key, which can be scalar or an array, return true if the keys exist in the index
  def key?(*key_list)
    first_keys, last_key = split_keys(key_list.flatten)
    data = self
    while (key = first_keys.shift)
      return false unless data.__key__?(key)

      data = data.__fetch__(key)
    end
    data.__key__?(last_key)
  end

  alias member? key?
  alias include? key?

  # given one or more keys, each of which can be a scalar or array index,
  # return the corresponding key, value pairs.
  def slice(*keys)
    FlexHash[keys.map { |key| [key, fetch(key)] }]
  end

  # index the FlexHash object by `key_list`, a scalar key, or an array of keys.
  # New indexes are automatically associated with new FlexHash instances,
  # unless the FlexHash instance was created with the `default` attribute
  # assigned to nil, or something else.
  #
  # @param [String, Integer, Array] key_list one or more keys used as an index on the FlexHash instance.
  # @return [value, FlexHash] the value associated with the given index(es), or a newly initialized FlexHash instance.
  def [](*key_list)
    fetch_or_init_keys(Array(key_list).flatten) { |key| new_collection(key) }
  end

  # The original `Hash.fetch` call signature includes an optional "default"
  # value, which, if provided overrides the `Hash.default` value.  If the
  # `default` parameter is not provided, but the `fetch` call has an associated
  # block, it is used instead.
  #
  # However, because of the optional trailing "default" value, it's not
  # possible to use a variable sized leading argument because invocations with
  # multiple elements will apply the last element to the "default" argument.
  #
  # So, the call signature with array indexes must be a _single_ argument which
  # can be either a scalar value, or an array value.  Some examples:
  #
  #     ah = FlexHash.new
  #     ah.fetch(:key1)          # => { :key1 => {} }
  #     ah.fetch([:key1, :key2]) # => { :key1 => { :key2 => {} } }
  #     keys = ['a', 'b']
  #     ah.fetch(keys, '')       # => { 'a' => { 'b' => '' } }
  #
  # This is managed by the code below.
  def fetch(key_list, given_default = omitted = true)
    fetch_or_init_keys(Array(key_list).flatten) do |key|
      if omitted
        block_given? ? yield(key) : new_collection(key)
      else
        given_default
      end
    end
  end

  # fetch the values at the given keys, where each key can be a scalar (as with
  # normal hash), or an array of keys.
  def fetch_values(*key_list, &block)
    if array_index?(key_list)
      key_list.map { |key| fetch(key, &block) }
    elsif block_given?
      __fetch_values__(*key_list) { |key| yield(key) }
    else
      __fetch_values__(*key_list)
    end
  end

  def array_index?(key_list)
    key_list.any? { |key| key.class == Array }
  end

  # assign `value` to the resulting object indexed by the keys of `key_list`,
  # one or more hash keys.  New intermediate keys automatically are associated
  # with new FlexHash instances.
  # @param [String, Integer, Array] key_list one or more keys used to index the FlexHash object.
  # @return [value] the `value` stored is also returned.
  def []=(*key_list, value)
    store_with_init(Array(key_list).flatten, value)
  end

  # @param [Array, scalar] key_list one or more keys to be indexed on the FlexHash instance
  # @param [value] value an arbitrary value to be assigned
  # Indexes into the `FlexHash` instance with succeeding elements of `key_list`, storing the
  # `value` into the last index.
  def store(*key_list, value)
    store_with_init(Array(key_list).flatten, value)
  end

  # deletes the item indexed by the one or more keys in `key_list`.
  def delete(*key_list)
    first_keys, last_key = split_keys(key_list)
    data = fetch_data(first_keys)
    data.__delete__(last_key) if data.__key__?(last_key)
  end

  # replace the current contents with the `hash`, converting all "normal"
  # hash values into `FlexHash` equivalents.  Multiple keys to the same
  # hash object are handled correctly _(the transform is performed only
  # once per unique hash object)_.
  def replace(hash)
    __replace__(deep_transform_hashes_of(hash))
  end

  def merge(hash)
    __merge__(deep_transform_hashes_of(hash))
  end

  # updates the content by successively merging the given hashes, and then converting
  # any nested Hash objects to FlexHash objects.
  def update(*hashes, &block)
    hashes.each { |hash| __update__(hash, &block) }
    deep_transform_hashes! if hashes.any? { |hash| hash.class == Hash }
    self
  end

  # applies `transform_values` across all values, recursing on Hash and Array values.
  # Correctly detects loops when values have already been visited in the recursion by
  # tracking visited objects in a temporary @seen instance hash

  def deep_transform_values(depth = 0, &block)
    transform_values do |value|
      recursive_deep_transform_value(value, :deep_transform_values, depth + 1, &block)
    end.tap { reset_seen(depth) }
  end

  def deep_transform_values!(depth = 0, &block)
    transform_values! do |value|
      recursive_deep_transform_value(value, :deep_transform_values!, depth + 1, &block)
    end.tap { reset_seen(depth) }
  end

  def deep_transform_keys
    recursive_deep_transform_keys(FlexHash.new)
  end

  def deep_transform_keys!
    recursive_deep_transform_keys(self)
  end

  private

  def recursive_deep_transform_value(value, func, depth, &block)
    case value
    when Hash, Array
      value.seen? ? value : value.seen!.send(func, depth, &block)
    else
      yield(value)
    end
  end

  def recursive_deep_transform_keys(hash, depth = 0)
    deep_transform(hash, depth) do |key, value|
      [yield(key), value]
    end
  end

  public

  # transform each key and/or value.
  #
  # hash.deep_transform { |key, value| ... [new_key, new_value] }
  #
  # returns a new FlexHash with key, value pair resulting from each iteration of the block.
  #
  # hash.deep_transform(result_hash) { |key, value| ... [new_key, new_value] }
  #
  # returns the `result_hash` updated by the key,value pairs from the block iterations.

  def deep_transform(result_hash = {}, &block)
    deep_transform_depth(result_hash, 0, &block)
  end

  private

  def deep_transform_depth(result_hash, depth, &block)
    each_with_object(result_hash) do |(key, value), hash|
      new_key, new_value = recursive_deep_transform(hash, key, value, depth, &block)
      hash.store(new_key, new_value)
      hash.delete(key) if key != new_key && hash.key?(key)
    end.tap { reset_seen(depth) }
  end

  def recursive_deep_transform(hash, key, value, depth, &block)
    case value
    when Hash, Array
      if value.seen?
        [key, value]
      else
        value.seen!.deep_transform_depth(hash, key, value, depth + 1, &block)
      end
    else
      yield(key, value)
    end
  end

  public

  # returns the array of values corresponding to the array of keys, each of which may
  # be a scalar or array index, the latter of which performs nested indexing _(via `[]`)_.
  def values_at(*key_list)
    key_list.map { |key| self[key] }
  end

  private

  def deep_transform_hashes!
    replace(self)
  end

  # `transform_hashes` does a deep_transform_values converting corresponding
  # Hash values to FlexHash values
  def deep_transform_hashes_of(hash, hash_cache = {})
    new_hash = FlexHash.new(mapping)
    hash.each_pair do |key, val|
      if val.class == Hash
        # only transform a given instance once
        hash_cache[val.object_id] ||= deep_transform_hashes_of(val, hash_cache)
        val = hash_cache[val.object_id]
      end
      new_hash[key] = val
    end
    new_hash
  end

  public

  # the name of this instance.  By default it is the object_id
  def name
    @name || object_id.to_s
  end

  # return a string representation of the FlexHash object, complete with the mappings
  def inspect
    out = []
    out << string_name
    out << string_mappings
    out << string_data
    out.compact.join(' ') + '>'
  end

  # return a string representation of the FlexHash object data using `awesome_print`
  def to_s
    "#<FlexHash #{name} " + ai(sort_keys: true) + '>'
  end

  private

  def fetch_or_init_keys(key_list)
    first_keys, last_key = split_keys(key_list)
    data = fetch_data(first_keys)
    fetch_or_init_key(last_key, data) do |key|
      block_given? ? yield(key) : default
    end
  end

  def fetch_key_with_initialization(key, data)
    fetch_or_init_key(key, data) do |new_key|
      new_collection(new_key, no_nil: true)
    end
  end

  def fetch_or_init_key(key, data)
    data ||= self
    return data.__fetch__(key) if data.__include__?(key)

    default_value = yield(key)
    data.__store__(key, default_value) unless default_value.nil? # avoid initializations with nil
  end

  # returns the data collection indexed by `key_list`.  If `key_list` is empty,
  # returns `self`.
  def fetch_data(key_list)
    data = self
    key_list.each { |key| data = fetch_key_with_initialization(key, data) }
    data
  end

  def store_with_init(key_list, value)
    first_keys, last_key = split_keys(key_list)
    fetch_data(first_keys).__store__(last_key, value)
  end

  def split_keys(key_list)
    key_list = Array(key_list).dup
    [key_list, key_list.pop]
  end

  # return an new collection based on key mappings, in this order:
  #    exact match of the key
  #    regexp matches on the key
  #    .default => value
  #    node ? FlexHash.new : default
  def new_collection(key, no_nil: false)
    initialize_value(
      mapping[key] || matching_mapping(key) || default_without_mapping(no_nil: no_nil)
    )
  end

  def initialize_value(value)
    case value
    when Array, []  then [] # TODO: should be FlexArray.new
    when Hash, {}   then FlexHash.new(mapping)
    when Class      then value.new
    else
      value
    end
  end

  # mapping is a hash of `mapkey => init` pairs, where some `mapkey` values can
  # be regexps.  Returns the `init` value corresponding to the first `mapkey`
  # that matches the `key` argument.
  def matching_mapping(key)
    regexp_mappings = (mapping || {}).select { |k, _v| k.class == Regexp }
    (regexp_mappings.detect { |rex, _init| rex.match?(key.to_s) } || []).last
  end

  def default_without_mapping(no_nil: false)
    # .default can be set explicitly to 'nil', so requires careful handling
    no_nil ? FlexHash.new(mapping) : default
  end

  def string_name
    "#<FlexHash #{name}"
  end

  def string_mappings
    '(' + mapping.ai(multiline: false)[1..-2].strip + ')' unless mapping.nil? || mapping.size.zero?
  end

  def string_data
    ai(sort_keys: true, raw: true)
  end
end
