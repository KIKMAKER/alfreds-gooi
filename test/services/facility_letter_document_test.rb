# frozen_string_literal: true
require "test_helper"
require "tmpdir"

class FacilityLetterDocumentTest < ActiveSupport::TestCase
  setup do
    @site = DropOffSite.create!(
      name: "Neighbourhood Farm", street_address: "1 Farm Rd, Observatory", suburb: suburb_fixture("Observatory"),
      collection_day: "Thursday", legal_name: "Neighbourhood Farm NPC",
      signatory_name: "Thandi Manager", signatory_title: "Farm Manager",
      max_kg_per_delivery: 125, max_deliveries_per_week: 2
    )
  end

  def text_of(docx)
    xml = Zip::File.open_buffer(StringIO.new(docx)).read("word/document.xml")
    Nokogiri::XML(xml).xpath("//w:p", FacilityLetterDocument::WORD_NS).map { |p| p.xpath(".//w:t", FacilityLetterDocument::WORD_NS).map(&:content).join }
  end

  # Builds a minimal .docx whose body is the given raw <w:p> XML.
  def build_template(paragraphs_xml)
    path = File.join(Dir.mktmpdir, "t.docx")
    Zip::OutputStream.open(path) do |z|
      z.put_next_entry("[Content_Types].xml")
      z.write('<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>')
      z.put_next_entry("word/document.xml")
      z.write('<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' \
              "#{paragraphs_xml}</w:body></w:document>")
    end
    Pathname.new(path)
  end

  test "the shipped template fills completely with no token left behind" do
    lines = text_of(FacilityLetterDocument.new(@site, on: Date.new(2026, 11, 3)).to_docx)
    joined = lines.join("\n")

    assert_no_match(/\{\{|\}\}/, joined)
    assert_includes joined, "Date: 3 November 2026"
    assert_includes joined, "We, Neighbourhood Farm NPC, confirm"
    assert_includes joined, "Our facility, Neighbourhood Farm, 1 Farm Rd, Observatory, accepts"
    assert_includes joined, "up to twice a week, with volumes of up to 125 kg per delivery"
    assert_includes joined, "Name: Thandi Manager"
    assert_includes joined, "Designation: Farm Manager"
    assert_includes joined, "Organisation: Neighbourhood Farm NPC"
  end

  test "the suburb is added to the address only when the street address lacks it" do
    @site.update!(street_address: "1 Farm Rd")
    assert_match "Neighbourhood Farm, 1 Farm Rd, Observatory, accepts", text_of(FacilityLetterDocument.new(@site).to_docx).join
  end

  test "a token Word has split across runs is still replaced, keeping formatting" do
    template = build_template(
      '<w:p><w:r><w:t>Hi {{leg</w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>al_na</w:t></w:r><w:r><w:t>me}}, bye</w:t></w:r></w:p>'
    )
    docx = FacilityLetterDocument.new(@site, template: template).to_docx

    assert_equal ["Hi Neighbourhood Farm NPC, bye"], text_of(docx)
    assert_match "<w:b/>", Zip::File.open_buffer(StringIO.new(docx)).read("word/document.xml")
  end

  test "several tokens in one paragraph, including repeats, all resolve" do
    template = build_template('<w:p><w:r><w:t>{{legal_name}} / {{signatory_name}} / {{legal_name}}</w:t></w:r></w:p>')

    assert_equal ["Neighbourhood Farm NPC / Thandi Manager / Neighbourhood Farm NPC"],
                 text_of(FacilityLetterDocument.new(@site, template: template).to_docx)
  end

  test "an unknown token is an error, not a visible typo in a letter" do
    template = build_template('<w:p><w:r><w:t>{{legal_nmae}}</w:t></w:r></w:p>')

    assert_raises(FacilityLetterDocument::UnknownToken) { FacilityLetterDocument.new(@site, template: template).to_docx }
  end

  test "incomplete details are refused" do
    @site.update!(legal_name: nil)

    error = assert_raises(FacilityLetterDocument::IncompleteDetails) { FacilityLetterDocument.new(@site).to_docx }
    assert_match "Registered name", error.message
  end

  test "delivery phrasing and decimal kg read naturally" do
    @site.update!(max_deliveries_per_week: 1, max_kg_per_delivery: 12.5)
    assert_match "up to once a week, with volumes of up to 12.5 kg", text_of(FacilityLetterDocument.new(@site).to_docx).join

    @site.update!(max_deliveries_per_week: 3)
    assert_match "up to 3 times a week", text_of(FacilityLetterDocument.new(@site).to_docx).join
  end
end
