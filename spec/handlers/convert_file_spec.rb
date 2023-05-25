require 'spec_helper'

require './handler'

describe DataPipeline::Handlers::ConvertFile do

  describe '#process' do
    let(:npower_xls)   { File.open('spec/support/files/npower-eon_export.xls') }
    let(:npower_xlsx)  { File.open('spec/support/files/npower-eon_export.xlsx') }
    let(:unknown_file) { File.open('spec/support/files/1x1.png') }

    let(:logger){ Logger.new(IO::NULL) }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:environment) {
      {
        'PROCESS_BUCKET' => 'process-bucket',
        'UNPROCESSABLE_BUCKET' => 'unprocessable-bucket'
      }
    }

    let(:handler) { DataPipeline::Handlers::ConvertFile }
    let(:response) { DataPipeline::Handler.run(handler: handler, event: event, client: client, environment: environment, logger: logger) }

    before do
      client.stub_responses(
        :get_object, ->(context) {
          case context.params[:key]
          when 'npower-eon/export.xls', 'npower-eon/export.XLS'
            { body: npower_xls }
          when 'npower-eon/export.xlsx', 'npower-eon/export.XLSX'
            { body: npower_xlsx }
          when 'sheffield/image.png'
            { body: unknown_file}
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
        expect(request[:params][:key]).to eq('npower-eon/export.xlsx.csv')
        expect(request[:params][:bucket]).to eq('process-bucket')
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
        expect(request[:params][:key]).to eq('npower-eon/export.XLSX.csv')
        expect(request[:params][:bucket]).to eq('process-bucket')
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
        expect(request[:params][:key]).to eq('npower-eon/export.xls.csv')
        expect(request[:params][:bucket]).to eq('process-bucket')
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
        expect(request[:params][:key]).to eq('npower-eon/export.XLS.csv')
        expect(request[:params][:bucket]).to eq('process-bucket')
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
        expect(request[:params][:key]).to eq('sheffield/image.png')
        expect(request[:params][:bucket]).to eq('unprocessable-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end

    end
  end
end