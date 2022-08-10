require 'aws-sdk-s3'

module DataPipeline
  module Handlers
    class ProcessFile
      def initialize(client:, logger:, environment: {})
        @client = client
        @environment = environment
        @logger = logger
      end

      def process(key:, bucket:)
        file = @client.get_object(bucket: bucket, key: key)

        next_bucket = next_bucket_finder(key)

        if next_bucket == @environment['AMR_DATA_BUCKET']
          file_body = StringIO.new

          file.body.each_line do |line|
            line = remove_utf8_invalids(line)
            line = remove_utf8_nulls(line)
            next if line.strip.empty?

            file_body.puts line.encode('UTF-8', universal_newline: true)
          end
          file_body.rewind
        else
          file_body = file.body
        end

        response = @client.put_object(
          bucket: next_bucket,
          key: key,
          content_type: file.content_type,
          body: file_body
        )

        @logger.info("Moved: #{key} to: #{next_bucket}")

        { statusCode: 200, body: JSON.generate(response: response) }
      end

      def remove_utf8_invalids(line)
        line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      end

      def remove_utf8_nulls(line)
        line.delete("\u0000")
      end

      def next_bucket_finder(key)
        case key
        when /csv\Z/ then @environment['AMR_DATA_BUCKET']
        when /zip\Z/ then @environment['COMPRESSED_BUCKET']
        else @environment['UNPROCESSABLE_BUCKET']
        end
      end
    end
  end
end
