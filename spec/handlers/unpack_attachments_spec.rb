# frozen_string_literal: true

require 'spec_helper'

require './handler'

describe DataPipeline::Handlers::UnpackAttachments do
  let(:logger) { Logger.new(IO::NULL) }
  let(:client) { Aws::S3::Client.new(stub_responses: true) }
  let(:environment) { { 'PROCESS_BUCKET' => 'test-bucket' } }

  describe '#process' do
    let(:sheffield_email) { File.open('spec/support/emails/sheffield_email.txt') }
    let(:sheffield_email_fwd) { File.open('spec/support/emails/sheffield-fwd.txt') }
    let(:sheffield_email_no_attachment) { File.open('spec/support/emails/sheffield_email_no_attachments.txt') }
    let(:imserv_email_with_link) { File.open('spec/support/emails/imserv_email_with_link.txt') }

    let(:handler) { described_class }
    let(:response) do
      DataPipeline::Handler.run(handler:, event:, client:, environment:, logger:)
    end

    before do
      client.stub_responses(
        :get_object, lambda { |context|
          case context.params[:key]
          when 'sheffield-email.txt'
            { body: sheffield_email }
          when 'sheffield-fwd.txt'
            { body: sheffield_email_fwd }
          when 'sheffield-email-no-attachment.txt'
            { body: sheffield_email_no_attachment }
          when 'imserv_email_with_link.txt'
            { body: imserv_email_with_link }
          else
            'NotFound'
          end
        }
      )
      response
    end

    describe 'when the email has an attachment' do
      let(:event) { DataPipeline::Support::Events.sheffield_email_added }

      it 'puts the attachment file in the PROCESS_BUCKET from the environment using the prefix the email was sent to' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/sheffield-email.txt/4003063_9232_Export_20181108_120524_290.zip')
        expect(request[:params][:bucket]).to eq('test-bucket')
        expect(request[:params][:content_type]).to eq('application/zip')
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end

      it 'returns the code of the files created' do
        body = JSON.parse(response[:body])
        expect(body['responses'].size).to eq(1)
      end
    end

    describe 'when the email has been forwarded' do
      let(:event) { DataPipeline::Support::Events.sheffield_email_forwarded }

      it 'uses the forwarded to header instead of the to field' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:put_object)
        expect(request[:params][:key]).to eq('sheffield/sheffield-fwd.txt/4003063_9232_Export_20190227_120407_366.zip')
      end
    end

    describe 'when the email has no attachments' do
      let(:event) { DataPipeline::Support::Events.sheffield_email_added_no_attachment }

      it 'does not add any files' do
        request = client.api_requests.last
        expect(request[:operation_name]).to eq(:get_object)
      end

      it 'returns a success code' do
        expect(response[:statusCode]).to eq(200)
      end

      it 'returns the code of the files created' do
        body = JSON.parse(response[:body])
        expect(body['responses']).to be_empty
      end
    end
  end

  describe 'when the email has no attachments, but an embedded imserv link' do
    let(:imserv_email_with_link) { File.open('spec/support/emails/imserv_email_with_link.txt') }
    let(:handler) { described_class }
    let(:response) do
      DataPipeline::Handler.run(handler:, event:, client:, environment:, logger:)
    end
    let(:event) { DataPipeline::Support::Events.imserv_email_with_link_added }

    let(:link) { 'https://datavision.imserv.com/imgserver/InternalImage.aspx?cbmsimgid=1111aaaZZZ%3D&mode=View' }
    let(:headers) do
      {
        'content-disposition' => 'inline;filename="WC-EnergySparksLast7Days_161120212207.csv"',
        'content-type' => 'application/vnd.ms-excel'
      }
    end
    let(:body) { 'some,data,here' }
    let(:http_response) { double(success?: true, status: 200, body:, headers:) }

    before do
      allow(Faraday).to receive(:get).with(link).and_return(http_response)
      client.stub_responses(
        :get_object, lambda { |context|
          case context.params[:key]
          when 'imserv_email_with_link.txt'
            { body: imserv_email_with_link }
          else
            'NotFound'
          end
        }
      )
      response
    end

    it 'puts the downloads file in the PROCESS_BUCKET from the environment using the prefix the email was sent to' do
      request = client.api_requests.last
      expect(request[:operation_name]).to eq(:put_object)
      expect(request[:params][:key]).to eq('data/imserv_email_with_link.txt/WC-EnergySparksLast7Days_161120212207.csv')
      expect(request[:params][:bucket]).to eq('test-bucket')
      expect(request[:params][:content_type]).to eq('application/vnd.ms-excel')
    end

    it 'returns a success code' do
      expect(response[:statusCode]).to eq(200)
    end

    it 'returns the code of the files created' do
      body = JSON.parse(response[:body])
      expect(body['responses'].size).to eq(1)
    end
  end

  describe '#extract_download_links' do
    let(:handler) do
      described_class.new(client:, logger:, environment:)
    end

    context 'with an imserv email' do
      let(:email_file)  { File.open('spec/support/emails/imserv_email_with_link.txt') }
      let(:imserv_link) { 'https://datavision.imserv.com/imgserver/InternalImage.aspx?cbmsimgid=1111aaaZZZ%3D&mode=View' }
      let(:mail) { Mail.new(email_file.read) }

      it 'only finds imserv links' do
        expect(handler.extract_download_links(mail)).to contain_exactly(imserv_link)
      end
    end

    context 'with an imserv email that was forwarded' do
      let(:email_file)  { File.open('spec/support/emails/imserv_email_with_link_fwd.txt') }
      let(:imserv_link) { 'https://datavision.imserv.com/imgserver/InternalImage.aspx?cbmsimgid=1111aaaZZZ%3D&mode=View' }
      let(:mail) { Mail.new(email_file.read) }

      it 'only finds imserv links' do
        expect(handler.extract_download_links(mail)).to contain_exactly(imserv_link)
      end
    end

    context 'with other emails' do
      ['sheffield_email_no_attachments.txt', 'sheffield_email.txt', 'sheffield-fwd.txt'].each do |email|
        it "finds no links [#{email}]" do
          mail = Mail.new(File.read("spec/support/emails/#{email}"))
          expect(handler.extract_download_links(mail)).to be_empty
        end
      end
    end
  end

  describe '#download_csv_reports' do
    let(:success)     { true }
    let(:status)      { 200 }
    let(:headers)     do
      {
        'content-disposition' => 'inline;filename="WC-EnergySparksLast7Days_161120212207.csv"',
        'content-type' => 'application/vnd.ms-excel'
      }
    end
    let(:body) { 'some,data,here' }
    let(:response) { double(success?: success, status:, body:, headers:) }

    let(:links) { ['http://example.org/download/1'] }

    let(:handler) do
      described_class.new(client:, logger:, environment:)
    end

    before do
      links.each do |link|
        allow(Faraday).to receive(:get).with(link).and_return(response)
      end
    end

    context 'when download is successful' do
      context 'when content-disposition is available' do
        it 'downloads the file' do
          results = handler.download_csv_reports(links)
          expect_single_excel_file(results, 'WC-EnergySparksLast7Days_161120212207.csv')
        end
      end

      context 'when disposition is not available' do
        let(:headers) do
          {
            'content-type' => 'application/vnd.ms-excel'
          }
        end

        it 'downloads the file and supplies a default filename' do
          results = handler.download_csv_reports(links)
          expect_single_excel_file(results, 'http___example.org_download_1')
        end
      end

      def expect_single_excel_file(results, filename)
        expect(results.length).to be 1
        expect(results[0]).to include(body:, mime_type: headers['content-type'], filename:)
      end
    end

    context 'when download is unsuccessful' do
      # they return a 200 OK for a 404, but its a HTML page with an error message
      let(:success)     { true }
      let(:status)      { 200 }
      let(:body)        { 'Your image cannot be displayed at this time' }
      let(:headers)     do
        {
          'content-type' => 'text/html; charset=utf-8'
        }
      end
      let(:response) { double(success?: success, status:, body:, headers:) }

      it 'returns no data' do
        results = handler.download_csv_reports(links)
        expect(results.length).to be 0
      end

      it 'logs to rollbar' do
        allow(Rollbar).to receive(:error)
        handler.download_csv_reports(links)
        expect(Rollbar).to have_received(:error).with('Unable to download file', link: 'http://example.org/download/1',
                                                                                 prefix: nil)
      end
    end
  end
end
