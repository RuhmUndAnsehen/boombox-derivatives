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

require 'bigdecimal'
require 'bigdecimal/util'

require 'boombox/amplifier/version'
require_relative 'dsl'

module Boombox
  Underlying = Struct.new(:price, :time)
  SECONDS_PA = 365 * 24 * 3600

  class ForwardInstrument < EngineDSL
    param :expiry
    param :price, &:to_d
    param :rate, default: 0, &:to_d
    param :underlying
    param :yield, default: 0, &:to_d

    alias maturity expiry
    alias _maturity _expiry

    def _underlying_price = _underlying.price.to_d

    def _tte
      @_tte ||= ((_expiry - _underlying.time).to_d / SECONDS_PA)
    end
    alias _ttm _tte
  end
end
