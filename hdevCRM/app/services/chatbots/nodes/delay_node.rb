class Chatbots::Nodes::DelayNode < Chatbots::Nodes::BaseNode
  MAX_SECONDS = 24.hours.to_i

  def execute
    seconds = [[data['seconds'].to_i, 1].max, MAX_SECONDS].min
    Chatbots::ResumeJob.set(wait: seconds.seconds).perform_later(session.id, node['id'])
    [:wait, :waiting_delay, (seconds + 60).seconds.from_now]
  end
end
