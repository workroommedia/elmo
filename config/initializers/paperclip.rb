# frozen_string_literal: true

upload_path = "uploads/:class/:attachment/:id_partition/:style/:filename"

# We always do local storage in testing for speed and so that we don't rely on external services.
if !Rails.env.test? && Settings.key?(:paperclip) && Settings.paperclip.storage == "cloud"
  raise "AWS must be provided if storage set to 'cloud'" unless Settings.key?(:aws)

  Paperclip::Attachment.default_options.merge!(
    path: upload_path,
    storage: "fog",
    fog_credentials: {
      provider: "AWS",
      aws_access_key_id: Settings.aws.access_key_id,
      aws_secret_access_key: Settings.aws.secret_access_key,
      region: Settings.aws.region,
      scheme: "https"
    },
    fog_directory: Settings.aws.bucket,
    fog_options: {multipart_chunk_size: 10.megabytes},
    fog_host: nil,
    fog_public: false
  )
else
  Paperclip::Attachment.default_options[:path] = ":rails_root/#{upload_path}"
end

Paperclip.options[:content_type_mappings] = {
  wmv: "application/vnd.ms-asf",
  opus: "audio/x-opus+ogg"
}

module Paperclip
  # Paperclip's spoof detection currently, as a result of idiosyncracies with the `file` command,
  # reports false positives for a variety of different media types and must be disabled.
  # TODO: Find a better workaround, or wait for paperclip to update
  class MediaTypeSpoofDetector
    def spoofed?
      false
    end
  end

  # Returns the id of the instance in a split path form. e.g. returns
  # 000/001/234 for an id of 1234.
  module Interpolations
    def id_partition(attachment, _style_name)
      case id = attachment.instance.id
      when Integer
        format("%09d", id).scan(/\d{3}/).join("/")
      when String
        id.split("-").join("/")
      end
    end
  end
end
