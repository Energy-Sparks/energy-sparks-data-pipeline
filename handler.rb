# frozen_string_literal: true

require 'bundler'
Bundler.setup(:default)

require './handlers/handler_base'
require './handlers/process_file'
require './handlers/uncompress_file'
require './handlers/unpack_attachments'
require './handlers/convert_file'
require 'aws-sdk-s3'
require 'rollbar'

module DataPipeline
  class Handler
    def self.run(handler:, event:, context: {}, client: Aws::S3::Client.new, logger: Logger.new($stdout),
                 environment: ENV)
      s3_record = event['Records'].first['s3']
      file_key = CGI.unescape s3_record['object']['key']
      bucket_name = s3_record['bucket']['name']

      logger.info("Running handler: #{handler.name} with file: #{file_key} from bucket: #{bucket_name}")
      logger.debug("Event: #{event}")
      logger.debug("Context: #{context}")

      handler.new(client:, logger:, environment:).process(key: file_key, bucket: bucket_name)
    end

    def self.process_file(event:, context:)
      run(handler: DataPipeline::Handlers::ProcessFile, event:, context:)
    end

    def self.uncompress_file(event:, context:)
      run(handler: DataPipeline::Handlers::UncompressFile, event:, context:)
    end

    def self.unpack_attachments(event:, context:)
      run(handler: DataPipeline::Handlers::UnpackAttachments, event:, context:)
    end

    def self.convert_file(event:, context:)
      run(handler: DataPipeline::Handlers::ConvertFile, event:, context:)
    end
  end
end
