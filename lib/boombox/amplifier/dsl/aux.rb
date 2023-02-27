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

require 'boombox/amplifier/version'

require_relative 'aux/decl'
require_relative 'aux/error'
require_relative 'aux/inst'
require_relative 'aux/proxy'

module Boombox
  module DSL
    ##
    # Class methods for Engine. They are in a separate module for readability.
    module EngineClassMethods
      def [](property)
        case property
        when Symbol then params[property]
        else
          raise TypeError, "invalid property type: #{property.class}"
        end
      end

      def each_decl(&block) = params.values.each(&block)

      ##
      # Define a group of child engines.
      def engine_group(name, **opts, &block)
        group = EngineGroupDecl.new(name, **opts)
        group.proxy.instance_exec(&block) if block

        declare_param(group)
      end

      def illegal_varnames = %i[@engine_dirty]

      ##
      # Enable calling instance methods on the class by instantiating first.
      def method_missing(name, *args, **opts)
        return super unless respond_to_missing?(name)

        new.send(name, *args, **opts)
      end

      def params(recurse_super: true)
        @params ||= {}
        return @params if !recurse_super || self == Engine

        superclass.params.merge(@params)
      end

      ##
      # Define a parameter.
      #
      # :call-seq: param(name, **{default:, is:, is_not:, to:}) -> name
      def param(name, **opts, &block)
        param = ParameterDecl.new(name, **opts)
        param.proxy.instance_exec(&block) if block

        declare_param(param)
      end

      def respond_to_missing?(name) = public_instance_methods.include?(name)
      def varname_illegal?(varname) = illegal_varnames.include?(varname)

      private

      def declare_param(param)
        params(recurse_super: false)[param.name] = param
        param.declared(self)
        param.name
      end
    end
  end
end
