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
      let(:client) { double('elasticsearch_client') }

      before do
        allow(Entry.__elasticsearch__).to receive(:client).and_return(client)
      end

      # The job runs after the row is destroyed, so it can't load the record.
      it 'deletes the document by ID once the entry is gone' do
        entry_id = entry.id
        entry.destroy!

        expect(client).to receive(:delete).with(index: Entry.index_name, id: entry_id, ignore: 404)
        described_class.new.perform(entry_id, 'delete')
      end

      it "accepts 'destroy' from jobs enqueued before the rename" do
        expect(client).to receive(:delete).with(index: Entry.index_name, id: 123, ignore: 404)
        described_class.new.perform(123, 'destroy')
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
