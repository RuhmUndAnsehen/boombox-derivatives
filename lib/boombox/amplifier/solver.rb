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

require_relative 'dsl'

module Boombox
  ##
  # General purpose solver following the Dekker-Brent method.
  class DekkerBrentSolver < EngineDSL
    ##
    # Thrown when the initial estimates have equal signs.
    class EqualSignsError < ArgumentError; end

    param :a0, &:to_d
    param :b0, &:to_d
    param :function
    param :max_iterations, default: 42
    param :tolerance, default: 1e-6, &:to_d

    def _fn(*args, **opts, &block)
      _function.call(*args, **opts, &block)
    end

    def solve
      reset

      @_ak, @_bk = initial_estimates
      @_fak, @_fbk = assert_unequal_signs(@_ak, @_bk)
      ensure_params_order
      shift_params(2)
      @_bisectflag = true
      recurse_solve(0)
    end

    protected

    def initial_estimates
      [_a0, _b0]
    end

    def recurse_solve(depth)
      return @_bk if @_fbk.abs < _tolerance || depth >= _max_iterations

      s = secant
      if bisect_condition(s)
        s = bisect
        @_bisectflag = true
      else
        @_bisectflag = false
      end

      update_params(s)
      recurse_solve(depth + 1)
    end

    def update_params(val_s)
      shift_params
      fs = _fn(val_s)
      if (@_fak * fs).negative?
        @_bk = val_s
        @_fbk = fs
      else
        @_ak = val_s
        @_fak = fs
      end
      ensure_params_order
    end

    def shift_params(times = 1)
      shift_params(times - 1) if times > 1
      shift_params_once
    end

    private

    def sign(val) = val <=> 0
    def bisect = (@_ak + @_bk) / 2

    def bisect_condition(secant)
      intp = (3 * @_ak + @_bk) / 4
      (intp <=> secant) != (secant <=> @_bk) ||
        (@_bisectflag &&
         ((secant - @_bk).abs >= (@_bk - @_bkm1).abs / 2 ||
          (@_bk - @_bkm1).abs < _tolerance)) ||
        (!@_bisectflag &&
         ((secant - @_bk).abs >= (@_bkm1 - @_bkm2).abs / 2 ||
          (@_bkm1 - @_bkm2).abs < _tolerance))
    end

    def secant
      if @_fak != @_fbk && @_fbk != @_fbkm1
        i1 = interp_term(@_ak, @_fak, @_fbk, @_fbkm1)
        i2 = interp_term(@_bk, @_fbk, @_fak, @_fbkm1)
        i3 = interp_term(@_bkm1, @_fbkm1, @_fak, @_fbk)
        i1 + i2 + i3
      else
        diffquot = (@_bk - @_bkm1) / (@_fbk - @_fbkm1)
        @_fbk - diffquot * @_fbk
      end
    end

    def interp_term(val, fval, foth1, foth2)
      val * foth1 * foth2 / (fval - foth1) / (fval - foth2)
    end

    def ensure_params_order
      return unless @_fbk.abs > @_fak.abs

      @_ak, @_bk = @_bk, @_ak
      @_fak, @_fbk = @_fbk, @_fak
    end

    def shift_params_once
      @_bkm2 = @_bkm1
      @_bkm1 = @_bk
      @_fbkm2 = @_fbkm1
      @_fbkm1 = @_fbk
    end

    def assert_unequal_signs(val_a, val_b)
      fak = _fn(val_a)
      fbk = _fn(val_b)
      raise EqualSignsError if sign(fak) == sign(fbk)

      [fak, fbk]
    end
  end

  ##
  # IV Solver for Black-Scholes option prices. Does not work because Ruby
  # built-in Math is too imprecise and BigMath too slow.
  #
  # See: A Closed-form Model-free Implied Volatility Formula through Delta
  #      Families (https://ssrn.com/abstract=3573239)
  class BSIVSolver < EngineDSL
    PRECISION = 10
    class << self
      def erf_inv(xxx)
        a = 0.147
        t1 = Math.log(1 - xxx**2)
        t2 = 2 / Math::PI / a + t1 / 2
        (xxx <=> 0) * Math.sqrt(Math.sqrt(t2**2 - t1 / a) - t2)
      end

      def phi_inv(xxx) = Math.sqrt(2) * erf_inv(2 * xxx - 1)
    end

    param :delta_fam,
          default: lambda { |x_y, eps|
                     BigMath.exp((-x_y**2 / 4 / eps), PRECISION) / 2 /
                       BigMath.sqrt(BigMath.PI(PRECISION) * eps, PRECISION)
                   }
    param :engine
    param :epsilon, default: 1e-8, &:to_d
    param :precision, default: 30
    param :steps, default: 42

    def solve = solve_for(:iv)

    def solve_for_iv
      iv = (_iv_l.._iv_u)
           .step(_step_width)
           .map { |v| _engine.iv(v).solve_for(:iv) }
           .map { |c| _delta_fam(c.price - _engine._price) * c.iv * c.vega }
           .each_cons(2).map { |a, b| a + b }
           .each_with_object(_step_width / 2).map(&:*)
           .sum
      _engine.iv(iv).solve_for(:price)
    end

    def _c
      @_c ||= _engine._price / Math.exp(-_engine._yield * _engine._tte) /
              _engine._underlying_price
    end

    def _k
      @_k ||= Math.log(_engine._strike /
                Math.exp((_engine._rate - _engine._yield) * _engine._tte))
    end

    def _iv_bound(val)
      -2 / Math.sqrt(_engine._tte) * self.class.phi_inv((1 - _c) / val)
    end

    def _iv_u
      @_iv_u ||= _iv_bound(1 + Math.exp(_k))
    end

    def _iv_l
      @_iv_l ||= _iv_bound(_k.negative? ? 2 * Math.exp(_k) : 2)
    end

    def _step_width = (_iv_u - _iv_l) / _steps
    def _delta_fam(x_y) = @delta_fam.call(x_y, _epsilon)
  end

  ##
  # Solver for options parameters following Dekker-Brent
  class OptionsSolver < DekkerBrentSolver
    param :engine
    param :param, default: :iv
    param :param_search_adjust, default: 1.1, &:to_d

    def initialize(**args)
      super

      function!(
        lambda do |pv|
          _engine.send(_param, pv).solve_for(:price).price - _engine._price
        end
      )
    end

    protected

    def initial_estimates
      a0, b0 = super
      return a0, b0 if a0 && b0
      return approx_estimates unless a0 || b0

      est_u = a0 || b0
      est_l = est_u / _param_search_adjust
      search_estimates(est_l, est_u, _fn(est_l), _fn(est_u))
    end

    private

    def approx_estimates
      c = _engine._price / _engine._underlying_price
      k = Math.log(_engine._strike / _engine._underlying_price)
      est_u, est_l = approx_estimates_h(c, k)

      search_estimates(est_l, est_u, _fn(est_l), _fn(est_u))
    end

    def approx_estimates_h(param_c, param_k)
      [_iv_bound(param_c, 1 + Math.exp(param_k)),
       _iv_bound(param_c, param_k.negative? ? 2 * Math.exp(param_k) : 2)]
    end

    def search_estimates(est_l, est_u, fest_l, fest_u)
      if fest_u.negative?
        est_u, fest_u = search_estimates_h(est_u * _param_search_adjust, fest_u)
      end
      if fest_l.positive?
        est_l, fest_l = search_estimates_h(est_l / _param_search_adjust, fest_l)
      end
      return est_l, est_u if (fest_l * fest_u).negative?

      search_estimates(est_l, est_u, fest_l, fest_u)
    end

    def search_estimates_h(est, fest_old)
      fest = _fn(est)
      if (fest * fest_old).negative? || fest.abs < fest_old.abs
        [est, fest]
      else
        [-est, _fn(-est)]
      end
    end

    def _iv_bound(ccc, val)
      -2 / Math.sqrt(_engine._tte) * BSIVSolver.phi_inv((1 - ccc) / val)
    end
  end
end
