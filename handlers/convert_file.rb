require 'aws-sdk-s3'
require 'roo'
require 'roo-xls'

module DataPipeline
  module Handlers
    class ConvertFile
      def initialize(client:, logger:, environment: {})
        @client = client
        @environment = environment
        @logger = logger
      end

      def process(key:, bucket:)
        file = @client.get_object(bucket: bucket, key: key)
        prefix = key.split('/').first

        response = begin
          spreadsheet = Roo::Spreadsheet.open(file)
          content = spreadsheet.sheet(0).to_csv
          move_to_process_bucket("#{prefix}/#{file.name}", content)
        rescue Roo::Error => e
          move_to_unprocessable_bucket(key, file)
        end
        { statusCode: 200, body: JSON.generate(response: response) }
      end

    private

      def move_to_process_bucket(key, content)
        @client.put_object(
          bucket: @environment['AMR_DATA_BUCKET'],
          key: key,
          body: content,
        )
      end

      def move_to_unprocessable_bucket(key, file)
        @client.put_object(
          bucket: @environment['UNPROCESSABLE_BUCKET'],
          key: key,
          body: file.body,
          content_type: file.content_type
        )
      end
    end
  end
end
