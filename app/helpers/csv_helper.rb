module CSVHelper
  # Formats paragraph style textual data in CSV to play nice with Excel.
  def format_csv_para_text(text)
    return text unless text.is_a?(String) && !text.blank?

    # We convert to Markdown since there is a gem to do it and it's much more
    # readable. Conversion also strips unknown tags.
    text = ReverseMarkdown.convert(text, unknown_tags: :drop)

    # Excel seems to like \r\n, so replace all plain \ns with \r\n in all string-type cells.
    # Also ReverseMarkdown adds extra whitespace -- trim it.
    text = text.split(/\r?\n/).map(&:strip).join("\r\n")

    # Also remove html entities.
    text.gsub(/&(?:[a-z\d]+|#\d+|#x[a-f\d]+);/i, "")
  end
end
