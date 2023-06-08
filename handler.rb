require './handlers/handler_base'
require './handlers/process_file'
require './handlers/uncompress_file'
require './handlers/unpack_attachments'
require './handlers/convert_file'

module DataPipeline
  class Handler
    def self.run(handler:, event:, context: {}, client: Aws::S3::Client.new, logger: Logger.new(STDOUT), environment: ENV)
      s3_record = event['Records'].first['s3']
      file_key = CGI::unescape s3_record['object']['key']
      bucket_name = s3_record['bucket']['name']

      handler.new(client: client, logger: logger, environment: environment).process(key: file_key, bucket: bucket_name)
    end

    def self.process_file(event:, context:)
      run(handler: DataPipeline::Handlers::ProcessFile, event: event, context: context)
    end

    def self.uncompress_file(event:, context:)
      run(handler: DataPipeline::Handlers::UncompressFile, event: event, context: context)
    end

    def self.unpack_attachments(event:, context:)
      run(handler: DataPipeline::Handlers::UnpackAttachments, event: event, context: context)
    end

    def self.convert_file(event:, context:)
      run(handler: DataPipeline::Handlers::ConvertFile, event: event, context: context)
    end
  end
end
