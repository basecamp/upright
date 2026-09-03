class Upright::Artifact
  ICONS = {
    "webm" => "video",
    "log"  => "log",
    "json" => "download",
    "html" => "download",
    "xml"  => "download",
    "txt"  => "download",
    "bin"  => "download",
    "zip"  => "download"
  }.freeze

  attr_reader :filename, :content

  def initialize(name:, content:)
    @filename = name
    @content = content
  end

  def extension
    File.extname(filename).delete_prefix(".")
  end

  def basename
    File.basename(filename, ".*")
  end

  def timestamped_filename
    current_site = Upright.current_site
    [ Time.current.to_fs(:number), current_site.code, safe_name ].join("_") + ".#{extension}"
  end

  def content_type
    Marcel::MimeType.for(extension: extension)
  end

  def icon
    ICONS.fetch(extension, "attachment")
  end

  def attach_to(probe_result, timestamped: false)
    probe_result.artifacts.attach(
      io: to_io,
      filename: timestamped ? timestamped_filename : filename,
      content_type: content_type
    )
  end

  private
    def to_io
      case content
      when StringIO, File, IO
        content.tap(&:rewind)
      else
        StringIO.new(content.to_s)
      end
    end

    def safe_name
      basename.parameterize(separator: "_")
    end
end
