SitemapGenerator::Sitemap.default_host = "https://www.gooi.me"
SitemapGenerator::Sitemap.create do
  add "/",       changefreq: "weekly",  priority: 1.0
  add "/about",  changefreq: "monthly", priority: 0.8
  add "/story",  changefreq: "monthly", priority: 0.8
  add "/faq",    changefreq: "monthly", priority: 0.8
  add "/blog",   changefreq: "weekly",  priority: 0.7

  Post.published.each do |post|
    add post_path(post), lastmod: post.updated_at, changefreq: "monthly", priority: 0.6
  end

end
