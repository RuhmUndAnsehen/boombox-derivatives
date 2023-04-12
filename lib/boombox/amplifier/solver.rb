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
