# frozen_string_literal: true

require 'spec_helper'

require './handler'

describe DataPipeline::Handlers::Copy do
  let(:environment) { { 'PROCESS_BUCKET' => 'test-bucket' } }
  let(:client) { Aws::S3::Client.new(stub_responses: true) }

  def api_requests
    client.api_requests.map { |request| request.slice(*%i[params operation_name]) }
  end

  describe '#process' do
    before do
      DataPipeline::Handler.run(handler: described_class, event:, client:,
                                environment:, logger: Logger.new(IO::NULL))
    end

    context 'with a file' do
      let(:event) { DataPipeline::Support::Events.file_event(filename: 'amr-data/edf/test-file') }

      it 'does a copy object with the correct parameters' do
        expect(api_requests).to eq([{ params: { bucket: environment['PROCESS_BUCKET'],
                                                copy_source: 'bucket/amr-data/edf/test-file',
                                                key: 'edf/20250323-101112/test-file' },
                                      operation_name: :copy_object }])
      end
    end

    context 'with an incorrect key' do
      let(:event) { DataPipeline::Support::Events.file_event(filename: 'test-file') }

      it 'does nothing' do
        expect(api_requests).to eq([])
      end
    end
  end
end
