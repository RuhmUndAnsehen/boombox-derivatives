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

require 'active_support/inflector'

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
    #
    # This class can be overriden (see ::new_state) to abstract from the
    # underlying number type.
    State = Struct.new(:a_k, :b_k, :f_ak, :f_bk, :b_km1, :f_bkm1, :b_km2,
                       :f_bkm2, :bisect_flag, :tolerance,
                       keyword_init: true) do
      alias_method :bisect?, :bisect_flag

      def assert_unequal_signs
        raise EqualSignsError if (f_ak <=> 0) == (f_bk <=> 0)

        self
      end

      def bisect = (a_k + b_k) / 2

      def conditional_bisect
        sec = secant
        self.bisect_flag = bisect_condition(sec)
        bisect? ? bisect : sec
      end

      def convergence? = tolerable?(f_bk)
      def d_bk         = b_k   - b_km1
      def d_bkm1       = b_km1 - b_km2
      def d_fbk        = f_bk  - f_bkm1
      def diffquot_bk  = d_bk / d_fbk

      def sanitize
        return self unless f_bk.abs > f_ak.abs

        with!(a_k: b_k, b_k: a_k, f_ak: f_bk, f_bk: f_ak)
      end

      def secant = secant_cond? ? secant_intp : secant_grad

      def shift(times = 1)
        times.times { shift_once }
        self
      end
      alias_method :<<, :shift

      def tolerable?(arg) = arg.abs <= tolerance

      def update(sec, f_s)
        params = update?(f_s) ? %i[b_k f_bk] : %i[a_k f_ak]
        with!(**params.zip([sec, f_s]).to_h)
      end

      def update?(f_s) = (f_ak * f_s).negative?
      def with(**kwargs) = dup.with!(**kwargs)

      def with!(**kwargs)
        kwargs.each { |key, val| self[key] = val }
        self
      end

      private

      def bisect_condition(secant)
        (bs_cond_intp <=> secant) != (secant <=> b_k) ||
          bisect?  && bs_cond_helper(secant, d_bk) ||
          !bisect? && bs_cond_helper(secant, d_bkm1)
      end

      def bs_cond_helper(secant, d_bkx)
        (secant - b_k).abs >= d_bkx.abs / 2 || tolerable?(d_bkx)
      end

      def bs_cond_intp = (3 * a_k + b_k) / 4

      def i1 = interp_term(a_k,   f_ak,   f_bk, f_bkm1)
      def i2 = interp_term(b_k,   f_bk,   f_ak, f_bkm1)
      def i3 = interp_term(b_km1, f_bkm1, f_ak, f_bk)

      def interp_term(val, fval, foth1, foth2)
        val * foth1 * foth2 / (fval - foth1) / (fval - foth2)
      end

      def secant_cond? = f_ak != f_bk && f_bk != f_bkm1
      def secant_intp  = i1 + i2 + i3
      def secant_grad  = (1 - diffquot_bk) * f_bk

      def shift_once
        with!(b_km2: b_km1, b_km1: b_k, f_bkm2: f_bkm1, f_bkm1: f_bk)
      end
    end

    class << self
      def new_state(*args, **opts, &block) = State.new(*args, **opts, &block)
    end

    attr_accessor :state
    alias s state

    param :a0
    param :b0
    param :max_iterations, default: 42, is: :positive?
    param :tolerance, default: 1e-5, is_not: :negative?

    def _fn(*args, **opts, &block)
      unless @_fn
        raise NoMethodError, 'implement this function or pass a block to #solve'
      end

      @_fn.call(*args, **opts, &block)
    end

    def solve(&block)
      reset

      @_fn = block
      init_state
      recurse_solve(0)
    end

    protected

    def init_state
      self.state = self.class.new_state(a_k: _a0, b_k: _b0,
                                        f_ak: _fn(_a0), f_bk: _fn(_b0),
                                        bisect_flag: true,
                                        tolerance: _tolerance)
      state.assert_unequal_signs.sanitize.shift(2)
    end

    def recurse_solve(depth)
      return s.b_k if s.convergence? || depth >= _max_iterations

      update_params(s.conditional_bisect)
      recurse_solve(depth + 1)
    end

    def update_params(sec) = s.shift.update(sec, _fn(sec)).sanitize
  end

  ##
  # Solver for options parameters following Dekker-Brent
  class OptionsSolver < DekkerBrentSolver
    param :engine
    param :param, default: :iv, is: Symbol
    param :contract_value

    def _fn(estimate)
      _engine.with(_param => estimate).solve_for(:value) - _contract_value
    end

    def solve_for(param, &block)
      with(param:).solve(&block)
    end
  end

  ##
  # Solver for multiple options at the same time.
  #
  # This class assumes that #engine supports Torch::Tensor as parameters and
  # return values.
  class OptionsChainSolver < OptionsSolver
    ##
    # Specialization of DekkerBrentSolver::State for Torch::Tensor computations.
    class State < DekkerBrentSolver::State
      def initialize(**_)
        super

        return unless [true, false].include?(bisect_flag)

        self.bisect_flag = Torch.full_like(a_k || b_k, bisect_flag ? 1 : 0,
                                           dtype: :bool)
      end

      def assert_unequal_signs
        if f_ak.sign.int.eq(f_bk.sign.int).any?(&:item)
          raise DekkerBrentSolver::EqualSignsError
        end

        self
      end

      def bisect = a_k.add(b_k).div!(2)

      def conditional_bisect
        sec = secant
        self.bisect_flag = bisect_condition(sec)
        bisect.where(bisect_flag, sec)
      end

      def convergence? = super.all?(&:item)
      def diffquot_bk  = d_bk.div!(d_fbk)

      def sanitize
        invalids = f_bk.abs.gt(f_ak.abs)

        new_a_k  = a_k.where(invalids, b_k)
        new_b_k  = b_k.where(invalids, a_k)
        new_f_ak = f_ak.where(invalids, f_bk)
        new_f_bk = f_bk.where(invalids, f_ak)

        with!(a_k: new_a_k, b_k: new_b_k, f_ak: new_f_ak, f_bk: new_f_bk)
      end

      def secant = secant_intp.where(secant_cond?, secant_grad)
      def tolerable?(arg) = arg.abs.le(tolerance)

      def update(secant, f_s)
        nans  = secant.isnan
        cond  = update?(f_s).logical_or!(nans)
        icond = cond.logical_not.logical_or!(nans)

        new_a_k  = a_k.where(cond, secant)
        new_b_k  = b_k.where(icond, secant)
        new_f_ak = f_ak.where(cond, f_s)
        new_f_bk = f_bk.where(icond, f_s)

        with!(a_k: new_a_k, b_k: new_b_k, f_ak: new_f_ak, f_bk: new_f_bk)
      end

      def update?(f_s) = f_ak.mul(f_s).lt(0)

      private

      def bisect_condition(secant)
        bs_cond_first(secant)
          .logical_or!(bisect?.logical_and(bs_cond_helper(secant, d_bk)))
          .logical_or!(bisect?.logical_not
                              .logical_and(bs_cond_helper(secant, d_bkm1)))
      end

      def bs_cond_first(secant)
        bs_cond_intp.sub!(secant).sign!.int
                    .ne(secant.sub(b_k).sign!.int)
      end

      def bs_cond_helper(secant, d_bkx)
        secant.sub(b_k).abs!
              .ge(d_bkx.abs.div!(2))
              .logical_or!(tolerable?(d_bkx))
      end

      def bs_cond_intp = b_k.add(a_k, alpha: 3).div!(4)

      def interp_term(val, fval, foth1, foth2)
        val.mul(foth1).mul!(foth2)
           .div!(fval.sub(foth1))
           .div!(fval.sub(foth2))
      end

      def secant_cond? = f_ak.ne(f_bk).logical_and!(f_bk.ne(f_bkm1))
      def secant_grad  = f_bk.addcmul(f_bk, diffquot_bk, value: -1)
      def secant_intp  = i1.add(i2).add!(i3)
    end

    class << self
      def new_state(*args, **opts, &block) = State.new(*args, **opts, &block)
    end

    param :param, default: :iv, is: Symbol,
                  to: ->(prm) { ActiveSupport::Inflector.pluralize(prm).to_sym }
  end
end
