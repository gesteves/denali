require 'rails_helper'

RSpec.describe JobDeathReporter do
  let(:job) { { 'class' => 'ThreadsJob', 'jid' => 'abc', 'queue' => 'high', 'args' => [1, 'Caption'], 'retry_count' => 7 } }

  # Bugsnag discards these classes, and they're the ones that die quietly.
  it 'reports the death as an error of its own, so the discard list does not swallow it' do
    expect(Bugsnag).to receive(:notify) do |error|
      expect(error).to be_a(JobDeathReporter::JobDied)
      expect(error.cause).to be_nil
      expect(error.message).to eq('ThreadsJob gave up after 8 retries: MetaTransientError: try later')
    end

    described_class.call(job, MetaTransientError.new('try later'))
  end

  it 'says when the retry rules discarded the job' do
    expect(Bugsnag).to receive(:notify) do |error|
      expect(error.message).to start_with('ThreadsJob discarded: MetaCaptionTooLongError')
    end

    described_class.call(job.merge('discarded_at' => 1), MetaCaptionTooLongError.new('too long'))
  end
end
