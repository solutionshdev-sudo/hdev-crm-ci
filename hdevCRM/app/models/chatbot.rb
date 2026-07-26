class Chatbot < ApplicationRecord
  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true
  has_many :chatbot_inboxes, dependent: :destroy_async
  has_many :inboxes, through: :chatbot_inboxes
  has_many :chatbot_sessions, dependent: :destroy_async

  enum :status, { draft: 0, active: 1, inactive: 2 }

  validates :name, presence: true
  validate :flow_structure

  scope :enabled, -> { where(status: :active) }

  def start_node
    (flow['nodes'] || []).find { |node| node['type'] == 'start' }
  end

  def find_node(node_id)
    (flow['nodes'] || []).find { |node| node['id'] == node_id }
  end

  # Aresta saindo de node_id pelo handle dado. Nós com uma única saída não
  # marcam sourceHandle no Vue Flow, então nil casa com qualquer handle.
  def next_node_id(node_id, handle = nil)
    edges = (flow['edges'] || []).select { |edge| edge['source'] == node_id }
    edge = if handle.present?
             edges.find { |item| item['sourceHandle'] == handle }
           else
             edges.first
           end
    edge && edge['target']
  end

  private

  def flow_structure
    return if flow.blank?

    errors_found = Chatbots::FlowValidator.new(flow).errors
    errors_found.each { |message| errors.add(:flow, message) }
  end
end
