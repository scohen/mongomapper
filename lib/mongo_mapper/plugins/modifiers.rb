# encoding: UTF-8
module MongoMapper
  module Plugins
    module Modifiers
      extend ActiveSupport::Concern

      class DSL
        include MongoMapper::Plugins::Querying

        attr_reader :operations
        attr_reader :criteria
        attr_reader :owner_class

        def initialize(clazz)
          @owner_class, @operations = clazz, { }
        end

        def where(criteria,&block)
          self.tap do
            @criteria = clean_criteria(criteria)

            if block_given?
              instance_eval(&block)
              execute
            end
          end
        end

        def increment(keys={ })
          add_increment(keys)
        end

        def decrement(keys={ })
          add_increment(keys.inject({ }) { |memo, (k, v)| memo[k] = -v.abs; memo })
        end

        def unset(*keys)
          add_operation(:$unset, keys)
        end

        def push(values={ })
          add_operation(:$push, values)
        end

        def push_all(values = { })
          add_operation(:$pushAll, values)
        end

        def pull(values={ })
          add_operation(:$pull, values)
        end

        def pull_all(values = { })
          add_operation(:$pullAll, values)
        end

        def add_to_set(values = { })
          add_operation(:$addToSet, values)
        end

        alias push_uniq add_to_set

        def pop(values={ })
          add_operation(:$pop, values)
        end

        def set(updates = { })
          updates.each_pair do |k, v|
            updates[k] = owner_class.keys[k.to_s].set(v) if owner_class.key?(k)
          end

          add_operation(:$set, updates)
        end

        def execute
          owner_class.collection.update(criteria.to_hash, operations.stringify_keys, :multi => true)
        end

        private

        def add_increment(fixed_keys)

          if incs = operations[:$inc]
            fixed_keys.each_pair do |field, value|
              if old_val = incs[field]
                incs[field] = old_val + value
              else
                incs[field] = value
              end
            end

            add_operation(:$inc, incs)
          else
            add_operation(:$inc, fixed_keys)
          end
        end

        def clean_criteria(criteria)
          case criteria
            when String
              fixed = { :_id => criteria }
            when BSON::ObjectId
              fixed = { :_id => criteria }
            when Hash
              fixed = criteria

            when Array
              ids   = criteria.collect do |id|
                case id
                  when String
                    BSON::ObjectId.legal?(id) ? BSON::ObjectId.from_string(id) : nil
                  when BSON::ObjectId
                    id
                  else
                    nil
                end
              end
              fixed = { :_id => ids.compact }

            else
              fixed = { }
          end
          owner_class.criteria_hash(fixed)
        end

        def add_operation(operation, value)
          self.tap do |dsl|
            dsl.operations[operation] = value
          end
        end
      end

      module ClassMethods

        def atomic()
          MongoMapper::Plugins::Modifiers::DSL.new(self)
        end

        def increment(*args)
          modifier_update('$inc', args)
        end

        def decrement(*args)
          criteria, keys       = criteria_and_keys_from_args(args)
          values, to_decrement = keys.values, { }
          keys.keys.each_with_index { |k, i| to_decrement[k] = -values[i].abs }
          collection.update(criteria, { '$inc' => to_decrement }, :multi => true)
        end

        def set(*args)
          criteria, updates = criteria_and_keys_from_args(args)
          updates.each do |key, value|
            updates[key] = keys[key.to_s].set(value) if key?(key)
          end
          collection.update(criteria, { '$set' => updates }, :multi => true)
        end

        def unset(*args)
          if args[0].is_a?(Hash)
            criteria, keys = args.shift, args
          else
            keys, ids = args.partition { |arg| arg.is_a?(Symbol) }
            criteria  = { :id => ids }
          end

          criteria  = criteria_hash(criteria).to_hash
          modifiers = keys.inject({ }) { |hash, key| hash[key] = 1; hash }
          collection.update(criteria, { '$unset' => modifiers }, :multi => true)
        end

        def push(*args)
          modifier_update('$push', args)
        end

        def push_all(*args)
          modifier_update('$pushAll', args)
        end

        def add_to_set(*args)
          modifier_update('$addToSet', args)
        end

        alias push_uniq add_to_set

        def pull(*args)
          modifier_update('$pull', args)
        end

        def pull_all(*args)
          modifier_update('$pullAll', args)
        end

        def pop(*args)
          modifier_update('$pop', args)
        end

        private
        def modifier_update(modifier, args)
          criteria, updates = criteria_and_keys_from_args(args)
          collection.update(criteria, { modifier => updates }, :multi => true)
        end

        def criteria_and_keys_from_args(args)
          keys     = args.pop
          criteria = args[0].is_a?(Hash) ? args[0] : { :id => args }
          [criteria_hash(criteria).to_hash, keys]
        end
      end

      module InstanceMethods
        def unset(*keys)
          self.class.unset(id, *keys)
        end

        def increment(hash)
          self.class.increment(id, hash)
        end

        def decrement(hash)
          self.class.decrement(id, hash)
        end

        def set(hash)
          self.class.set(id, hash)
        end

        def push(hash)
          self.class.push(id, hash)
        end

        def push_all(hash)
          self.class.push_all(id, hash)
        end

        def pull(hash)
          self.class.pull(id, hash)
        end

        def pull_all(hash)
          self.class.pull_all(id, hash)
        end

        def add_to_set(hash)
          self.class.push_uniq(id, hash)
        end

        alias push_uniq add_to_set

        def pop(hash)
          self.class.pop(id, hash)
        end
      end
    end
  end
end