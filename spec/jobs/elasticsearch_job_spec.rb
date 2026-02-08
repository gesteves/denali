require 'rails_helper'

RSpec.describe ElasticsearchJob, type: :worker do
  let(:blog) { create(:blog) }
  let(:user) { create(:user) }
  let(:entry) { create(:entry, :published, blog: blog, user: user) }

  describe '#perform' do
    let(:es_proxy) { double('elasticsearch_proxy') }

    before do
      allow_any_instance_of(Entry).to receive(:__elasticsearch__).and_return(es_proxy)
    end

    context 'with create operation' do
      it 'indexes the document' do
        expect(es_proxy).to receive(:index_document)
        described_class.new.perform(entry.id, 'create')
      end
    end

    context 'with update operation' do
      it 'updates the document' do
        expect(es_proxy).to receive(:update_document)
        described_class.new.perform(entry.id, 'update')
      end
    end

    context 'with delete operation' do
      it 'deletes the document' do
        expect(es_proxy).to receive(:delete_document)
        described_class.new.perform(entry.id, 'delete')
      end
    end

    context 'with non-existent entry_id' do
      it 'returns early without error' do
        # The worker handles RecordNotFound gracefully
        expect {
          described_class.new.perform(999999, 'create')
        }.not_to raise_error
      end

      it 'does not attempt elasticsearch operations' do
        expect(es_proxy).not_to receive(:index_document)
        expect(es_proxy).not_to receive(:update_document)
        expect(es_proxy).not_to receive(:delete_document)

        described_class.new.perform(999999, 'update')
      end
    end
  end
end
