require 'rails_helper'

RSpec.describe ApplicationJob do
  describe '.retry_delay' do
    it 'backs off exponentially for an unprocessed photo, up to ten minutes' do
      expect(described_class.retry_delay(0, UnprocessedPhotoError.new)).to eq(1)
      expect(described_class.retry_delay(4, UnprocessedPhotoError.new)).to eq(16)
      expect(described_class.retry_delay(20, UnprocessedPhotoError.new)).to eq(10.minutes.to_i)
    end

    # Enough room for a slow analysis, where count + 1 seconds ran out in about half an hour.
    it 'spreads 25 retries for an unprocessed photo over hours' do
      total = (0...25).sum { |count| described_class.retry_delay(count, UnprocessedPhotoError.new) }
      expect(total).to be > 2.hours.to_i
    end

    it 'leaves other errors to Sidekiq' do
      expect(described_class.retry_delay(3, StandardError.new)).to be_nil
    end
  end

  describe 'retry blocks' do
    # A subclass that overrides retry_delay keeps the parent's rules through super;
    # declaring sidekiq_retry_in would have replaced them.
    let(:job_class) do
      Class.new(ApplicationJob) do
        def self.retry_delay(count, exception)
          exception.is_a?(ArgumentError) ? :discard : super
        end
      end
    end

    it 'gives every job a block that asks its own retry_delay' do
      expect(job_class.sidekiq_retry_in_block.call(0, ArgumentError.new)).to eq(:discard)
      expect(job_class.sidekiq_retry_in_block.call(2, UnprocessedPhotoError.new)).to eq(4)
    end

    it 'works for jobs further down the hierarchy' do
      grandchild = Class.new(job_class)
      expect(grandchild.sidekiq_retry_in_block.call(0, ArgumentError.new)).to eq(:discard)
    end
  end
end
