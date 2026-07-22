# Backs the homepage "Straight from the gooi feed" section (Phase 2 of
# docs/gooi-public-ui-overhaul-brief.md). Static curated set for now, per
# the user's explicit decision — no Instagram API integration yet. The
# partial only ever calls .current_posts, so swapping to a real API call
# later only means changing this one method's body.
#
# PLACEHOLDER_POSTS uses existing app photos until the user provides their
# actual curated folder — swap the list, not the shape, when that lands.
class GooiFeed
  Post = Struct.new(:image, :caption, keyword_init: true)

  PLACEHOLDER_POSTS = [
    Post.new(image: "suburb_launch_hero.jpg", caption: "This week's scraps, ready to gooi."),
    Post.new(image: "kitchen_bucket.jpg", caption: "One bucket, zero landfill."),
    Post.new(image: "suburb_launch_bakkie.jpeg", caption: "The gooi bakkie, out on route."),
    Post.new(image: "gooi_alfred.png", caption: "Alfred, making the rounds."),
    Post.new(image: "bucket2.jpg", caption: "Weekly collection, every time."),
    Post.new(image: "empty_bucket.jpg", caption: "Emptied, rinsed, ready again."),
  ].freeze

  def self.current_posts
    PLACEHOLDER_POSTS
  end
end
