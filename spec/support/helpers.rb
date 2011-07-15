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
  def stats_for(obj, expected)
    obj.reload
    stats = [obj.up_votes_count, obj.down_votes_count, obj.faceless_up_count, obj.faceless_down_count, obj.votes_count, obj.votes_point]
    stats.should == expected
  end
end