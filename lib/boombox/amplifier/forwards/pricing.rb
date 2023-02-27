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

require_relative '../common'
require_relative '../dsl'

module Boombox
  ##
  # Engine for the pricing of forwards (and futures).
  class ForwardsEngine < ForwardInstrumentsEngine
    param :carry, default: 0, to: :to_d
    param :dividends, default: {}
    param :value, to: :to_d

    def solve_for_value
      _dividends.reduce(_fwd_price(spot)) do |fwd, (date, dvdnd)|
        fwd - _fwd_price(dvdnd, _ttm(date))
      end
    end
    alias solve_for_forward_price solve_for_value

    def solve_for_carry
      raise ArgumentError, 'dividend not supported' unless _dividends.empty?

      -Math.log(_value / _spot) / _tte - _rate - _yield
    end

    def solve_for_rate
      raise ArgumentError, 'dividend not supported' unless _dividends.empty?

      -Math.log(_value / _spot) / _tte - _carry - _yield
    end

    def solve_for_yield
      raise ArgumentError, 'dividend not supported' unless _dividends.empty?

      -Math.log(_value / _spot) / _tte - _carry - _rate
    end

    def solve_for_tte
      raise ArgumentError, 'dividend not supported' unless _dividends.empty?

      -Math.log(_value / _spot) / (_rate + _carry + _yield)
    end

    def solve_for_expiry
      _time + solve_for_tte * SECONDS_PA
    end
    alias solve_for_maturity solve_for_expiry

    def solve_for_time
      _expiry - solve_for_tte * SECONDS_PA
    end

    def solve_for_spot
      raise ArgumentError, 'dividend not supported' unless _dividends.empty?

      _value / Math.exp((_rate + _carry + _yield) * _tte)
    end

    protected

    def _fwd_price(spot, ttm = _ttm)
      spot * Math.exp((_rate + _carry - _yield) * ttm)
    end
  end
end
