# frozen_string_literal: true

require 'rspec'
require 'spec_helper'

RSpec.describe FlexHash do
  it "has a version number" do
    expect(FlexHash::VERSION).not_to be nil
  end

  def self.for_many_keys(num = 4)
    keys = []
    1.upto(num) { |n| keys << "key#{n}".to_sym }
    1.upto(num) do |len|
      key_list = keys[0, len]
      yield(key_list, len)
    end
  end

  shared_examples_for 'flex_hash' do |mappings, key, sub_key, expected_class, nil_default = false|
    let(:flexh) { FlexHash.new(mappings).tap { |fh| fh.default = nil if nil_default } }

    context "non-nil default mapping" do
      let(:flexh) { FlexHash.new(mappings) }

      it "initializes new, unmapped keys with a FlexHash" do
        expect(flexh['some_other_key'].class).to eq FlexHash
      end

      it "does initialize intermediate unmapped keys" do
        flexh[key, 'new_key'] = 'nested'
        expect(flexh[key].class).to eq FlexHash
      end

      context "indexing" do
        for_many_keys do |key_list, len|
          it "indexes with a single array at #{len} levels of unmapped keys" do
            expect(flexh[key_list].class).to eq FlexHash
          end

          it "indexes with splatted array at #{len} levels of unmapped keys" do
            expect(flexh[*key_list].class).to eq FlexHash
          end
        end

        it "initializes the mapped keys as specified in the mapping" do
          expect(flexh[key][sub_key].class).to eq expected_class
        end
      end

      context "indexing with fetch at multiple levels" do
        for_many_keys do |key_list, len|
          it "indexes at #{len} levels of unmapped keys" do
            expect(flexh.fetch(key_list).class).to eq FlexHash
          end

          it "correctly manages an explicit default" do
            expect(flexh.fetch(key_list, 'huh')).to eq 'huh'
          end

          it "correctly manages with a nil .default" do
            flexh.default = nil
            expect(flexh.fetch(key_list)).to eq nil
          end

          it "correctly manages with a non-nil explicit default" do
            flexh.default = 'wow'
            expect(flexh.fetch(key_list)).to eq 'wow'
          end
        end
      end

      context "assignments at multiple levels of indexing" do
        for_many_keys do |key_list, len|
          new_value = "works at #{len}"

          it "can assign via []= to #{len} levels of un-mappped keys" do
            flexh[key_list] = new_value
            expect(flexh[key_list]).to eq new_value
          end

          it "can assign via store at multiple levels" do
            expect { flexh.store(key_list, new_value) }.to_not raise_error
            expect(flexh[key_list]).to eq new_value
          end

          it "can assign via splatted indexes at multiple levels" do
            expect { flexh.store(*key_list, new_value) }.to_not raise_error
            expect(flexh[key_list]).to eq new_value
          end
        end
      end
    end

    context "regexp mappings" do
      let(:flexh) { FlexHash.new((mappings || {}).merge(/str/ => String, /array/ => Array)) }

      it "recognizes the string regex mapping" do
        expect(flexh[key, 'str1'].class).to eq String
      end

      it "recognizes the array regex mapping" do
        expect(flexh[key, 'array'].class).to eq Array
      end

      it "regexp mapped indexes can retain values" do
        flexh[key, 'str1'] = 'String one'
        flexh[key, 'str2'] = 'String two'
        expect(flexh[key, 'str1']).to eq 'String one'
        expect(flexh[key, 'str2']).to eq 'String two'
      end

      let(:array_init) do
        flexh[key, :array] << 'one'
        flexh[key, :array] << 'two'
        flexh[key, :array]
      end

      it "array-mapped values can use array methods (like append)" do
        expect { array_init }.to_not raise_error
        expect(array_init).to match_array(%w[one two])
      end
    end

    context "hash methods" do
      let(:flexh) { FlexHash.new }

      it "supports the keys and values hash instance methods" do
        flexh[key][:array] = []
        flexh[key][:array] << 'path1'
        flexh[key][:array] << 'path2'
        flexh[key][:string] = 'fun'
        expect(flexh.keys).to include(key)
        expect(flexh[key].keys).to include(:array, :string)
        expect(flexh[key].values).to match_array([%w[path1 path2], 'fun'])
        expect(flexh[key][:array]).to eq %w[path1 path2]
        expect(flexh[key][:string]).to eq 'fun'
      end

      let(:hash_methods) { {}.methods - Object.methods }

      it "supports _all_ the Hash instance methods" do
        expect(FlexHash.new).to respond_to(*hash_methods)
      end
    end

    context 'hash method overrides' do
      context '.key?' do
        let(:flexh) { FlexHash.new }

        for_many_keys(4) do |key_list, len|
          it "can test #{len} element keys" do
            expect { flexh[key_list] = 'good' }.to_not raise_error
            expect(flexh.key?(key_list)).to be true
          end

          it "can test #{len} element keys splatted" do
            expect { flexh[key_list] = 'good' }.to_not raise_error
            expect(flexh.key?(*key_list)).to be true
          end
        end
      end

      context '.fetch_values' do
        let(:flexh) { FlexHash.new }

        context 'indexing by scalar value' do
          it "returns the values defined for a key" do
            flexh[:key1] = 'fun1'
            expect(flexh.fetch_values(:key1)).to eq ['fun1']
          end

          it "returns the values defined for 2 scalar arguments" do
            flexh[:key1] = 'fun1'
            flexh[:key2, :key3] = 'fun2'
            expect(flexh.fetch_values(:key1, :key2)).to eq ['fun1', { key3: 'fun2' }]
          end
        end

        context 'indexing by arrays' do
          it "returns different values for a 2-element argument" do
            flexh[:key1] = 'fun1'
            flexh[:key2, :key3] = 'fun2'
            expect(flexh.fetch_values(:key1, %i[key2 key3])).to eq %w[fun1 fun2]
          end

          it "returns sub-hashes on 1st or 2nd level indexes" do
            flexh[:key1] = 'fun1'
            flexh[:key2, :key3] = 'fun2'
            expect(flexh.fetch_values(:key1, :key2, %i[key2 key3])).to match_array(['fun1', { key3: 'fun2' }, 'fun2'])
          end

          it "manages multiple deep indexes" do
            flexh[:k1, :k2, :k3] = 'fun1'
            flexh[:k2, :k3] = 'fun2'
            flexh[:k1, :k2, :k4] = 'fun3'
            fetch_keys = [%i[k1 k2 k3], %i[k2 k3], %i[k1 k2 k4]]
            fun_values = %w[fun1 fun2 fun3]
            expect(flexh.fetch_values(*fetch_keys)).to match_array(fun_values)
          end
        end

        context 'using default blocks' do
          it "returns the values defined for a key (and ignores the block)" do
            flexh[:key1] = 'fun1'
            expect(flexh.fetch_values(:key1) { 'NO' }).to eq ['fun1']
          end

          it "returns the values defined for 2 scalar arguments (and ignores the block)" do
            flexh[:key1] = 'fun1'
            flexh[:key2, :key3] = 'fun2'
            expect(flexh.fetch_values(:key1, :key2) { 'NO' }).to eq ['fun1', { key3: 'fun2' }]
          end

          it "uses the block when there is no final key" do
            flexh.delete(:key1)
            expect { flexh.fetch_values(:key1) { 'NO' } }.to_not raise_error
            expect(flexh.fetch_values(:key1) { 'NO' }).to eq ['NO']
          end

          it "uses the block only when there is no key" do
            flexh[:key2] = 'fun2'
            expect { flexh.fetch_values(:key2, :key3) { 'NO' } }.to_not raise_error
            expect(flexh.fetch_values(:key2, :key3) { 'NO' }).to match_array(%w[fun2 NO])
          end
        end
      end
    end
  end

  context "with no mappings" do
    let(:flexh) { FlexHash.new }

    it_behaves_like 'flex_hash', nil, 'paths_key', 'key2', FlexHash
  end

  context "with explicit mappings" do
    context "using literal instance mappings" do
      mappings = { versions: [], path: '' }

      it_behaves_like 'flex_hash', mappings, 'paths1', :path,     String
      it_behaves_like 'flex_hash', mappings, 'paths2', :versions, Array
    end

    context "using mappings by class name" do
      mappings = { versions: Array, path: String }

      it_behaves_like 'flex_hash', mappings, 'paths3', :path,     String
      it_behaves_like 'flex_hash', mappings, 'paths4', :versions, Array
    end

    context 'using default = nil' do
      mappings = { versions: Array, /path/ => String }

      it_behaves_like 'flex_hash', mappings, 'dir3',  :path,     String, true
      it_behaves_like 'flex_hash', mappings, 'dir4',  :versions, Array,  true
    end
  end

  context '.default is nil' do
    let(:flexh) { FlexHash.new(/str/ => String, /array/ => Array).tap { |fh| fh.default = nil } }

    it "can use nil as a default mapping" do
      expect(flexh['some_key']).to be_nil
    end

    it "when a non-existant key is used with .default = nil, no initialization takes place" do
      flexh['some_key']
      expect(flexh.keys).to_not include('some_key')
    end

    it 'the default mapping does not override the String mapping' do
      expect(flexh['str1'].class).to eq String
    end

    it 'the default mapping does not override the Array mapping' do
      expect(flexh['array1'].class).to eq Array
    end
  end

  context "array indexes" do
    let(:flexh) { FlexHash.new }

    it "automatically creates nested lists" do
      flexh[:hash2]['a', 'b'] = 'a b'
      flexh[:hash2]['a', 'c'] = 'a c'
      expect(flexh[:hash2]).to eq('a' => { 'b' => 'a b', 'c' => 'a c' })
    end

    it "automatically creates 3-deep lists" do
      flexh[:hash3]['a', 'b', 'c'] = 'a b c'
      flexh[:hash3]['a', 'b', 'd'] = 'a b d'
      expect(flexh[:hash3]).to eq('a' => { 'b' => { 'c' => 'a b c', 'd' => 'a b d' } })
    end

    def init_array_3
      flexh[:k1, :k2, :k3] = 'foo'
      flexh[:k1, :k2, :k4] = 'bar'
    end

    it "allows array-based indexing" do
      init_array_3
      expect(flexh[:k1, :k2, :k3]).to eq 'foo'
      expect(flexh[:k1, :k2, :k4]).to eq 'bar'
    end

    it "has the expected hash shape" do
      init_array_3
      expect(flexh[:k1]).to eq(k2: { k3: 'foo', k4: 'bar' })
      expect(flexh[:k1, :k2]).to eq(k3: 'foo', k4: 'bar')
    end

    it "sequential single-indexing is equivalent (mostly) to array-indexing" do
      init_array_3
      expect(flexh[:k1][:k2][:k3]).to eq flexh[:k1, :k2, :k3]
      expect(flexh[:k1][:k2][:k4]).to eq flexh[:k1, :k2, :k4]
    end

    it "allows multiple array arguments to be used in an index" do
      fx1 = %i[k1 k2]
      fx2 = %i[k1 k2 k3]
      flexh[fx1, :k3] = 'foo'
      expect(flexh[fx2]).to eq flexh[fx1, :k3]
      expect(flexh[:k1, :k2, :k3]).to eq flexh[fx2]
    end

    context 'when .default is nil' do
      let(:flexh) { FlexHash.new.tap { |fh| fh.default = nil } }

      it "sequential multiple indexes cause errors" do
        expect { flexh[:k1][:k2] = 'oops' }.to raise_error(/undefined method/)
      end

      it "array indexes still work fine" do
        expect { flexh[:k1, :k2] = 'oops' }.to_not raise_error
        flexh[:k1, :k2] = 'okay!'
        expect(flexh[:k1, :k2]).to eq 'okay!'
      end
    end

    context 'when using array, non-splatted arguments' do
      let(:ax1) { ['dev', :tags, :tag1] }
      let(:ax2) { ['dev', :tags, :tag2] }

      it "array indexing works fine" do
        expect { flexh[ax1] = 'one' }.to_not raise_error
      end

      it "array argument indexing works just like multiple argument array indexing" do
        flexh[ax1] = 'one'
        ax1_shape1 = flexh.to_s
        flexh.clear
        flexh[*ax1] = 'one'
        ax1_shape2 = flexh.to_s
        expect(ax1_shape1).to eq ax1_shape2
      end

      it "single-argument array indexes create nested hashes just like multiple arguments" do
        flexh[ax1] = 'one'
        flexh[ax2] = 'two'
        expect(flexh['dev', :tags]).to eq(tag1: 'one', tag2: 'two')
      end
    end
  end

  context '.store' do
    let(:flexh) { FlexHash.new(/str/ => '', /path/ => []) }

    it "accepts scalar keys" do
      expect(flexh.store(:key, 'yay')).to eq 'yay'
      expect(flexh[:key]).to eq 'yay'
    end

    it "accepts array keys" do
      expect(flexh.store(:k1, :k2, 'fun')).to eq 'fun'
      expect(flexh[:k1, :k2]).to eq 'fun'
    end

    it "auto-initializes intermediate hashes" do
      expect(flexh.store(:k1, :k2, 'cool')).to eq 'cool'
      expect(flexh[:k1].class).to eq FlexHash
    end
  end

  context ".delete" do
    let(:flexh) { FlexHash.new }

    it "accepts a scalar key to delete" do
      flexh[:k1] = 'scalar'
      expect(flexh[:k1]).to eq 'scalar'
      expect(flexh.delete(:k1)).to eq 'scalar'
      expect(flexh.key?(:k1)).to be false
    end

    it "accepts an array key to delete" do
      flexh[:k2, :k3, :k4] = 'array'
      expect(flexh[:k2, :k3, :k4]).to eq 'array'
      expect(flexh.delete(:k2, :k3, :k4)).to eq 'array'
      expect(flexh.key?(:k2, :k3, :k4)).to be false
    end
  end

  context ".replace" do
    let(:flexh) { FlexHash.new }
    let(:sub_hash) { { one: 1, two: 2 }}
    let(:norm_hash) { { a: sub_hash, b: { c: sub_hash } } }

    it "replaces current hash content with new hash content" do
      flexh[:k1, :k2] = 'fun'
      expect(flexh[:k1]).to eq(k2: 'fun')
      flexh.replace(norm_hash)
      expect(flexh.key?(:k1)).to be false
    end

    it "converts normal hashes to FlexHash" do
      flexh[:k1, :k2] = 'fun'
      expect(flexh[:k1, :k2]).to eq 'fun'
      flexh.replace(norm_hash)
      expect(flexh[:a].class).to eq FlexHash
      expect(flexh[:b].class).to be FlexHash
    end

    it "retains duplicate keys to the same object" do
      flexh.replace(norm_hash)
      expect(flexh[:a].class).to eq FlexHash
      expect(flexh[:b].class).to be FlexHash
      expect(flexh[:b, :c].class).to be FlexHash
      expect(flexh[:a].object_id).to eq flexh[:b, :c].object_id
    end
  end

  context 'FlexHash[]' do
    it "takes flat arrays and creates a FlexHash" do
      fh = FlexHash[:k1, :one, :k2, :two]
      expect(fh[:k1]).to eq :one
      expect(fh[:k2]).to eq :two
    end
  end

  context '.slice' do
    let(:flexh) { FlexHash.new }

    it "accepts one more keys" do
      flexh = FlexHash.new.replace(a: 1, b: { bb: 2, cc: 3}, c: 4)
      expect(flexh.slice(:a)).to eq(:a => 1)
      expect(flexh.slice(:a, :c)).to eq(a: 1, c: 4)
    end

    it "accepts keys which can be arrays" do
      flexh = FlexHash.new.replace(a: 1, b: { bb: 2, cc: 3}, c: 4)
      expect(flexh.slice([:b, :bb])).to eq(b: { bb: 2 })
    end
  end

  context ".name" do
    let(:fh) { FlexHash.new }

    it "responds to :name" do
      expect(fh).to respond_to(:name)
    end

    it "has a default value of the object id" do
      expect(fh.name).to eq fh.object_id.to_s
    end

    it "can be set" do
      expect { fh.name = 'FunStuff' }.to_not raise_error
    end

    it "can be read after having been set" do
      expect { fh.name = 'FunStuff' }
      fh.name = 'FunStuff'
      expect(fh.name).to eq 'FunStuff'
    end
  end

  context ".inspect" do
    let(:fh) { FlexHash.new(/addr/ => [], path: '') }

    subject do
      fh[:k1, :k2, :k3] = 'yay'
      fh.inspect
    end

    it "produces a string with the class name in it" do
      expect(subject).to match(/FlexHash/)
    end

    it "includes the object id in the name too" do
      expect(subject).to match(/#{fh.object_id.to_s}/)
    end

    it "includes the mapping info" do
      expect(subject).to match(%r{\(/addr/.* => .*\[\], :path.* => .*"".*\)})
    end

    it "includes the hash data" do
      expect(subject).to match(/:k1.* =>.*{\s+:k2.* =>.*{\s+:k3.* => /m)
    end
  end

  context ".to_s" do
    let(:fh) { FlexHash.new(/addr/ => [], path: '') }

    subject do
      fh[:k1, :k2, :k3] = 'yay'
      fh.to_s
    end

    it "produces a string with the class name in it" do
      expect(subject).to match(/FlexHash/)
    end

    it "includes the object id in the name too" do
      expect(subject).to match(/#{fh.object_id.to_s}/)
    end

    it "does not include the mapping info" do
      expect(subject).to_not match(%r{\(/addr/.* => .*\[\], :path.* => .*"".*\)})
    end

    it "includes the hash data" do
      expect(subject).to match(/:k1.* =>.*{\s+:k2.* =>.*{\s+:k3.* => /m)
    end
  end
end
