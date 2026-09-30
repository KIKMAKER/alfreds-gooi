xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset "xmlns" => "http://www.sitemaps.org/schemas/sitemap/0.9" do
  static_pages = [
    { loc: root_url,                    changefreq: "weekly",  priority: 1.0 },
    { loc: about_url,                   changefreq: "monthly", priority: 0.8 },
    { loc: story_url,                   changefreq: "monthly", priority: 0.8 },
    { loc: faq_url,                     changefreq: "monthly", priority: 0.8 },
    { loc: posts_url,                   changefreq: "weekly",  priority: 0.7 },
  ]

  static_pages.each do |page|
    xml.url do
      xml.loc page[:loc]
      xml.changefreq page[:changefreq]
      xml.priority page[:priority]
    end
  end

  @posts.each do |post|
    xml.url do
      xml.loc post_url(post)
      xml.lastmod post.updated_at.iso8601
      xml.changefreq "monthly"
      xml.priority 0.6
    end
  end
end
