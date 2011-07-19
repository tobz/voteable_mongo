module Helpers
  # Helper Methods

  # Compare object stats with expectations in array
  # 
  #   up_votes_count, 
  #   down_votes_count, 
  #   faceless_up_count, 
  #   faceless_down_count, 
  #   votes_count, 
  #   votes_point
  # 
  def stats_for(obj, expected, voting_field = "votes")
    obj.reload
    stats = [obj.up_votes_count(voting_field), 
            obj.down_votes_count(voting_field), 
            obj.faceless_up_votes_count(voting_field), 
            obj.faceless_down_votes_count(voting_field), 
            obj.total_up_votes_count(voting_field), 
            obj.total_down_votes_count(voting_field),
            obj.votes_count(voting_field), 
            obj.votes_point(voting_field)
            ]
    stats.should == expected
  end
end