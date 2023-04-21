# frozen_string_literal: true

require 'boombox/derivatives/options'

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
            context 'and 853 steps' do
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

RSpec.describe Boombox::FastLRChainEngine do
  describe '#update' do
    engine = described_class.new(
      expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
      iv: 0.3, rate: 0.07, spot: 100, steps: 25, time: Time.new(2000, 1, 1)
    )
    it 'should have initialized the correct parameters' do
      expect(engine.param(:chain)
                   .template.initialized_params.map(&:decl).map(&:name).sort)
        .to eq(%i[expiry iv rate spot steps time])
    end

    context 'with given strikes' do
      engine.with!(chain: [80, 90, 100, 110, 120].map { |strike| { strike: } })
      it 'should not change the #template' do
        expect(engine.param(:chain)
                     .template.initialized_params.map(&:decl).map(&:name).sort)
          .to eq(%i[expiry iv rate spot steps time])
      end
      it 'should initialize the #chain\'s parameters' do
        expect(engine.param(:chain).raw_value.size).to eq(5)
        params = engine.param(:chain)
                       .value.map do |actual|
          actual.transform_values do |value|
            case value
            when Torch::Tensor then value.item
            else
              value
            end
          end
        end
        params.zip([80, 90, 100, 110, 120])
              .each do |actual, strike|
                expect(actual)
                  .to include(expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
                              iv: a_value_within(FLR_PRECISION).of(0.3),
                              rate: a_value_within(FLR_PRECISION).of(0.07),
                              spot: a_value_within(FLR_PRECISION).of(100),
                              steps: 25,
                              strike: a_value_within(FLR_PRECISION).of(strike),
                              time: Time.new(2000, 1, 1))
              end
      end

      context 'with given style and type' do
        engine2 = engine.with(style: :european, type: :call)
        it 'should update the #template' do
          expect(engine2.param(:chain).template
                        .initialized_params.map(&:decl).map(&:name).sort)
            .to eq(%i[expiry iv rate spot steps style time type])
        end
        it 'should update the #chain\'s parameters' do
          expect(engine2.param(:chain).raw_value.size).to eq(5)
          params = engine2.param(:chain)
                          .value.map do |actual|
            actual.transform_values do |value|
              case value
              when Torch::Tensor then value.item
              else
                value
              end
            end
          end
          params.zip([80, 90, 100, 110, 120])
                .each do |actual, strike|
                  expect(actual)
                    .to include(expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
                                iv: a_value_within(FLR_PRECISION).of(0.3),
                                rate: a_value_within(FLR_PRECISION).of(0.07),
                                spot: a_value_within(FLR_PRECISION).of(100),
                                steps: 25,
                                strike: a_value_within(FLR_PRECISION)
                                          .of(strike),
                                style: :european,
                                time: Time.new(2000, 1, 1),
                                type: :call)
                end
        end
      end
      context 'with parameters passed to the #chain engines directly' do
        engine2 = engine.with(iv: 5.0, style: :european, type: :call)
                        .with!(chain: [80, 90, 100, 110, 120].map do |strike|
                                        { strike: }
                                      end,
                               ivs: Torch.tensor([0.3]))
                        .with!(ivs: Torch.tensor([0.3]))
        # .with!(chain: 5.times.map { {iv: 0.3} })
        it 'should the #chain members\' parameters' do
          params = engine2.param(:chain)
                          .value.map do |actual|
            actual.transform_values do |value|
              case value
              when Torch::Tensor then value.item
              else
                value
              end
            end
          end
          params.zip([80, 90, 100, 110, 120])
                .each do |actual, strike|
                  expect(actual)
                    .to include(expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
                                iv: a_value_within(FLR_PRECISION).of(0.3),
                                rate: a_value_within(FLR_PRECISION).of(0.07),
                                spot: a_value_within(FLR_PRECISION).of(100),
                                steps: 25,
                                strike: a_value_within(FLR_PRECISION)
                                          .of(strike),
                                style: :european,
                                time: Time.new(2000, 1, 1),
                                type: :call)
                end
        end
      end
    end
  end

  describe '#solve_for(:value)' do
    engine = described_class.new(
      expiry: Time.new(2000, 1, 1) + 365 * 12 * 3600,
      iv: 0.3, rate: 0.07, spot: 100, steps: 853, time: Time.new(2000, 1, 1)
    )
    context 'with given strikes' do
      engine.with!(chain: [80, 90, 100, 110, 120].map { |strike| { strike: } })
      it 'should compute European style call prices' do
        engine2 = engine.with(style: :european, type: :call)
        engine2.solve_for(:value)
               .map(&:item)
               .zip([23.75799, 16.09963, 10.13377, 5.94946, 3.28280])
               .each do |actual, target|
                 expect(actual).to be_within(FLR_PRECISION).of(target)
               end
      end
    end
    context 'with template parameters passed directly to the chain engines' do
      engine2 = engine.with(iv: 5.0, style: :european, type: :call)
                      .with!(chain: [80, 90, 100, 110, 120].map do |strike|
                                      { strike: }
                                    end,
                             ivs: Torch.tensor([0.3]))
      it 'should compute European style call prices' do
        engine2.solve_for(:value)
               .map(&:item)
               .zip([23.75799, 16.09963, 10.13377, 5.94946, 3.28280])
               .each do |actual, target|
                 expect(actual).to be_within(FLR_PRECISION).of(target)
               end
      end
    end
  end
end
