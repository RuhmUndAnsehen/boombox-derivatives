# frozen_string_literal: true

require 'boombox/amplifier/options'
require 'boombox/amplifier/solver'

PRECISION = 1e-6

RSpec.shared_examples 'iv_solver_eu_tests_calls' do |engine, solver|
  it 'should compute call iv' do
    engine = engine.type(:call)
    solver = solver.engine(engine)
    expect(solver.engine(engine.strike(80).price(23.75799)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(90).price(16.09963)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(100).price(10.13377)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(110).price(5.94946)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(120).price(3.28280)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
  end
end

RSpec.shared_examples 'iv_solver_eu_tests_puts' do |engine, solver|
  it 'should compute put iv' do
    engine = engine.type(:put)
    solver = solver.engine(engine)
    expect(solver.engine(engine.strike(80).price(1.00642)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(90).price(3.00412)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(100).price(6.69431)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(110).price(12.16606)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(120).price(19.15545)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
  end
end

RSpec.shared_examples 'iv_solver_us_tests_puts' do |engine, solver|
  it 'should compute put iv' do
    engine = engine.type(:put)
    solver = solver.engine(engine)
    expect(solver.engine(engine.strike(80).price(1.04264)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(90).price(3.12832)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(100).price(7.02858)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(110).price(12.93136)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
    expect(solver.engine(engine.strike(120).price(20.67576)).solve.round(5))
      .to be_within(PRECISION).of(0.3)
  end
end

RSpec.shared_examples 'iv_solver_eu' do |engine_class|
  engine = engine_class
           .new
           .underlying!(
             Boombox::Underlying.new(100, Time.new(2000, 1, 1))
           )
           .rate!(0.07)
           .expiry!(Time.new(2000, 1, 1) + 365 * 12 * 3600)
  solver = described_class.new.param(:iv)
  context 'with given parameter range' do
    solver2 = solver.a0(0.2).b0(0.31)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate a0 below actual value' do
    solver2 = solver.a0(0.25)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate a0 below actual value' do
    solver2 = solver.a0(0.35)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate b0 below actual value' do
    solver2 = solver.b0(0.25)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'with given estimate b0 below actual value' do
    solver2 = solver.b0(0.35)
    include_examples 'iv_solver_eu_tests_puts', engine, solver2
    include_examples 'iv_solver_eu_tests_calls', engine, solver2
  end
  context 'without initial estimates' do
    include_examples 'iv_solver_eu_tests_puts', engine, solver
    include_examples 'iv_solver_eu_tests_calls', engine, solver
  end
end

RSpec.shared_examples 'iv_solver_us' do |engine_class|
  engine = engine_class
           .new.style!(:american)
           .steps!(25)
           .underlying!(Boombox::Underlying.new(100,
                                                Time.new(2000, 1, 1)))
           .rate!(0.07)
           .expiry!(Time.new(2000, 1, 1) + 365 * 12 * 3600)
  solver = described_class.new.param(:iv)
  context 'with given parameter range' do
    solver2 = solver.a0(0.2).b0(0.31)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate a0 below actual value' do
    solver2 = solver.a0(0.25)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate a0 below actual value' do
    solver2 = solver.a0(0.35)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate b0 below actual value' do
    solver2 = solver.b0(0.25)
    include_examples 'iv_solver_us_tests_puts', engine, solver2
    # include_examples 'iv_solver_us_tests_calls', engine, solver2
  end
  context 'with given estimate b0 below actual value' do
    solver2 = solver.b0(0.35)
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
