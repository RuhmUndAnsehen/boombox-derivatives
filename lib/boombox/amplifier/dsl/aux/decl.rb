# frozen_string_literal: true

#    This file is part of Boombox Amplifier.
#
#    Boombox Amplifier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by the
#    Free Software Foundation, either version 3 of the License, or (at your
#    option) any later version.
#
#    Boombox Amplifier is distributed in the hope that it will be useful, but
#    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
#    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
#    more details.
#
#    You should have received a copy of the GNU General Public License along
#    with Boombox Amplifier. If not, see <https://www.gnu.org/licenses/>.

require 'observer'
require 'set'

require_relative 'inst'
require_relative 'proxy'

module Boombox
  module DSL
    ##
    # Base class for initializers.
    class BaseDecl
      class << self
        def attributes(recurse_super: true)
          @attributes ||= Set.new
          return @attributes if !recurse_super || self == BaseDecl

          superclass.attributes.union(@attributes)
        end

        def attribute(name, optional: false, **opts, &block)
          attributes(recurse_super: false) << name

          define_attr_default_method(name, opts, &block)
          define_attr_assert_validity_method(name, optional:)
          attr_accessor(name)
        end

        def assert_validity_method_name(attr) = :"assert_validity_of_#{attr}"
        def default_method_name(attr)         = :"init_default_#{attr}"

        private

        def define_attr_assert_validity_method(name, optional:)
          define_method(assert_validity_method_name(name)) do
            return if instance_variable_defined?(:"@#{name}") || optional

            raise ArgumentError, "#{whatami}: `#{name}' is required"
          end
        end

        def define_attr_default_method(name, opts, &block)
          setter = :"#{name}="

          define_method(default_method_name(name)) do
            return send(setter, instance_exec(&block)) if block
            return send(setter, opts[:default].dup)    if opts.key?(:default)
          end
        end
      end

      attribute :varname

      def initialize(**opts, &block)
        initialize_defaults
        initialize_opts(**opts)
        call_block(&block)
        finalize_init
      end

      def assert_validity(engine_class)
        assert_attributes_validity
        return unless engine_class.varname_illegal?(varname)

        msg = <<~MSG
          Use of instance variable name `#{varname}' is prohibited, please specify
          explicitly (`varname: @another_name')
        MSG
        raise NameError, msg, varname
      end

      def declared(engine_class)
        assert_validity(engine_class)
        freeze
      end

      def instantiate(engine, *args, **opts)
        instance = new(*args, **opts)
        engine.instance_variable_set(varname, instance)
      end

      def new(*args, **opts, &block)
        self.class.instance_class.new(self, *args, **opts, &block)
      end

      ##
      # Returns an instance of Proxy that provides an interface to modify
      # parameters of this instance via DSL.
      def proxy
        Proxy.new do |proxy|
          self.class.attributes
              .each { |attr| proxy.define attr, method(:"#{attr}=") }
        end
      end

      ##
      # Returns this object's type as a human-readable String.
      def whatami = self.class.to_s

      private

      def amend_proxy(proxy, &block) = Proxy::Helper.new(proxy).call(&block)

      def assert_attributes_validity
        self.class.attributes
            .map(&self.class.method(:assert_validity_method_name))
            .each(&method(:send))
      end

      def call_block(&block)
        proxy.call(&block) if block
      end

      def finalize_init; end

      def initialize_defaults
        self.class.attributes
            .map(&self.class.method(:default_method_name))
            .each(&method(:send))
      end

      def initialize_opts(**opts)
        opts.slice(*self.class.attributes)
            .each { |key, value| send(:"#{key}=", value) }
      end
    end

    ##
    # Base class for parameter initializers.
    class BaseParameterDecl < BaseDecl
      attribute :name
      attribute(:reader)  { :"_#{name}" }
      attribute(:varname) { :"@#{name}" }

      def initialize(name, **opts, &block)
        self.name = name

        super(**opts, &block)
      end

      def instantiate(engine, *_args, **_opts)
        ivar = varname # necessary because of block scoping
        engine.define_singleton_method(reader) do
          instance_variable_get(ivar).value
        end
        super
      end
    end

    ##
    # Initializer class for Parameter.
    class ParameterDecl < BaseParameterDecl
      class << self
        def instance_class = Parameter
      end

      attribute :default, optional: true
      attribute :is,      default: ->(_) { true }
      attribute :is_not,  default: ->(_) { false }
      attribute :to,      default: :itself
    end

    ##
    # Initializer class for EngineGroup.
    class EngineGroupDecl < BaseParameterDecl
      class << self
        def delegate_decl_class = DelegateDecl
        def instance_class = EngineGroup
      end

      attribute :exposes, default: []
      attribute :template

      def assert_validity(_)
        super
        nil # TODO
      end

      def declared(engine_class)
        exposes.map  { |(args, opts)| delegation(*args, **(opts || {})) }
               .each { |decl| engine_class.send(:declare_param, decl) }

        super
      end

      def instantiate(engine, *args, **opts)
        super(engine, template, *args, **opts)
      end

      def proxy
        amend_proxy(super) do |proxy|
          proxy.define :exposes, ->(*params) { exposes.concat(params) }
        end
      end

      private

      def delegation(*args, **opts)
        self.class.delegate_decl_class.new(*args, **opts.merge!(to: name))
      end
    end

    ##
    # Initializer class for Delegate.
    class DelegateDecl < BaseParameterDecl
      ##
      # Data class holding parameter delegation data.
      class Delegation
        attr_accessor :param, :to, :prefix

        def initialize(*args, param: nil, to: nil, prefix: nil)
          self.param  = init_arg(args, param)
          self.to     = init_arg(args, to)
          self.prefix = init_arg(args, prefix)
          freeze
        end

        def assert_validity
          msg = 'expected %<param>s:%<wrong>s to be %<correct>s'
          { param: Symbol, to: Symbol }
            .each do |param, correct|
              unless param.is_a?(correct)
                wrong = send(param).class
                raise TypeError, msg.format(param:, correct:, wrong:)
              end
            end
        end

        def prefixed_param = prefix ? :"#{prefix}_#{param}" : param
        def to_h           = { param:, to:, prefix: }
        def with(**opts)   = self.class.new(**to_h.merge!(opts))

        private

        def init_arg(args, arg) = arg || args.shift
      end

      class << self
        def delegation(*args, **opts) = Delegation.new(*args, **opts)
        def instance_class = Delegate
      end

      attr_accessor :delegation

      attribute :initializable, default: true

      def initialize(*args, **opts, &block)
        self.delegation = self.class.delegation(*args, **opts)

        super(delegation.prefixed_param, &block)
      end

      def assert_validity(_)
        delegation.assert_validity
        super
      end

      def group          = delegation.to
      def initializable? = initializable
      def param          = delegation.param
      def prefixed_param = delegation.prefixed_param
    end
  end
end
