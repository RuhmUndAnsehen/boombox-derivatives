# frozen_string_literal: true

#    This file is part of Boombox Derivatives.
#
#    Boombox Derivatives is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by the
#    Free Software Foundation, either version 3 of the License, or (at your
#    option) any later version.
#
#    Boombox Derivatives is distributed in the hope that it will be useful, but
#    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
#    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
#    more details.
#
#    You should have received a copy of the GNU General Public License along
#    with Boombox Derivatives. If not, see <https://www.gnu.org/licenses/>.

require 'observer'

require 'boombox/derivatives/version'
require_relative 'proxy'

module Boombox
  module DSL
    ##
    # Raised if a parameter was referenced but not declared.
    class UndeclaredParameterError < ArgumentError
      def initialize(name)
        super("undeclared parameter: #{name.inspect}")
      end
    end
  end
end
