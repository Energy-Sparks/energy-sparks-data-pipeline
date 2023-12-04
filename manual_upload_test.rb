# frozen_string_literal: true

require 'aws-sdk-s3'
require 'mail'
require 'zip'

attachment_path = 'spec/support/files/npower-eon_export.xls'
attachment_name = "#{Time.now.strftime('test-%Y%m%d-%H%M%S')}.xls"

buffer = Zip::OutputStream.write_buffer do |zio|
  zio.put_next_entry(attachment_name)
  zio.write(File.read(attachment_path))
end

mail = Mail.new({ from: 'test@example.com', to: 'test@example.com', subject: 'Test Email with Attachment',
                  body: 'This is the body of the email.' })
mail.add_file(filename: "#{File.basename(attachment_name)}.zip", content: buffer.string)

s3 = Aws::S3::Client.new
s3.put_object(
  bucket: 'es-development-data-inbox',
  key: File.basename(attachment_name),
  body: mail.to_s
)
puts "uploaded #{attachment_name}"
