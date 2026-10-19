require "zip"

# Fills Gooi's facility confirmation letter template (a .docx) with one site's
# details, so the manager only has to sign it.
#
# The template (lib/documents/gooi-facility-confirmation-letter.docx) holds
# {{tokens}}. Word often splits a typed token across several text runs
# ("{{max_", "kg}}") when it is edited or autocorrected, so tokens are matched on
# each paragraph's joined text and written back across the original runs, which
# keeps the surrounding formatting.
class FacilityLetterDocument
  TEMPLATE = Rails.root.join("lib/documents/gooi-facility-confirmation-letter.docx")
  TOKEN = /\{\{\s*(\w+)\s*\}\}/
  WORD_NS = { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }.freeze
  PARTS = %r{\Aword/(document|header\d*|footer\d*)\.xml\z}

  class IncompleteDetails < StandardError; end
  class UnknownToken < StandardError; end

  def initialize(site, template: TEMPLATE, on: Date.current)
    @site = site
    @template = template
    @on = on
  end

  def filename
    "Gooi facility confirmation letter - #{@site.name}.docx"
  end

  def to_docx
    raise IncompleteDetails, @site.missing_compliance_fields.to_sentence unless @site.compliance_details_complete?

    buffer = Zip::OutputStream.write_buffer do |out|
      Zip::File.open(@template.to_s) do |zip|
        zip.each do |entry|
          next if entry.directory?

          content = entry.get_input_stream.read
          content = fill(content) if entry.name.match?(PARTS)
          out.put_next_entry(entry.name)
          out.write(content)
        end
      end
    end
    buffer.string
  end

  # Every value a template may use. Anything else is an error rather than a
  # visible {{typo}} in a letter sent to a facility.
  def values
    {
      "legal_name"                => @site.legal_name,
      "facility_name_and_address" => facility_name_and_address,
      "max_kg_per_delivery"       => kg(@site.max_kg_per_delivery),
      "deliveries_per_week_phrase" => deliveries_phrase(@site.max_deliveries_per_week),
      "max_deliveries_per_week"   => @site.max_deliveries_per_week.to_s,
      "signatory_name"            => @site.signatory_name,
      "signatory_title"           => @site.signatory_title,
      "date"                      => @on.strftime("%-d %B %Y")
    }
  end

  private

  def fill(xml)
    doc = Nokogiri::XML(xml)
    doc.xpath("//w:p", WORD_NS).each { |paragraph| fill_paragraph(paragraph) }
    doc.to_xml
  end

  def fill_paragraph(paragraph)
    nodes = paragraph.xpath(".//w:t", WORD_NS).to_a
    texts = nodes.map(&:content)
    full = texts.join
    return unless full.match?(TOKEN)

    starts = texts.each_with_index.map { |_, i| texts[0...i].sum(&:length) }

    # Right to left, so earlier offsets stay valid while later text changes.
    full.to_enum(:scan, TOKEN).map { Regexp.last_match }.reverse_each do |match|
      name = match[1]
      value = values.fetch(name) { raise UnknownToken, "Unknown token {{#{name}}} in the letter template" }
      replace_range(texts, starts, match.begin(0), match.end(0), value.to_s)
    end

    nodes.each_with_index do |node, i|
      node.content = texts[i]
      node["xml:space"] = "preserve"
    end
  end

  # Puts `value` where the token began and blanks the rest of the token, which
  # may run on into later nodes.
  def replace_range(texts, starts, from, to, value)
    first = starts.rindex { |s| s <= from }
    last = starts.rindex { |s| s < to }

    (first..last).each do |i|
      lo = [from - starts[i], 0].max
      hi = [to - starts[i], texts[i].length].min
      insert = i == first ? value : ""
      texts[i] = texts[i][0...lo] + insert + texts[i][hi..]
    end
  end

  def facility_name_and_address
    parts = [@site.name, @site.street_address]
    suburb = @site.suburb&.name
    parts << suburb if suburb.present? && !@site.street_address.to_s.downcase.include?(suburb.downcase)
    parts.compact_blank.join(", ")
  end

  def kg(value)
    value.to_d.to_s("F").sub(/\.0+\z/, "")
  end

  def deliveries_phrase(count)
    case count
    when 1 then "once a week"
    when 2 then "twice a week"
    else "#{count} times a week"
    end
  end
end
