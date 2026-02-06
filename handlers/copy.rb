# frozen_string_literal: true

require 'faraday'

module DataPipeline
  module Handlers
    # simple copy object into process bucket
    class Copy < HandlerBase
      def process(key:, bucket:)
        _, identifier, file = key.split('/', 3)
        if identifier.nil? || file.nil?
          logger.info("Invalid key for #{key}")
          return
        end
        copy("#{bucket}/#{key}", "#{identifier}/#{prefix_timestamp}/#{file}")
      rescue StandardError => e
        logger.error("Unable to copy: #{key}")
        logger.error(e.inspect)
        Rollbar.error(e)
      end

      def copy(from, to)
        @client.copy_object(bucket: bucket_name(:process), copy_source: URI::DEFAULT_PARSER.escape(from), key: to)
        logger.info("Copied to #{copy_key}")
      end
    end
  end
end
