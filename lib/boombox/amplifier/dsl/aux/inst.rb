# frozen_string_literal: true

#    Financial instrument library for Boombox
#    Copyright (C) 2022-2023 RuhmUndAnsehen
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

require_relative 'error'

module Boombox
  module DSL
    ##
    # Base class for Engine internals.
    class BaseInst
      attr_reader :decl

      def initialize(decl)
        @decl = decl
      end

      ##
      # Raises an Error if #valid? returns +false+.
      def assert_validity
        return if valid?

        raise validity_error_type, validity_error_msg
      end

      ##
      # Returns +true+ if this object has been fully initialized (i.e. by
      # assigning a value to a Parameter object).
      #
      # Called by Engine#to_h to determine if this object should be included or
      # skipped.
      def initialized? = false

      ##
      # Callback when an Engine object is done invoking BaseDecl#instanciate on
      # all registered objects.
      #
      # This ensures that BaseInst objects with dependencies that optimize
      # their interactions can initialize those with all relevant objects
      # instantiated.
      def instantiated(engine); end

      ##
      # Returns the name of #decl.
      def name = decl.name

      ##
      # Returns +true+ if this object is in a valid state.
      #
      # Called by #assert_validity.
      def valid? = true

      ##
      # Returns this object's type as a human-readable String.
      def whatami = self.class.to_s

      private

      ##
      # Returns an error message indicating why this object's state is invalid.
      def validity_error_msg = "#{whatami} `#{decl.name} is invalid"

      ##
      # Returns an error Class indicating why this object's state is invalid.
      def validity_error_type = ArgumentError
    end

    ##
    # Base class for Engine parameters.
    class BaseParameter < BaseInst
      def initialized? = @initialized

      private

      def validity_error_msg = super + ": #{value.inspect}"
    end

    ##
    # Engine parameters. Provides checks, and support for the observer pattern.
    class Parameter < BaseParameter
      include Observable

      def <<(observer)
        add_observer(observer)
        self
      end

      def initialize(decl, *values)
        super(decl)

        return if values.empty?

        self.value = transform(values[0])
      end

      def changed
        # `initialized' and `changed' are different states for different
        # purposes. While `changed' is reset after each call to
        # #notify_observers, `initialized' is supposed to be persistent.
        @initialized = true
        super
      end

      def is?(it_is = decl.is)
        it_is == value ||
          (it_is.is_a?(Module) && value.is_a?(it_is)) ||
          it_is.to_proc[value]
      end

      def not?(is_not = decl.is_not) = !is?(is_not)
      def raw_value = @value
      def transform(val) = decl.to.to_proc[val]

      def value
        return @value if initialized?

        transform(decl.default)
      end
      alias call value

      def value=(newval)
        changed
        notify_observers(name, newval)
        @value = transform(newval)
      end

      def valid?
        super && not? && is?
      rescue StandardError
        false
      end
    end

    ##
    # Subgroup of Engines.
    class EngineGroup < BaseParameter
      def initialized? = @value.any?(&:initialized?)

      def param(name)
        Proxy.new do |prxy|
          prxy.define :value, -> { @value.map { |e| e.param(name).value } }
          prxy.define :value=,
                      ->(nval) { @value.map { |e| e.param(name).value = nval } }
        end
      end

      def replace(array)
        @value = array.map { |params| decl.template.with(**params) }
      end

      def value=(newval)
        case newval
        when Array then replace(newval)
        else
          raise TypeError, "unsupported value type: #{newval.class}"
        end
      end

      def value = super.map(&:to_h)
    end

    ##
    # Delegates Engine parameters to another parameter (typically EngineGroup).
    #
    # This enables the parameters of EngineGroup constituents to be addressed
    # as parameters through Engine.
    class Delegate < BaseParameter
      attr_reader :group

      def delegation   = decl.delegation
      def initialized? = false

      def instantiated(engine)
        @group = engine[delegation.to]
        self
      end

      def param          = decl.param
      def prefixed_param = decl.prefixed_param
      def value          = group.param(param).value

      def value=(newval)
        group.param(param).value = newval
      end
    end
  end
end
