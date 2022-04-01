# frozen_string_literal: true

#    Financial instrument library for Boombox
#    Copyright (C) 2022 RuhmUndAnsehen
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
    ##
    # Storage class for parameter declarations.
    ParameterDecl = Struct.new(:engine_class, :name, :default, :is, :is_not,
                               :to, :reader, :varname, :writer) do
      def initialize(engine_class, name, **args)
        super(engine_class, name,
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
        return unless engine_class.varname_illegal?(varname)

        msg = <<~MSG
          Use of instance variable name `#{varname}' is prohibited, please specify
          explicitly (`varname: @another_name')
        MSG
        raise NameError, msg, varname
      end

      def new(*args, **opts, &block) = Parameter.new(*args, **opts, &block)
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
  end
end
