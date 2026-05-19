module ApplicationHelper
  # Custom renderer maps markdown elements to Gooi blog visual components.
  # Convention:
  #   ## Heading     → section heading with yellow dot
  #   > blockquote   → large styled pullquote
  #   ![caption](url)→ full-width figure with caption
  class GooiBlogRenderer < Redcarpet::Render::HTML
    def header(text, level)
      if level == 2
        %(<h2 class="blog-section-heading">#{text}<span class="yellow-txt">.</span></h2>\n)
      else
        %(<h#{level}>#{text}</h#{level}>\n)
      end
    end

    def block_quote(quote)
      %(<blockquote class="blog-pullquote">#{quote}</blockquote>\n)
    end

    def image(link, title, alt)
      caption = title.presence || alt.presence
      html  = %(<figure class="blog-figure">)
      html += %(<img src="#{link}" alt="#{alt}" class="blog-figure__img" loading="lazy">)
      html += %(<figcaption class="blog-figure__caption">#{caption}</figcaption>) if caption
      html += %(</figure>)
      html
    end

    # Prevent Redcarpet wrapping <figure> in a spurious <p>
    def paragraph(text)
      text.lstrip.start_with?("<figure") ? "#{text}\n" : "<p>#{text}</p>\n"
    end
  end

  def markdown(text)
    renderer = GooiBlogRenderer.new(safe_links_only: true)
    Redcarpet::Markdown.new(renderer, autolink: true, no_intra_emphasis: true, tables: true).render(text).html_safe
  end

  def render_navbar
    if user_signed_in?
      if current_user.driver? || current_user.admin?
        render "shared/driver_navbar"
      else
        render "shared/new_navbar"
      end
    end
    render "shared/new_navbar"
  end

  def breadcrumb_schema(items)
    breadcrumb_list = {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items.map.with_index do |item, index|
        {
          "@type": "ListItem",
          "position": index + 1,
          "name": item[:name],
          "item": item[:url]
        }
      end
    }

    content_for :structured_data do
      content_tag :script, breadcrumb_list.to_json.html_safe, type: "application/ld+json"
    end
  end

  def render_breadcrumbs(items)
    content_tag :nav, class: "breadcrumb-nav", "aria-label": "breadcrumb" do
      content_tag :ol, class: "breadcrumb" do
        items.map.with_index do |item, index|
          is_last = index == items.length - 1
          content_tag :li, class: "breadcrumb-item #{'active' if is_last}", "aria-current": (is_last ? "page" : nil) do
            if is_last
              item[:name]
            else
              link_to item[:name], item[:url]
            end
          end
        end.join.html_safe
      end
    end
  end
end
