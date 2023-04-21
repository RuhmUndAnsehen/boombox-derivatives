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

require 'boombox/derivatives/version'

module Boombox
  module Refine
    ##
    # Using this module will define a #to_time method in Numeric, Time.
    module ToTime
      refine ::Numeric do
        def to_time = ::Time.at(self)
      end

      refine ::Time do
        def to_time = self
      end
    end
  end
end
