# frozen_string_literal: true

require 'spec_helper'

require './handler'

describe DataPipeline::Handlers::ConvertFile do
  describe '#process' do
    let(:npower_xls)   { File.open('spec/support/files/npower-eon_export.xls') }
    let(:npower_xlsx)  { File.open('spec/support/files/npower-eon_export.xlsx') }
    let(:bryt_xlsx) { File.open('spec/support/files/bryt_multi-sheet.xlsx') }
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
          when 'npower-eon/20250323-101112/export.xls', 'npower-eon/20250323-101112/export.XLS'
            { body: npower_xls }
          when 'npower-eon/20250323-101112/export.xlsx', 'npower-eon/20250323-101112/export.XLSX'
            { body: npower_xlsx }
          when 'bryt/20250323-101112/multi-sheet.xlsx'
            { body: bryt_xlsx }
          when 'sheffield/20250323-101112/image.png'
            { body: unknown_file }
          else
            'NotFound'
          end
        }
      )
      response
    end

    describe 'when the file is xlsx' do
      let(:event) { DataPipeline::Support::Events.xlsx_added }

      it 'puts the converted file in the PROCESS_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:bucket]).to eq('process-bucket')
        expect(request[:params][:key]).to eq('npower-eon/20250323-101112/export.xlsx.csv')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is xlsx and has multiple sheets' do
      let(:event) { DataPipeline::Support::Events.xlsx_multi_added }

      it 'puts the converted file in the PROCESS_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:bucket]).to eq('process-bucket')
        expect(request[:params][:key]).to eq('bryt/20250323-101112/multi-sheet.xlsx.csv')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is XLSX' do
      let(:event) { DataPipeline::Support::Events.uppercase_xlsx_added }

      it 'puts the converted file in the PROCESS_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:bucket]).to eq('process-bucket')
        expect(request[:params][:key]).to eq('npower-eon/20250323-101112/export.XLSX.csv')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is xls' do
      let(:event) { DataPipeline::Support::Events.xls_added }

      it 'puts the converted file in the PROCESS_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:bucket]).to eq('process-bucket')
        expect(request[:params][:key]).to eq('npower-eon/20250323-101112/export.xls.csv')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is XLS' do
      let(:event) { DataPipeline::Support::Events.uppercase_xls_added }

      it 'puts the converted file in the PROCESS_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:bucket]).to eq('process-bucket')
        expect(request[:params][:key]).to eq('npower-eon/20250323-101112/export.XLS.csv')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file does not convert' do
      let(:event) { DataPipeline::Support::Events.image_added }

      it 'puts the file in the UNPROCESSABLE_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:bucket]).to eq('unprocessable-bucket')
        expect(request[:params][:key]).to eq('sheffield/20250323-101112/image.png')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end
  end
end
