# frozen_string_literal: true

require 'mail'
require 'faraday'

module DataPipeline
  module Handlers
    class UnpackAttachments < HandlerBase
      IMSERV_LINK_REGEX = %r{(https://datavision.imserv.com/imgserver/InternalImage.aspx\?[a-zA-Z0-9&%=]+)}

      def process(key:, bucket:)
        email_file = @client.get_object(bucket:, key:)
        email = Mail.new(email_file.body.read)

        sent_to = email.header['X-Forwarded-To'] || email.to.first
        logger.info("Receipt address: #{sent_to}")

        prefix = "#{sent_to.to_s.split('@').first}/#{key}"
        logger.info("Prefix: #{prefix}")

        responses = if email.attachments.any?
                      store_attachments(prefix, email)
                    else
                      store_downloads(prefix, email)
                    end
        respond 200, responses:
      end

      def store_attachments(prefix, email)
        email.attachments.map do |attachment|
          add_to_bucket(:process,
                        key: "#{prefix}/#{attachment.filename}",
                        content_type: attachment.mime_type,
                        body: attachment.decoded)
        end
      end

      def store_downloads(prefix, email)
        logger.info('Extracting download links')
        links = extract_download_links(email, prefix)
        results = download_csv_reports(links, prefix)
        results.map do |download|
          add_to_bucket(:process,
                        key: "#{prefix}/#{download[:filename]}",
                        content_type: download[:mime_type],
                        body: download[:body])
        end
      end

      def extract_download_links(mail, prefix = nil)
        to_match = if mail.parts.any?
                     mail.parts.first.decoded
                   else
                     mail.decoded
                   end
        to_match.scan(IMSERV_LINK_REGEX).flatten
      rescue StandardError => e
        logger.error("Unable to process mail body: #{mail.subject}, #{e.message}")
        logger.error(e.backtrace)
        Rollbar.error(e, subject: mail.subject, prefix:)
        []
      end

      def download_csv_reports(links, prefix = nil)
        results = []
        links.each do |link|
          logger.info("Downloading: #{link}")
          resp = Faraday.get(link)
          if download_error?(resp)
            logger.error("Unable to download file #{link}")
            Rollbar.error('Unable to download file', link:, prefix:)
          else
            results << { filename: filename(resp, link), body: resp.body,
                         mime_type: resp.headers['content-type'] }
          end
        rescue StandardError => e
          logger.error("Unable to download file #{link}, #{e.message}")
          logger.error(e.backtrace)
          Rollbar.error(e, link:, prefix:)
        end
        results
      end

      private

      def download_error?(resp)
        # they only use 200 errors, but check anyway status anyway
        # not found errors are returned with an error message and an HTML content type
        # check for both in case either change
        !resp.success? || resp.headers['content-type']&.include?('text/html') ||
          resp.body.match('Your image cannot be displayed at this time')
      end

      def filename(resp, link)
        if resp.headers['content-disposition']&.match(/filename=("?)(.+)\1/)
          resp.headers['content-disposition'].match(/filename=("?)(.+)\1/)[2]
        else
          link.gsub(%r{(:|/|\?)}, '_')
        end
      end
    end
  end
end
