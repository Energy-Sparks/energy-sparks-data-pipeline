require 'zip'

module DataPipeline
  module Handlers
    class UncompressFile < HandlerBase
      def process(key:, bucket:)
        file = client.get_object(bucket: bucket, key: key)
        prefix = key.split('/').first

        responses = []
        begin
          Zip::File.open_buffer(file.body) do |zip_file|
            zip_file.each do |entry|
              content = entry.get_input_stream.read
              logger.info("Uncompression successs")
              responses << add_to_bucket(:process, key: "#{prefix}/#{entry.name}", body: content)
            end
          end
        rescue Zip::Error => e
          logger.info("Uncompression failed, error: #{e.message}")
          Rollbar.error(e, bucket: bucket, key: key)

          responses << add_to_bucket(:unprocessable, key: key, file: file)
        end
        respond 200, responses: responses
      end
    end
  end
end
