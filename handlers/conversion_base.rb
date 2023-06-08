module DataPipeline
  module Handlers
    class ConversionBase

    private

      def move_to_process_bucket(key, content)
        @client.put_object(
          bucket: @environment['PROCESS_BUCKET'],
          key: key,
          body: content
        )
      end

      def move_to_unprocessable_bucket(key, file)
        @client.put_object(
          bucket: @environment['UNPROCESSABLE_BUCKET'],
          key: key,
          body: file.body
        )
      end
    end
  end
end