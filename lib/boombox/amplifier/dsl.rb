# frozen_string_literal: true

#    Financial instrument library for Boombox
#    Copyright (C) 2021-2022 RuhmUndAnsehen
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

require 'observer'

require 'boombox/amplifier/version'

module Boombox
  ##
  # Provides a DSL for parameter initialisation
  class EngineDSL
    ILLEGAL_VARNAMES = %i[@engine_dirty].freeze
    class << self
      def params
        @params ||= {}
        return @params unless superclass.respond_to?(:params)

        superclass.params.merge(@params)
      end

      ##
      # Define a parameter.
      #
      # :call-seq: param(name, **{default:, is:, is_not:, to:}) -> name
      def param(name, **opts)
        param = ParameterDecl.new(name, **opts)
        define_method(param.reader) do
          instance_variable_get(param.varname).value
        end
        (@params ||= {})[name] = param
        name
      end
    end

    ##
    # Storage class for parameter declarations.
    ParameterDecl = Struct.new(:name, :default, :is, :is_not, :to,
                               :reader, :varname, :writer) do
      def initialize(name, **args)
        super(name,
              args[:default],
              args[:is] || ->(_) { true },
              args[:is_not] || ->(_) { false },
              args[:to] || :itself,
              args[:reader] || :"_#{name}",
              args[:varname] || :"@#{name}")

        assert_validity
        freeze
      end

      def assert_validity
        return unless ILLEGAL_VARNAMES.include?(varname)

        msg = <<~MSG
          Use of instance variable name `#{varname}' is prohibited, please specify
          explicitly (`varname: @another_name')
        MSG
        raise NameError, msg, varname
      end
    end

    ##
    # Raised if a parameter was referenced but not declared.
    class UndeclaredParameterError < ArgumentError
      def initialize(name)
        super("undeclared parameter: #{name.inspect}")
      end
    end

    ##
    # Engine parameters. Provides checks, and support for the observer pattern.
    class Parameter
      include Observable

      attr_reader :decl, :value
      alias call value

      def <<(observer)
        add_observer(observer)
        self
      end

      def initialize(decl, value = nil, skip_init: false)
        @decl = decl
        @value = decl.to.to_proc[value || decl.default] unless skip_init
      end

      def assert_validity
        return if valid?

        raise ArgumentError,
              "parameter `#{decl.name} is invalid: #{value.inspect}"
      end

      def is?(it_is = decl.is)
        it_is == value ||
          (it_is.is_a?(Module) && value.is_a?(it_is)) ||
          it_is.to_proc[value]
      end

      def not?(is_not = decl.is_not) = !is?(is_not)

      def name = decl.name

      def value=(newval)
        changed
        notify_observers(name, value)
        @value = decl.to.to_proc[newval]
      end

      def valid?
        not? && is?
      rescue StandardError
        false
      end
    end

    def [](name) = instance_variable_get(self.class.params[name])&.value

    def []=(name, value)
      decl = self.class.params[name]
      raise UndeclaredParameterError, name if decl.nil?

      dirty
      ensure_param(decl, value, skip_init: true).value = value
    end

    def initialize(**args)
      initialize_params(args)
    end

    def dirty?
      @engine_dirty
    end

    def dirty(status: true)
      @engine_dirty = status
    end

    def assert_validity
      self.class.params.values
          .map { |decl| [decl.name, instance_variable_get(decl.varname)] }
          .each do |name, value|
            raise ArgumentError, "uninitialized parameter: #{name}" unless value

            value.assert_validity
          end
    end

    def new(**args)
      self.class.new(**to_h.merge!(args))
    end

    def solve_for(param)
      reset if dirty?
      initialize_defaults
      assert_validity
      send("solve_for_#{param}")
    end

    def to_h
      instance_variables.map(&method(:instance_variable_get))
                        .select { |val| val.is_a?(Parameter) }
                        .to_h { |par| [par.decl.name, par.value] }
    end

    def reset
      resettable_instance_variables.each { |v| remove_instance_variable(v) }
      dirty(status: false)
    end

    def resettable_instance_variables
      instance_variables.select { |v| v[1] == '_' }
    end

    def update(**params)
      params.each { |name, value| self[name] = value }
      self
    end

    alias with new
    alias with! update

    private

    def ensure_param(decl, value = nil, **opt)
      if instance_variable_defined?(decl.varname)
        instance_variable_get(decl.varname)
      else
        instance_variable_set(decl.varname, Parameter.new(decl, value, **opt))
      end
    end

    def initialize_defaults
      self.class.params.each { |_name, param| ensure_param(param) }
    end

    def initialize_params(args)
      params = self.class.params
      args.each do |name, value|
        raise UndeclaredParameterError, name unless params.key?(name)

        decl = params[name]
        ensure_param(decl, value)
      end
    end
  end
end
