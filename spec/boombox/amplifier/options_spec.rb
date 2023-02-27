# frozen_string_literal: true

require 'boombox/amplifier/options'

LR_PRECISION = 1e-5

RSpec.describe Boombox::LeisenReimerEngine do
  describe '.params' do
    it 'should return the expected parameter names' do
      expect(described_class.params.keys.sort).to eq(%i[expiry iv rate spot
                                                        steps strike style time
                                                        type yield])
    end
  end
  describe '#solve_for(:value)' do
    engine = described_class.new
    context 'with underlying price at 100' do
      engine.with!(spot: 100, time: Time.new(2000, 1, 1))
      context 'and rate at 0.07' do
        engine.with!(rate: 0.07)
        context 'and implied volatility at 0.3' do
          engine.with!(iv: 0.3)
          context 'and tte 0.5 years' do
            engine.with!(expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600)
            context 'and 25 steps' do
              engine.with!(steps: 25)
              it 'should compute European style call prices' do
                engine2 = engine.with(style: :european, type: :call)
                expect(engine2.with(strike: 80).solve_for(:value))
                  .to be_within(LR_PRECISION).of(23.75822)
                expect(engine2.with(strike: 90).solve_for(:value))
                  .to be_within(LR_PRECISION).of(16.09941)
                expect(engine2.with(strike: 100).solve_for(:value))
                  .to be_within(LR_PRECISION).of(10.13316)
                expect(engine2.with(strike: 110).solve_for(:value))
                  .to be_within(LR_PRECISION).of(5.94889)
                expect(engine2.with(strike: 120).solve_for(:value))
                  .to be_within(LR_PRECISION).of(3.28258)
              end
              it 'should compute European style put prices' do
                engine2 = engine.with(style: :european, type: :put)
                expect(engine2.with(strike: 80).solve_for(:value))
                  .to be_within(LR_PRECISION).of(1.00665)
                expect(engine2.with(strike: 90).solve_for(:value))
                  .to be_within(LR_PRECISION).of(3.00390)
                expect(engine2.with(strike: 100).solve_for(:value))
                  .to be_within(LR_PRECISION).of(6.69370)
                expect(engine2.with(strike: 110).solve_for(:value))
                  .to be_within(LR_PRECISION).of(12.16548)
                expect(engine2.with(strike: 120).solve_for(:value))
                  .to be_within(LR_PRECISION).of(19.15523)
              end
              it 'should compute American style put prices' do
                engine2 = engine.with(style: :american, type: :put)
                expect(engine2.with(strike: 80).solve_for(:value))
                  .to be_within(LR_PRECISION).of(1.04264)
                expect(engine2.with(strike: 90).solve_for(:value))
                  .to be_within(LR_PRECISION).of(3.12832)
                expect(engine2.with(strike: 100).solve_for(:value))
                  .to be_within(LR_PRECISION).of(7.02858)
                expect(engine2.with(strike: 110).solve_for(:value))
                  .to be_within(LR_PRECISION).of(12.93136)
                expect(engine2.with(strike: 120).solve_for(:value))
                  .to be_within(LR_PRECISION).of(20.67576)
              end
            end
          end
        end
      end
    end
  end
end

BS_PRECISION = 1e-5

RSpec.describe Boombox::BlackScholesEngine do
  describe '#solve_for(:value)' do
    engine = described_class.new
    context 'with underlying price at 100' do
      engine.with!(spot: 100, time: Time.new(2000, 1, 1))
      context 'and rate at 0.07' do
        engine.with!(rate: 0.07)
        context 'and implied volatility at 0.3' do
          engine.with!(iv: 0.3)
          context 'and tte 0.5 years' do
            engine.with!(expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600)
            it 'should compute European style call prices' do
              engine2 = engine.with(type: :call)
              expect(engine2.with(strike: 80).solve_for(:value))
                .to be_within(BS_PRECISION).of(23.75799)
              expect(engine2.with(strike: 90).solve_for(:value))
                .to be_within(BS_PRECISION).of(16.09963)
              expect(engine2.with(strike: 100).solve_for(:value))
                .to be_within(BS_PRECISION).of(10.13377)
              expect(engine2.with(strike: 110).solve_for(:value))
                .to be_within(BS_PRECISION).of(5.94946)
              expect(engine2.with(strike: 120).solve_for(:value))
                .to be_within(BS_PRECISION).of(3.28280)
            end
            it 'should compute European style call prices' do
              engine2 = engine.with(type: :put)
              expect(engine2.with(strike: 80).solve_for(:value))
                .to be_within(BS_PRECISION).of(1.00642)
              expect(engine2.with(strike: 90).solve_for(:value))
                .to be_within(BS_PRECISION).of(3.00412)
              expect(engine2.with(strike: 100).solve_for(:value))
                .to be_within(BS_PRECISION).of(6.69431)
              expect(engine2.with(strike: 110).solve_for(:value))
                .to be_within(BS_PRECISION).of(12.16606)
              expect(engine2.with(strike: 120).solve_for(:value))
                .to be_within(BS_PRECISION).of(19.15545)
            end
          end
        end
      end
    end
  end
end

FLR_PRECISION = 1e-3

RSpec.describe Boombox::FastLREngine do
  describe '.params' do
    it 'should return the expected parameter names' do
      expect(described_class.params.keys.sort).to eq(%i[expiry iv rate spot
                                                        steps strike style time
                                                        type value yield])
    end
  end
  describe '#solve' do
    engine = described_class.new
    context 'with underlying price at 100' do
      engine.with!(spot: 100, time: Time.new(2000, 1, 1))
      context 'and rate at 0.07' do
        engine.with!(rate: 0.07)
        context 'and implied volatility at 0.3' do
          engine.with!(iv: 0.3)
          context 'and tte 0.5 years' do
            engine.with!(expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600)
            context 'and 25 steps' do
              engine.with!(steps: 853)
              it 'should compute European style call prices' do
                engine2 = engine.with(style: :european, type: :call)
                expect(engine2.with(strike: 80).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(23.75799)
                expect(engine2.with(strike: 90).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(16.09963)
                expect(engine2.with(strike: 100).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(10.13377)
                expect(engine2.with(strike: 110).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(5.94946)
                expect(engine2.with(strike: 120).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(3.28280)
              end
              it 'should compute European style put prices' do
                engine2 = engine.with(style: :european, type: :put)
                expect(engine2.with(strike: 80).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(1.00642)
                expect(engine2.with(strike: 90).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(3.00412)
                expect(engine2.with(strike: 100).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(6.69431)
                expect(engine2.with(strike: 110).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(12.16606)
                expect(engine2.with(strike: 120).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(19.15545)
              end
              it 'should compute American style put prices' do
                engine2 = engine.with(style: :american, type: :put)
                expect(engine2.with(strike: 80).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(1.037)
                expect(engine2.with(strike: 90).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(3.123)
                expect(engine2.with(strike: 100).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(7.035)
                expect(engine2.with(strike: 110).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(12.955)
                expect(engine2.with(strike: 120).solve_for(:value).item)
                  .to be_within(FLR_PRECISION).of(20.717)
              end
            end
          end
        end
      end
    end
  end
end
