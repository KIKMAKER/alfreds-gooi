module ApplicationHelper
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
