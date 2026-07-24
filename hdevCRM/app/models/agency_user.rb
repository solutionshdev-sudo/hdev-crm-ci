# == Schema Information
#
# Table name: agency_users
#
#  id         :bigint           not null, primary key
#  role       :integer          default("administrator"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  agency_id  :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_agency_users_on_agency_id              (agency_id)
#  index_agency_users_on_agency_id_and_user_id  (agency_id,user_id) UNIQUE
#  index_agency_users_on_user_id                (user_id)
#
class AgencyUser < ApplicationRecord
  belongs_to :agency
  belongs_to :user

  enum :role, { administrator: 0 }

  validates :user_id, uniqueness: { scope: :agency_id }
end
