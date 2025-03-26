# frozen_string_literal: true

require 'zip'

module DataPipeline
  module Handlers
    class UncompressFile < HandlerBase
      def process(key:, bucket:)
        file = client.get_object(bucket:, key:)
        prefix = key.rpartition('/').first

        responses = []
        begin
          Zip::File.open_buffer(file.body) do |zip_file|
            zip_file.each do |entry|
              content = entry.get_input_stream.read
              logger.info('Uncompression successs')
              responses << add_to_bucket(:process, key: "#{prefix}/#{entry.name}", body: content)
            end
          end
        rescue Zip::Error => e
          logger.error("Uncompression failed, error: #{e.message}")
          Rollbar.error(e, bucket:, key:)

          responses << add_to_bucket(:unprocessable, key:, file:)
        end
        respond 200, responses:
      end
    end
  end
end
