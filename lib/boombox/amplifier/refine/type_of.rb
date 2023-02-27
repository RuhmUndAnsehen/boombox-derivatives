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

require 'boombox/amplifier/version'

module Boombox
  module Refine
    ##
    # Using this module will define a #type_of? method in Module.
    module TypeOf
      refine ::Module do
        ##
        # Returns +true+ if and only if +object.is_a?(self)+ returns +true+.
        def type_of?(object) = object.is_a?(self)
      end
    end
  end
end
