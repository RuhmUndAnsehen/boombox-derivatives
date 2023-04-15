# frozen_string_literal: true

#    This file is part of Boombox Amplifier.
#
#    Boombox Amplifier is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by the
#    Free Software Foundation, either version 3 of the License, or (at your
#    option) any later version.
#
#    Boombox Amplifier is distributed in the hope that it will be useful, but
#    WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
#    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
#    more details.
#
#    You should have received a copy of the GNU General Public License along
#    with Boombox Amplifier. If not, see <https://www.gnu.org/licenses/>.

require 'bigdecimal'
require 'bigdecimal/math'
require 'bigdecimal/util'

require_relative 'dsl'

module Boombox
  ##
  # General purpose solver following the Dekker-Brent method.
  class DekkerBrentSolver < DSL::Engine
    ##
    # Thrown when the initial estimates have equal signs.
    class EqualSignsError < ArgumentError; end

    ##
    # The solver's internal state.
    State = Struct.new(:a_k, :b_k, :f_ak, :f_bk, :b_km1, :f_bkm1, :b_km2,
                       :f_bkm2, :bisect_condition, keyword_init: true) do
      alias_method :bisect?, :bisect_condition

      def assert_unequal_signs
        raise EqualSignsError if (f_ak <=> 0) == (f_bk <=> 0)

        self
      end

      def convergence?(tolerance = 1e-6) = f_bk.abs < tolerance
      def d_bk        = b_k   - b_km1
      def d_bkm1      = b_km1 - b_km2
      def d_fbk       = f_bk  - f_bkm1
      def diffquot_bk = d_bk / d_fbk

      def sanitize
        return self unless f_bk.abs > f_ak.abs

        self.a_k,  self.b_k  = b_k,  a_k
        self.f_ak, self.f_bk = f_bk, f_ak
        self
      end

      def shift(times = 1)
        shift(times - 1) if times > 1
        shift_once
        self
      end
      alias_method :<<, :shift

      def shift_once
        self.b_km2  = b_km1
        self.b_km1  = b_k
        self.f_bkm2 = f_bkm1
        self.f_bkm1 = f_bk
      end

      def with(**kwargs) = dup.with!(**kwargs)

      def with!(**kwargs)
        kwargs.each { |key, val| self[key] = val }
        self
      end
    end

    attr_accessor :state
    alias s state

    param :a0, to: :to_d
    param :b0, to: :to_d
    param :max_iterations, default: 42, is: :positive?
    param :tolerance, default: 1e-6, to: :to_d, is_not: :negative?

    def _fn(*args, **opts, &block)
      unless @_fn
        raise NoMethodError, 'implement this function or pass a block to #solve'
      end

      @_fn.call(*args, **opts, &block)
    end

    def solve(&block)
      reset

      @_fn = block
      self.state = new_state
      s.assert_unequal_signs.sanitize.shift(2)
      s.bisect_condition = true
      recurse_solve(0)
    end

    protected

    def new_state
      State.new(a_k: _a0, b_k: _b0, f_ak: _fn(_a0), f_bk: _fn(_b0))
    end

    def recurse_solve(depth)
      return s.b_k if s.convergence?(_tolerance) || depth >= _max_iterations

      sec = secant
      if bisect_condition(sec)
        sec = bisect
        s.bisect_condition = true
      else
        s.bisect_condition = false
      end

      update_params(sec)
      recurse_solve(depth + 1)
    end

    def update_params(sec)
      s.shift
      fs = _fn(sec)
      if (s.f_ak * fs).negative?
        s.b_k  = sec
        s.f_bk = fs
      else
        s.a_k  = sec
        s.f_ak = fs
      end
      s.sanitize
    end

    private

    def sign(val) = val <=> 0
    def bisect = (s.a_k + s.b_k) / 2

    def bisect_condition(secant)
      intp = (3 * s.a_k + s.b_k) / 4
      (intp <=> secant) != (secant <=> s.b_k) ||
        s.bisect?  && bs_cond_helper(secant, s.d_bk) ||
        !s.bisect? && bs_cond_helper(secant, s.d_bkm1)
    end

    def bs_cond_helper(secant, d_bkx)
      (secant - s.b_k).abs >= d_bkx.abs / 2 || d_bkx.abs < _tolerance
    end

    def secant
      if s.f_ak != s.f_bk && s.f_bk != s.f_bkm1
        i1 = interp_term(:a_k,   :f_ak,   :f_bk, :f_bkm1)
        i2 = interp_term(:b_k,   :f_bk,   :f_ak, :f_bkm1)
        i3 = interp_term(:b_km1, :f_bkm1, :f_ak, :f_bk)
        i1 + i2 + i3
      else
        (1 - s.diffquot_bk) * s.f_bk
      end
    end

    def interp_term(*syms)
      val, fval, foth1, foth2 = *syms.map(&s.method(:[]))
      val * foth1 * foth2 / (fval - foth1) / (fval - foth2)
    end
  end

  ##
  # Solver for options parameters following Dekker-Brent
  class OptionsSolver < DekkerBrentSolver
    param :engine
    param :param, default: :iv, is: Symbol
    param :contract_value, to: :to_d

    def _fn(estimate)
      _engine.with(_param => estimate).solve_for(:value) - _contract_value
    end

    def solve_for(param, &block)
      with(param:).solve(&block)
    end
  end
end
