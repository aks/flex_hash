# frozen_string_literal: true

# This module defines some methods that enable object tracking and recognition
# needed to avoid infinite recursions when there are nested circular dependencies.
#
# "How do you create a circular dependency?" you may ask.
#
# Here's how:
#
# a = {}
# b = { a: a }
# a = { b: b }
#
# While this is a reduced, absurd example, there are sometimes valid reasons to have
# nested references to parent objects, which leads to the _possibility_ of infinite
# recursions while doing a "deep" operation on a FlexHash or FlexArray.
module SeenMixin
  def seen?
    @seen ||= {}
    @seen.key?(object_id)
  end

  def seen!
    @seen ||= {}
    @seen.store(object_id, true)
    self
  end

  def reset_seen(depth)
    @seen = nil if depth.zero?
  end
end
