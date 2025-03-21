# frozen_string_literal: true

require 'spec_helper'

require './handler'

describe DataPipeline::Handlers::ProcessFile do
  describe '#process' do
    let(:sheffield_csv)       { File.open('spec/support/files/sheffield_export.csv') }
    let(:cr_csv)              { File.open('spec/support/files/cr.csv') }
    let(:cr_empty_lines_csv)  { File.open('spec/support/files/cr_empty_lines.csv') }
    let(:highlands_csv)       { File.open('spec/support/files/highlands.csv') }
    let(:highlands_invalid_character_csv) do
      File.open('spec/support/files/highlands-invalid-character.csv', 'r:UTF-8')
    end
    let(:sheffield_gas_csv)   { File.open('spec/support/files/sheffield_export.csv') }
    let(:sheffield_zip)       { File.open('spec/support/files/sheffield_export.zip') }
    let(:npower_xls)          { File.open('spec/support/files/npower-eon_export.xls') }
    let(:npower_xlsx)         { File.open('spec/support/files/npower-eon_export.xlsx') }
    let(:unknown_file)        { File.open('spec/support/files/1x1.png') }
    let(:logger) { Logger.new(IO::NULL) }
    let(:client) { Aws::S3::Client.new(stub_responses: true) }
    let(:environment) do
      {
        'AMR_DATA_BUCKET' => 'data-bucket',
        'COMPRESSED_BUCKET' => 'compressed-bucket',
        'UNPROCESSABLE_BUCKET' => 'unprocessable-bucket',
        'SPREADSHEET_BUCKET' => 'spreadsheet-bucket'
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
          when 'sheffield/email-id/export.csv', 'sheffield/email-id/export.CSV', 'sheffield/email-id/export.cns',
               'sheffield/email-id/export.CNS'
            { body: sheffield_csv }
          when 'sheffield/email-id/cr.csv'
            { body: cr_csv }
          when 'cr_empty_lines.csv'
            { body: cr_empty_lines_csv }
          when 'highlands-invalid-character.csv'
            { body: highlands_invalid_character_csv }
          when 'highlands.csv'
            { body: highlands_csv }
          when 'sheffield/email-id/export.zip', 'sheffield/email-id/export.ZIP'
            { body: sheffield_zip }
          when 'sheffield/email-id/image.png'
            { body: unknown_file }
          when 'sheffield-gas/email-id/Sheffield City Council - Energy Sparks (Daily Email)20190303.csv'
            { body: sheffield_gas_csv }
          when 'npower-eon/email-id/export.xls', 'npower-eon/email-id/export.XLS'
            { body: npower_xls }
          when 'npower-eon/email-id/export.xlsx', 'npower-eon/email-id/export.XLSX'
            { body: npower_xlsx }
          else
            'NotFound'
          end
        }
      )
      response
    end

    describe 'when the file is a sheffield gas CSV with spaces in the filename' do
      let(:event) { DataPipeline::Support::Events.csv_sheffield_gas_added }

      it 'puts the attachment file in the AMR_DATA_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to \
          eq('sheffield-gas/email-id/Sheffield City Council - Energy Sparks (Daily Email)20190303.csv')
        expect(request[:params][:bucket]).to eq('data-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is a .CSV' do
      let(:event) { DataPipeline::Support::Events.uppercase_csv_added }

      it 'puts the attachment file in the AMR_DATA_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/email-id/export.CSV')
        expect(request[:params][:bucket]).to eq('data-bucket')
      end
    end

    describe 'when the file is a .cns' do
      let(:event) { DataPipeline::Support::Events.cns_added }

      it 'puts the attachment file in the AMR_DATA_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/email-id/export.cns')
        expect(request[:params][:bucket]).to eq('data-bucket')
      end
    end

    describe 'when the file is a .CNS' do
      let(:event) { DataPipeline::Support::Events.uppercase_cns_added }

      it 'puts the attachment file in the AMR_DATA_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/email-id/export.CNS')
        expect(request[:params][:bucket]).to eq('data-bucket')
      end
    end

    describe 'when the file is a .csv file' do
      let(:event) { DataPipeline::Support::Events.csv_added }

      it 'puts the attachment file in the AMR_DATA_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/email-id/export.csv')
        expect(request[:params][:bucket]).to eq('data-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end

      context 'when the file has mixed line endings' do
        let(:event) { DataPipeline::Support::Events.cr_csv_added }

        it 'normalises them' do
          request = client.api_requests.last
          expect(request[:params][:body].readlines.all? { |line| line.match?(/[^\r]\n\Z/) }).to be(true)
        end
      end

      context 'when the file has empty lines' do
        let(:event) { DataPipeline::Support::Events.cr_empty_lines_csv_added }

        it 'removes them' do
          request = client.api_requests.last
          expect(request[:params][:body].readlines.any? { |line| line.match?(/^$/) }).to be(false)
        end
      end

      context 'when the file has nulls and empty lines' do
        let(:event) { DataPipeline::Support::Events.highlands_csv_added }

        it 'removes them' do
          request = client.api_requests.last
          expect(request[:params][:body].readlines.any? { |line| line.match?(/\u0000/) }).to be(false)
          request[:params][:body].rewind
          expect(request[:params][:body].readlines.any? { |line| line.match?(/^$/) }).to be(false)
        end
      end

      context 'when the file has nulls and empty lines and invalid characters' do
        let(:event) { DataPipeline::Support::Events.highlands_invalid_character_csv_added }

        it 'removes them' do
          request = client.api_requests.last
          expect(request[:params][:body].readlines.any? { |line| line.match?(/\u0000/) }).to be(false)
          request[:params][:body].rewind
          expect(request[:params][:body].readlines.any? { |line| line.match?(/^$/) }).to be(false)
        end
      end
    end

    describe 'when the file is a .ZIP' do
      let(:event) { DataPipeline::Support::Events.uppercase_zip_added }

      it 'puts the attachment file in the COMPRESSED_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/email-id/export.ZIP')
        expect(request[:params][:bucket]).to eq('compressed-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is a .zip' do
      let(:event) { DataPipeline::Support::Events.zip_added }

      it 'puts the attachment file in the COMPRESSED_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/email-id/export.zip')
        expect(request[:params][:bucket]).to eq('compressed-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is an .xls' do
      let(:event) { DataPipeline::Support::Events.xls_added }

      it 'puts the attachment file in the SPREADSHEET_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('npower-eon/email-id/export.xls')
        expect(request[:params][:bucket]).to eq('spreadsheet-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is an .XLS' do
      let(:event) { DataPipeline::Support::Events.uppercase_xls_added }

      it 'puts the attachment file in the SPREADSHEET_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('npower-eon/email-id/export.XLS')
        expect(request[:params][:bucket]).to eq('spreadsheet-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is an .xlsx' do
      let(:event) { DataPipeline::Support::Events.xlsx_added }

      it 'puts the attachment file in the SPREADSHEET_BUCKET from the environment using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('npower-eon/email-id/export.xlsx')
        expect(request[:params][:bucket]).to eq('spreadsheet-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is an .XLSX' do
      let(:event) { DataPipeline::Support::Events.uppercase_xlsx_added }

      it 'puts the attachment file in the SPREADSHEET_BUCKET using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('npower-eon/email-id/export.XLSX')
        expect(request[:params][:bucket]).to eq('spreadsheet-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end

    describe 'when the file is an image' do
      let(:event) { DataPipeline::Support::Events.image_added }

      it 'puts the attachment file in the UNPROCESSABLE_BUCKET using the key of the object added' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/email-id/image.png')
        expect(request[:params][:bucket]).to eq('unprocessable-bucket')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end
    end
  end
end
