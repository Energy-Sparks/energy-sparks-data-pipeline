require 'aws-sdk-s3'
require 'roo'
require 'roo-xls'

module DataPipeline
  module Handlers
    class ConvertFile < HandlerBase

      def process(key:, bucket:)
        file = @client.get_object(bucket: bucket, key: key)

        response = nil
        begin
          tmp = Tempfile.new([key,File.extname(key)])
          tmp.binmode
          tmp.write file[:body].read
          spreadsheet = Roo::Spreadsheet.open(tmp)
          content = spreadsheet.sheet(0).to_csv

          @logger.info("Spreadsheet conversion successs")
          response =  add_to_bucket :process, key: "#{key}.csv", body: content
        rescue StandardError => e
          @logger.info("Spreadsheet conversion failed, error: #{e.message}")
          Rollbar.error(e, bucket: bucket, key: key)

          response = add_to_bucket :unprocessable, key: key, file: file
        end
        respond 200, responses: response
      end
    end
  end
end
