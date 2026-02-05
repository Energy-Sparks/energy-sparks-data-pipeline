# frozen_string_literal: true

require 'faraday'

module DataPipeline
  module Handlers
    # simple copy object into process bucket
    class Copy < HandlerBase
      def process(key:, bucket:)
        _, identifier, file = key.split('/', 3)
        response = @client.copy_object(bucket: bucket_name(:process),
                                       copy_source: URI::DEFAULT_PARSER.escape("#{bucket}/#{key}"),
                                       key: "#{identifier}/#{prefix_timestamp}/#{file}")
        respond 200, response
      end
    end
  end
end
