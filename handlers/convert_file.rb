require 'aws-sdk-s3'
require 'roo'
require 'roo-xls'

module DataPipeline
  module Handlers
    class ConvertFile < ConversionBase
      def initialize(client:, logger:, environment: {})
        @client = client
        @environment = environment
        @logger = logger
      end

      def process(key:, bucket:)
        file = @client.get_object(bucket: bucket, key: key)
        prefix = key.split('/').first

        response = nil
        begin
          filename  = File.basename(key,".*")
          extname  = File.extname(key)

          tmp = Tempfile.new([filename,extname])
          tmp.binmode
          tmp.write file[:body].read
          spreadsheet = Roo::Spreadsheet.open(tmp)

          content = spreadsheet.sheet(0).to_csv

          @logger.info("Spreadsheet conversion successs, moving: #{key} to: #{@environment['PROCESS_BUCKET']}")
          response = move_to_process_bucket("#{prefix}/#{filename}#{extname}.csv", content)
        rescue StandardError => e
          @logger.info("Spreadsheet conversion failed, moving: #{key} to: #{@environment['UNPROCESSABLE_BUCKET']} error: #{e.message}")
          response = move_to_unprocessable_bucket(key, file)
        end
        { statusCode: 200, body: JSON.generate(response: response) }
      end
    end
  end
end
