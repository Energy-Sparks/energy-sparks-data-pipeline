# frozen_string_literal: true

module DataPipeline
  module Handlers
    class ProcessFile < HandlerBase
      def process(key:, bucket:)
        file = client.get_object(bucket:, key:)

        next_bucket = next_bucket_finder(key)

        if next_bucket == :amr_data
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
        response = add_to_bucket(next_bucket, key:, body: file_body, content_type: file.content_type)

        respond 200, response:
      end

      private

      def remove_utf8_invalids(line)
        line.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      end

      def remove_utf8_nulls(line)
        line.delete("\u0000")
      end

      def next_bucket_finder(key)
        case key
        when /csv\Z/i, /cns\Z/i then :amr_data
        when /zip\Z/i then :compressed
        when /xlsx?\Z/i then :spreadsheet
        else :unprocessable
        end
      end
    end
  end
end
