# frozen_string_literal: true

require 'boombox/derivatives/options'
require 'boombox/derivatives/solver'

SOLV_PRECISION = 1e-6

RSpec.shared_examples 'iv_solver_eu_tests_calls' do |engine, solver|
  it 'should compute call iv' do
    engine = engine.with(type: :call)
    solver = solver.with(engine:)
    expect(solver.with(engine: engine.with(strike: 80),
                       contract_value: 23.75799).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 90),
                       contract_value: 16.09963).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 100),
                       contract_value: 10.13377).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 110),
                       contract_value: 5.94946).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 120),
                       contract_value: 3.28280).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
  end
end

RSpec.shared_examples 'iv_solver_eu_tests_puts' do |engine, solver|
  it 'should compute put iv' do
    engine = engine.with(type: :put)
    solver = solver.with(engine:)
    expect(solver.with(engine: engine.with(strike: 80),
                       contract_value: 1.00642).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 90),
                       contract_value: 3.00412).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 100),
                       contract_value: 6.69431).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 110),
                       contract_value: 12.16606).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 120),
                       contract_value: 19.15545).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
  end
end

RSpec.shared_examples 'iv_solver_us_tests_puts' do |engine, solver|
  it 'should compute put iv' do
    engine = engine.with(type: :put)
    solver = solver.with(engine:)
    expect(solver.with(engine: engine.with(strike: 80),
                       contract_value: 1.04264).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 90),
                       contract_value: 3.12832).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 100),
                       contract_value: 7.02858).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 110),
                       contract_value: 12.93136).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
    expect(solver.with(engine: engine.with(strike: 120),
                       contract_value: 20.67576).solve_for(:iv))
      .to be_within(SOLV_PRECISION).of(0.3)
  end
end

RSpec.shared_examples 'iv_solver_eu' do |engine_class|
  engine = engine_class.new
                       .with!(
                         expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
                         rate: 0.07,
                         spot: 100,
                         time: Time.new(2000, 1, 1)
                       )
  solver = described_class.new.with(param: :iv)
  context 'with given parameter range' do
    solver2 = solver.with(a0: 0.2, b0: 0.31)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate a0 below actual value' do
    solver2 = solver.with(a0: 0.25, b0: 10)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate a0 above actual value' do
    solver2 = solver.with(a0: 0.35, b0: 1e-5)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate b0 below actual value' do
    solver2 = solver.with(a0: 10, b0: 0.25)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate b0 above actual value' do
    solver2 = solver.with(a0: 1e-5, b0: 0.35)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'without initial estimates' do
    solver2 = solver.with(a0: 1e-5, b0: 10)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
end

RSpec.shared_examples 'iv_solver_us' do |engine_class|
  engine = engine_class.new
                       .with!(
                         expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
                         rate: 0.07,
                         spot: 100,
                         steps: 25,
                         style: :american,
                         time: Time.new(2000, 1, 1)
                       )
  solver = described_class.new.with(param: :iv)
  context 'with given parameter range' do
    solver2 = solver.with(a0: 0.2, b0: 0.31)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate a0 below actual value' do
    solver2 = solver.with(a0: 0.25, b0: 10)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate a0 above actual value' do
    solver2 = solver.with(a0: 0.35, b0: 1e-2)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate b0 below actual value' do
    solver2 = solver.with(a0: 10, b0: 0.25)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate b0 above actual value' do
    solver2 = solver.with(a0: 1e-2, b0: 0.35)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
end

RSpec.describe Boombox::OptionsSolver do
  describe '#solve' do
    context 'with European style engine' do
      include_examples 'iv_solver_eu', Boombox::BlackScholesEngine
    end
    context 'with American style engine' do
      include_examples 'iv_solver_us', Boombox::LeisenReimerEngine
    end
  end
end

RSpec.describe Boombox::OptionsChainSolver do
  describe '#solve' do
    engine = Boombox::FastLRChainEngine.new(
      chain: [80, 90, 100, 110, 120].map { |strike| { strike: } },
      expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
      iv: 0.3, rate: 0.07, spot: 100, steps: 853, time: Time.new(2000, 1, 1)
    )
    contract_value = Torch.tensor([23.75799, 16.09963, 10.13377, 5.94946,
                                   3.28280])
    solver = described_class.new(a0: Torch.tensor([3e-2]),
                                 b0: Torch.tensor([0.5]),
                                 contract_value:, engine:, param: :iv)
    it 'should accurately solve multiple problems at the same time' do
      solver.solve.map(&:item)
            .each do |result|
        expect(result).to be_within(SOLV_PRECISION).of(0.3)
      end
    end
  end
end
