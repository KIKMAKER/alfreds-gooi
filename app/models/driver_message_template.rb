# frozen_string_literal: true

# The message the driver's "Message a Day" tool sends for each client segment.
# Admin-editable on the bulk messages page; falls back to DEFAULTS until saved,
# so the table can be empty and the tool still works.
#
# Segment precedence (a customer has exactly one) is decided in CollectionSegment.
# Supported placeholders: {first_name} (the recipient's first name) and
# {skip_link} (a one-tap skip link — only resolves for the standard segment).
class DriverMessageTemplate < ApplicationRecord
  SEGMENTS = %w[standard new_customer once_off commercial].freeze

  DEFAULTS = {
    "standard" =>
      "Reminder, tomorrow is gooi day! 🌱\n" \
      "Away this week or short on scraps? Tap here to skip and we'll see you next week: {skip_link}",
    "new_customer" =>
      "Welcome to Gooi, {first_name}! 🌱 Tomorrow is your very first collection. " \
      "Just pop your bucket out in the morning and we'll take it from there. " \
      "So glad to have you composting with us!",
    "once_off" =>
      "Hi {first_name}! Your Gooi collection is tomorrow 🌱 Leave your bucket out in the " \
      "morning and we'll do the rest. Thanks for giving us a go!",
    "commercial" =>
      "Hi {first_name}, a reminder that your Gooi collection is scheduled for tomorrow. " \
      "Please have your bins out and accessible for pickup. Thank you!"
  }.freeze

  validates :segment, presence: true, inclusion: { in: SEGMENTS }, uniqueness: true

  # The body to use for a segment: the saved one, or the default if unsaved/blank.
  def self.body_for(segment)
    key = segment.to_s
    bodies_by_segment[key] || DEFAULTS.fetch(key, DEFAULTS.fetch("standard"))
  end

  # { "standard" => body, "new_customer" => body, ... } for all segments, with
  # defaults filled in where nothing is saved.
  def self.bodies_by_segment
    saved = where(segment: SEGMENTS).pluck(:segment, :body).to_h
    SEGMENTS.index_with { |segment| saved[segment].presence || DEFAULTS.fetch(segment) }
  end
end
