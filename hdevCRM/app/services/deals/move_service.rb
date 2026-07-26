# Moves a deal to a stage/position on the board. Position is the midpoint of
# the two neighbours (one-row UPDATE); when the gap collapses below EPSILON the
# whole stage is renormalized inline (rare: needs ~33 reinsertions in the same
# gap with scale 10).
class Deals::MoveService
  EPSILON = 1e-6
  STEP = 1024.0

  pattr_initialize [:deal!, :stage!, :before_deal_id, :after_deal_id]

  def perform
    position = compute_position
    renormalize_stage! if position.nil?
    deal.update!(deal_stage_id: stage.id, position: position || compute_position || next_top_position)
    deal
  end

  private

  def siblings
    stage.deals.where.not(id: deal.id).order(:position)
  end

  def compute_position
    before_pos = position_of(before_deal_id)
    after_pos = position_of(after_deal_id)

    return next_top_position if before_pos.nil? && after_pos.nil?
    return after_pos - STEP if before_pos.nil?
    return before_pos + STEP if after_pos.nil?
    return nil if (after_pos - before_pos).abs < EPSILON

    (before_pos + after_pos) / 2
  end

  def position_of(id)
    return if id.blank?

    siblings.find_by(id: id)&.position&.to_f
  end

  def next_top_position
    (siblings.minimum(:position).to_f - STEP)
  end

  def renormalize_stage!
    stage.deals.order(:position).each_with_index do |sibling, index|
      # rubocop:disable Rails/SkipsModelValidations
      sibling.update_column(:position, (index + 1) * STEP)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end
end
