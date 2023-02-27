# frozen_string_literal: true

#    Financial instrument library for Boombox
#    Copyright (C) 2021-2023 RuhmUndAnsehen
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

require 'boombox/amplifier/version'

require_relative 'aux'

module Boombox
  module DSL
    ##
    # Provides a DSL for parameter initialisation
    class Engine
      extend ::Boombox::DSL::EngineClassMethods

      def [](name) = param(name)&.value

      def []=(name, value)
        decl = self.class[name]
        raise UndeclaredParameterError, name unless decl

        dirty
        param(decl).value = value
      end

      def initialize(**opts)
        instantiate_params
        initialize_params(opts)
      end

      def dirty? = @engine_dirty

      def dirty(status: true)
        @engine_dirty = status
      end

      def assert_validity
        self.class.params.values
            .map { |decl| [decl.name, instance_variable_get(decl.varname)] }
            .each do |name, value|
              unless value
                raise ArgumentError,
                      "uninitialized parameter: #{name}"
              end

              value.assert_validity
            end
      end

      def initialized? = params.any?(&:initialized?)
      def new(**args) = self.class.new(**to_h.merge!(args))

      def reset
        resettable_instance_variables.each { |v| remove_instance_variable(v) }
        dirty(status: false)
      end

      def resettable_instance_variables
        param_names = self.class.params.values.map(&:varname)
        instance_variables.difference(param_names, self.class.illegal_varnames)
      end

      def solve_for(param)
        reset if dirty?
        assert_validity
        send("solve_for_#{param}")
      end

      def to_h
        initialized_params.to_h { |par| [par.name, par.value] }
      end

      def update(**params)
        params.each { |name, value| self[name] = value }
        self
      end

      alias with new
      alias with! update

      private

      def engine_groups = params.select { |obj| obj.is_a?(EngineGroup) }

      def instantiate_params
        self.class.each_decl
            .map  { |decl| decl.instantiate(self) }
            .each { |inst| inst.instantiated(self) }
      end

      def initialize_params(args)
        args = args.dup

        params.each do |inst|
          name = inst.name
          inst.value = args.delete(name) if args.key?(name)
        end

        # We deleted the arguments corresponding to parameters, so the hash
        # should be empty. Raise an error if it's not.
        raise UndeclaredParameterError, args.keys.first unless args.empty?
      end

      def initialized_params = params.select(&:initialized?)

      def param(name)
        decl = name.is_a?(BaseDecl) ? name : self.class[name]
        instance_variable_get(decl.varname)
      end

      def params
        instance_variables.map(&method(:instance_variable_get))
                          .select { |obj| obj.is_a?(BaseInst) }
      end

      def uninitialized_params = params.reject(&:initialized?)
    end
  end
end
