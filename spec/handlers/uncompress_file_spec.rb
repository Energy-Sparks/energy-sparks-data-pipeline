# frozen_string_literal: true

require 'spec_helper'

require './handler'

describe DataPipeline::Handlers::UncompressFile do
  describe '#process' do
    let(:sheffield_csv) { File.open('spec/support/files/sheffield_export.csv') }
    let(:sheffield_zip) { File.open('spec/support/files/sheffield_export.zip') }
    let(:unknown_file) { File.open('spec/support/files/1x1.png') }

    let(:logger) { Logger.new(IO::NULL) }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:environment) do
      {
        'PROCESS_BUCKET' => 'process-bucket',
        'UNPROCESSABLE_BUCKET' => 'unprocessable-bucket'
      }
    end

    let(:handler) { described_class }
    let(:response) do
      DataPipeline::Handler.run(handler:, event:, client:, environment:, logger:)
    end

    before do
      client.stub_responses(
        :get_object, lambda { |context|
          case context.params[:key]
          when 'sheffield/20250323-101112/export.zip'
            { body: sheffield_zip }
          when 'sheffield/20250323-101112/image.png'
            { body: unknown_file }
          else
            'NotFound'
          end
        }
      )
      response
    end

    describe 'when the file is a zip' do
      let(:event) { DataPipeline::Support::Events.zip_added }

      it 'puts the unzipped file in the PROCESS_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/20250323-101112/4003063_9232_Export_20181108_120524_290.csv')
        expect(request[:params][:bucket]).to eq('process-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file does not unzip' do
      let(:event) { DataPipeline::Support::Events.image_added }

      it 'puts the file in the UNPROCESSABLE_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/20250323-101112/image.png')
        expect(request[:params][:bucket]).to eq('unprocessable-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end
  end
end
