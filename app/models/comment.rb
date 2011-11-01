class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :stored_file

  validates_presence_of :user_id
  validates_presence_of :stored_file_id
  validates_presence_of :content

  attr_accessible :content, :user_id, :stored_file_id,
    :created_at, :updated_at
end