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

require_relative 'common'

module Boombox
  Underlying = Struct.new(:price, :time)
  ContractParams = Struct.new(:price, :iv, :delta, :gamma, :rho, :theta, :vega)

  ##
  # Superclass for options pricing engines
  class OptionsEngine < ForwardInstrument
    param :iv, &:to_d
    param :strike, &:to_d
    param :type, default: :call

    alias _carry _rate

    def _type_int
      @_type_int ||= _type == :call ? 1 : -1
    end
  end

  ##
  # Provides methods for Black-Scholes parameter estimation.
  module BlackScholesParams
    ##
    # Class methods
    module ClassMethods
      ##
      # Cumulative distribution function of the Standard Normal Distribution
      def phi(xxx) = (1 + Math.erf(xxx / Math.sqrt(2))) / 2

      ##
      # Density function of the Standard Normal Distribution
      def phi!(xxx) = Math.exp(-xxx**2 / 2) / Math.sqrt(2 * Math::PI)
    end

    def _d1
      @_d1 ||= (Math.log(_underlying_price / _strike) +
                  (_carry - _yield + _iv**2 / 2) * _tte) / _iv_timeadj
    end

    def _d2
      @_d2 ||= _d1 - _iv_timeadj
    end

    private

    def _iv_timeadj = _iv * Math.sqrt(_tte)
  end

  ##
  # Black-Scholes options pricing model.
  class BlackScholesEngine < OptionsEngine
    include BlackScholesParams
    extend BlackScholesParams::ClassMethods

    def _delta
      @_delta ||= _type_int * _divadj * self.class.phi(_type_int * _d1)
    end

    def _gamma
      @_gamma ||= _divadj_phi! / _underlying_price / _iv / _tte
    end

    def _vega
      @_vega ||= _divadj_phi! * _underlying_price * Math.sqrt(_tte)
    end

    def _theta
      @_theta ||= -_spot_helper * self.class.phi!(_d1) * _iv / 2 /
                  Math.sqrt(_tte) - _rate * _target_helper +
                  _yield * _spot_helper
    end

    def _rho
      @_rho ||= _target_helper * _tte
    end

    def solve_for_iv; end

    def solve_for_price
      price = _spot_helper - _target_helper
      ContractParams.new(price, _iv, _delta, _gamma, _rho, _theta, _vega)
    end

    private

    def _divadj = Math.exp(-_yield * _tte)
    def _divadj_phi! = self.class.phi!(_d1) * _divadj
    def _spot_helper = _underlying_price * _delta

    def _target_helper = _type_int * self.class.phi(_type_int * _d2) * _strike *
      Math.exp(-_rate * _tte)
  end

  ##
  # Binomial options pricing model.
  #
  # Currently only provides an interface, but will later feature CRR binomial
  # trees.
  class BinomialOptionsEngine < OptionsEngine
    param :steps, default: 123
    param :style, default: :american

    def solve_for_iv; end

    def solve_for_price
      last1 = last2 = nil
      last0 = _target
      _steps.times.reverse_each do |stepno|
        last2 = last1
        last1 = last0
        last0 =
          last0.each_cons(2).each_with_index.map do |(uptgt, downtgt), ndowns|
            _node_adj(stepno, ndowns,
                      (_p * uptgt + _p_inv * downtgt) *
                        Math.exp(-_rate * _tte / _steps))
          end
      end
      raise 'price Array contains more than one element' if last0.size != 1

      d_s = (_up - _down) * _underlying_price
      d_s_d = d_s * _down
      d_s_u = d_s * _up
      delta_d = (last2[1] - last2[2]) / d_s_d
      delta_u = (last2[0] - last2[1]) / d_s_u

      delta = (last1[0] - last1[1]) / d_s
      gamma = (delta_u - delta_d) / d_s
      # ~ theta = (last2[1] - last0[0]) / 2 / _tte * _steps
      ContractParams.new(last0[0], _iv, delta, gamma)
    end

    def _node_adj(stepno, ndowns, value)
      if _style == :american || stepno == _steps
        [value, _terminal_val(stepno, ndowns)].max
      elsif _style == :european
        value
      else
        _style.call(stepno, ndowns, value)
      end
    end

    def _terminal_val(stepno, ndowns)
      base_val = _underlying_price * _up**(stepno - ndowns) * _down**ndowns
      _type_int * (base_val - _strike)
    end

    def _target
      _steps.succ.times.to_a.map! { |i| _node_adj(_steps, i, 0) }
    end
  end

  ##
  # Leisen-Reimer options pricing engine.
  class LeisenReimerEngine < BinomialOptionsEngine
    include BlackScholesParams

    def _up
      @_up ||= Math.exp(_carry * _tte / _steps) * _h1 / _h2
    end

    def _down
      @_down ||= (Math.exp(_carry * _tte / _steps) - _p * _up) / _p_inv
    end

    def _p = _h2
    def _p_inv = 1 - _p

    def _h1
      @_h1 ||= _hn(_d1)
    end

    def _h2
      @_h2 ||= _hn(_d2)
    end

    private

    def _hn(d_n)
      0.5 + (d_n <=> 0) * (0.25 - 0.25.to_d * Math.exp(_hnhelper(d_n)))**0.5
    end

    def _hnhelper(d_n)
      -(d_n / (_steps + 1.to_d / 3.0 + 0.1.to_d / (_steps + 1)))**2 *
        (_steps + 1.to_d / 6.0)
    end
  end
end
