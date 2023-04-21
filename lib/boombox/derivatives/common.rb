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

require 'bigdecimal'
require 'bigdecimal/util'
require 'date'
require 'time'

require 'boombox/derivatives/version'
require_relative 'dsl'
require_relative 'refine/to_time'

module Boombox
  Underlying = Struct.new(:price, :time)
  SECONDS_PA = 365 * 24 * 3600

  ##
  # Common superclass for different kinds of derivatives.
  class ForwardInstrumentsEngine < DSL::Engine
    using ::Boombox::Refine::ToTime

    param :expiry, to: :to_time
    param :rate, default: 0, to: :to_d
    param :spot, to: :to_d
    param :time, to: :to_time
    param :yield, default: 0, to: :to_d

    def _maturity = _expiry

    def _tte(time = nil)
      return ((_expiry - time).to_d / SECONDS_PA) if time

      @_tte ||= _tte(_time)
    end
    alias _ttm _tte
  end
end
