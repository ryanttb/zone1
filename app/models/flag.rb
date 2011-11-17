class Flag < ActiveRecord::Base
  validates_presence_of :name, :label
  validates_uniqueness_of :name

  attr_accessible :name, :label

  PRESERVED = ["NOMINATED_FOR_PRESERVATION", "PRESERVED", "SELECTED_FOR_PRESERVATION"]
  # TODO: Maybe come up with a better name for this
  SELECTED = ["SELECTED_FOR_PRESERVATION", "UNIVERSITY_RECORD"]

  def self.all
    # TODO: Add cache expiration
    Rails.cache.fetch("flags") do
      Flag.find(:all)
    end
  end

  def self.label_map
    Flag.all.inject({}) { |h, flag| h[flag.id.to_s] = flag.label; h }
  end

  def self.preserved
    Flag.find_all_by_name(PRESERVED)
  end

  def preserved?
    PRESERVED.include?(self.name)
  end

  def self.selected
    Flag.find_all_by_name(SELECTED)
  end

  def selected?
    SELECTED.include?(self.name)
  end
end
