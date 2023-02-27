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
  module DSL
    ##
    # Proxy class to redirect DSL calls.
    class Proxy
      ##
      # Internal helper class used to define methods on Proxy.
      class Helper < BasicObject
        attr_accessor :proxy

        def initialize(proxy)
          self.proxy = proxy
        end

        def call(&block)
          block.call(self)
          proxy
        end

        def define(method, prc)
          proxy.define_singleton_method(method) do |*args, **opts, &block|
            prc.call(*args, **opts, &block)
          end
        end
      end

      def initialize(&block)
        strip_methods
        Helper.new(self).call(&block)
      end

      private

      ##
      # Returns an Array with the names of methods that we don't want to remove.
      #
      # These are mostly the methods defined for BasicObject, as well as
      # methods like #define_singleton_method that we need to define new stuff.
      def retain_methods
        %i[! != == __id__ __send__ define_singleton_method equal? instance_eval
           instance_exec method_missing singleton_method_added
           singleton_method_removed singleton_method_undefined]
      end

      ##
      # Removes all methods from the current instance, except
      # for those returned by #retain_methods.
      def strip_methods
        methods.difference(retain_methods)
               .each(&singleton_class.method(:undef_method))
      end
    end
  end
end
