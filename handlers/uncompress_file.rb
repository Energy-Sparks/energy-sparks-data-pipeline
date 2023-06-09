require 'aws-sdk-s3'
require 'zip'

module DataPipeline
  module Handlers
    class UncompressFile < ConversionBase
      def initialize(client:, logger:, environment: {})
        @client = client
        @environment = environment
        @logger = logger
      end

      def process(key:, bucket:)
        file = @client.get_object(bucket: bucket, key: key)
        prefix = key.split('/').first

        upload_responses = []
        begin
          Zip::File.open_buffer(file.body) do |zip_file|
            zip_file.each do |entry|
              content = entry.get_input_stream.read
              @logger.info("Uncompression successs, moving: #{key} to: #{@environment['PROCESS_BUCKET']}")
              upload_responses << move_to_process_bucket("#{prefix}/#{entry.name}", content)
            end
          end
        rescue Zip::Error => e
          @logger.info("Uncompression failed, moving: #{key} to: #{@environment['UNPROCESSABLE_BUCKET']} error: #{e.message}")
          upload_responses << move_to_unprocessable_bucket(key, file)
        end
        { statusCode: 200, body: JSON.generate(responses: upload_responses) }
      end

    end
  end
end
