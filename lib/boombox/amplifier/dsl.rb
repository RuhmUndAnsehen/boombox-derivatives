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

require 'boombox/amplifier/version'

module Boombox
  ##
  # Provides a DSL for parameter initialisation
  class EngineDSL
    class << self
      def params
        @params ||= {}
        return @params unless superclass.respond_to?(:params)

        superclass.params.merge(@params)
      end

      def param(param, default: nil, &cast)
        cast ||= proc(&:itself)
        define_method(param) { |newval| new("#{param}": cast.call(newval)) }
        define_method("#{param}!") do |newval|
          instance_variable_set("@#{param}", cast.call(newval))
          self
        end
        define_method("_#{param}") { instance_variable_get("@#{param}") }
        (@params ||= {})[param] = default
      end
    end

    def initialize(**args)
      initialize_params(args)
    end

    def new(**args)
      self.class.new(**to_h.merge!(args))
    end

    def solve
      solve_for(self.class.params.each_key.find do |k|
                  !instance_variable_defined?("@#{k}")
                end || :price)
    end

    def solve_for(param)
      reset
      send("solve_for_#{param}")
    end

    def to_h
      self.class.params
          .each_key.to_h { |k| [k, instance_variable_get("@#{k}")] }
    end

    def reset
      resettable_instance_variables.each { |v| remove_instance_variable(v) }
    end

    def resettable_instance_variables
      instance_variables.select { |v| v[1] == '_' }
    end

    private

    def initialize_params(args)
      self.class.params.merge(args)
          .each { |k, v| instance_variable_set("@#{k}", v) unless v.nil? }
    end
  end
end
