require 'sequencescape-api/finder_methods'
require 'sequencescape-api/associations/base'
require 'sequencescape-api/actions'

module Sequencescape::Api::Associations::HasMany
  module JsonBehaviour
    def self.included(base)
      base.write_inheritable_attribute(:default_attributes_if_missing, [])
    end

    def as_json(options = nil)
      options = { :root => false, :uuid => true }.reverse_merge(options || {})
      all.map { |o| o.as_json(options) }.compact
    end

    def run_validations!
      all.all?(&:run_validations!)
    end

    class CompositeErrors
      def initialize(association)
        @association = association
      end

      def full_messages
        map_errors(&:full_messages).flatten
      end

      def empty?
        map_errors(&:empty?).all?
      end

      def clear
        map_errors(&:clear)
      end

      def [](field)
        map_errors { |errors| errors[field] }.flatten
      end

      def map_errors(&block)
        @association.map(&:errors).map(&block)
      end
    end

    def errors
      CompositeErrors.new(self)
    end
  end

  class AssociationProxy < ::Sequencescape::Api::Associations::Base
    include ::Sequencescape::Api::FinderMethods
    extend  ::Sequencescape::Api::Actions
    include ::Sequencescape::Api::Associations::HasMany::JsonBehaviour
  end

  class InlineAssociationProxy 
    include Enumerable
    include ::Sequencescape::Api::FinderMethods::Delegation
    include ::Sequencescape::Api::Associations::Base::InstanceMethods
    include ::Sequencescape::Api::Associations::HasMany::JsonBehaviour

    def initialize(owner, json = nil)
      super
      @objects = @attributes.map(&method(:new))
    end

    def find(uuid)
      @objects.detect { |o| o.uuid == uuid }
    end

    def all
      @objects
    end

    def new(json, &block)
      super(json, false, &block)
    end
    private :new

    # We are changed if any of our objects have been changed.
    def changed?
      @objects.any?(&:changed?)
    end
  end

  def has_many(association, options = {}, &block)
    association = association.to_sym

    proxy = Class.new(
      case options[:disposition].try(:to_sym)
      when :inline then InlineAssociationProxy
      else AssociationProxy
      end
    )
    proxy.association = association
    proxy.options     = options
    proxy.instance_eval(&block) if block_given?

    association_methods(association, :has_many, proxy)
  end
end
