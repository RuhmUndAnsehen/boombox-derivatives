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

require 'bigdecimal'
require 'bigdecimal/util'

require 'boombox/amplifier/version'

module Boombox
  Underlying = Struct.new(:price, :time)
  ContractParams = Struct.new(:price, :iv, :delta, :gamma, :rho, :theta, :vega)

  ##
  # Provides a DSL for parameter initialisation
  class ParamsEngine
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
                  instance_variable_get("@#{k}").nil?
                end)
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
      self.class.params.each_key { |k| instance_variable_set("@#{k}", args[k]) }
    end
  end

  ##
  # Superclass for options pricing engines
  class OptionsEngine < ParamsEngine
    param :expiry
    param :iv, &:to_d
    param :price, &:to_d
    param :type, default: :call
    param :underlying

    def _underlying_price = _underlying.price.to_d

    def _tte
      @_tte ||= ((_expiry - _underlying.time).to_d / 365 / 24 / 3600)
    end
  end

  ##
  # Binomial options pricing model.
  #
  # Currently only provides an interface, but will later feature CRR binomial
  # trees.
  class BinomialOptionsEngine < OptionsEngine
    StepData = Struct.new(:depth, :dividend, :rate, :t_start, :t_end, :t_tm,
                          :exercise)

    param :rate, &:to_d
    param :steps, default: 123
    param :strike, &:to_d
    param :style, default: :american

    alias _carry _rate

    def solve_for_iv; end

    def solve_for_price
      last1 = last2 = nil
      last0 = _target # n + 1
      _steps.times.reverse_each do |stepno| # n - 1
        last2 = last1
        last1 = last0
        last0 =
          last0.each_cons(2).each_with_index.map do |(uptgt, downtgt), ndowns| # 0; n - 1
            _node_adj(stepno, ndowns,
                      (_p * uptgt + _p_inv * downtgt) * Math.exp(-_rate * _tte / _steps))
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
      type = _type == :call ? 1 : -1
      (base_val - _strike) * type
    end

    def _target
      _steps.succ.times.to_a.map! { |i| _node_adj(_steps, i, 0) }
    end
  end

  ##
  # Leisen-Reimer options pricing engine.
  class LeisenReimerEngine < BinomialOptionsEngine
    def _up
      @_up ||= Math.exp(_carry * _tte / _steps) * _h1 / _h2
    end

    def _down
      @_down ||= (Math.exp(_carry * _tte / _steps) - _p * _up) / _p_inv
    end

    def _p = _h2
    def _p_inv = 1 - _p

    def _d1
      @_d1 ||= (Math.log(_underlying_price / _strike) +
                  (_carry + _iv**2 / 2) * _tte) / _iv_timeadj
    end

    def _d2
      @_d2 ||= _d1 - _iv_timeadj
    end

    def _h1
      @_h1 ||= _hn(_d1)
    end

    def _h2
      @_h2 ||= _hn(_d2)
    end

    private

    def _hn(d_n)
      0.5 + (d_n <=> 0) * (0.25 - 0.25 * Math.exp(_hnhelper(d_n)))**0.5
    end

    def _hnhelper(d_n)
      -(d_n / (_steps + 1.to_d / 3.0 + 0.1.to_d / (_steps + 1)))**2 *
        (_steps + 1.to_d / 6.0)
    end

    def _iv_timeadj = _iv * Math.sqrt(_tte)
  end
end
