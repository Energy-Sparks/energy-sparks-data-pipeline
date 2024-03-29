# frozen_string_literal: true

module DataPipeline
  module Handlers
    class HandlerBase
      attr_reader :logger, :client, :environment

      def initialize(client:, logger:, environment: {})
        @client = client
        @environment = environment
        @logger = logger
        Rollbar.configure do |config|
          config.access_token = environment['ROLLBAR_ACCESS_TOKEN']
          config.environment = 'data-pipeline'
        end
      end

      private

      def add_to_bucket(bucket_sym, key:, body: nil, file: nil, content_type: nil)
        bucket = bucket_name(bucket_sym)
        params = { bucket:, key: }

        begin
          if file
            file.body.rewind # ensure stream is rewound before reading again
            params.merge!(body: file.body, content_type: file.content_type)
          elsif body
            params.merge!(body:, content_type:)
          else
            raise ArgumentError.new, 'Either file or body must be provided'
          end
          logger.info("Adding: #{key} to: #{bucket}")
          client.put_object(params.compact)
        rescue StandardError => e
          logger.error("Error adding #{key} to: #{bucket}, error: #{e.message}")
          Rollbar.error(e, bucket:, key:)
        end
      end

      def bucket_name(bucket_sym)
        environment["#{bucket_sym.to_s.upcase}_BUCKET"]
      end

      def respond(status_code, content)
        { statusCode: status_code, body: JSON.generate(content) }
      end
    end
  end
end
