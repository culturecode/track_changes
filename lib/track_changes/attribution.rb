module TrackChanges
  mattr_accessor :default_attribution

  # Set the source used for implict changes_by attribution
  # for the duration of the block
  def self.with_changes_attributed_to(new_source, &block)
    old_source = self.default_attribution
    self.default_attribution = new_source
    block.call
  ensure
    self.default_attribution = old_source
  end
end
