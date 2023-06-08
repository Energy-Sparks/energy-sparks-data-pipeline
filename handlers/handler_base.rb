module DataPipeline
  module Handlers
    class HandlerBase
      def initialize(client:, logger:, environment: {})
        @client = client
        @environment = environment
        @logger = logger
        Rollbar.configure do |config|
          config.access_token = @environment["ROLLBAR_ACCESS_TOKEN"]
          config.environment = "data-pipeline"
        end
      end

      def bucket_name(bucket_sym)
        @environment["#{bucket_sym.to_s.upcase}_BUCKET"]
      end

    private

      def add_to_bucket(bucket, key:, body: nil, file: nil, content_type: nil)
        params = { key: key, bucket: bucket_name(bucket) }

        if file
          file.body.rewind # ensure stream is rewound
          params.merge!({ body: file.body, content_type: file.content_type })
        elsif body
          params.merge!({ body: body, content_type: content_type })
        else
          raise ArgumentError.new, "Either file or body must be provided"
        end
        @logger.info("Moving: #{key} to: #{bucket}")
        @client.put_object(params.compact)
      end

      def respond(status_code, content)
        { statusCode: status_code, body: JSON.generate(content) }
      end
    end
  end
end