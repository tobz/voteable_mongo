require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
describe "Anonymous support" do
  before(:all) do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    # for anonymous voting tests
    @_category1 = Category.create!(:name => '123')
    @_category2 = Category.create!(:name => '456')
    @_post1 = Post.create!(:title => 'post11')
    @_post2 = Post.create!(:title => 'post21')
    @_post1.category_ids = [@_category1.id, @_category2.id]
    @_post1.save!
    @_comment = @_post2.comments.create!
  end
  context 'anonymous vote up post1 the first time' do
     before :all do
       @post = @_post1.vote(:value => :up)
     end
     it 'validates return post' do
       @post.should be_is_a Post
       @post.should_not be_new_record
   
       @post.votes.should == {
         'up' => [],
         'down' => [],
         'faceless_up_count' => 1,
         'faceless_down_count' => 0,
         'up_count' => 0,
         'down_count' => 0,
         'count' => 1,
         'point' => 1
       }
     end
     it 'validates post counters' do
       @_post1.up_votes_count.should == 0
       @_post1.down_votes_count.should == 0
       @_post1.faceless_up_count.should == 1
       @_post1.faceless_down_count.should == 0
       @_post1.total_up_count.should == 1
       @_post1.total_down_count.should == 0
       @_post1.votes_count.should == 1
       @_post1.votes_point.should == 1
     end
     it "validates voters stats" do
       @_post1.up_voters(User).to_a.should be_empty
       @_post1.voters(User).to_a.should be_empty
       @_post1.down_voters(User).should be_empty
     end
     it "validates parents stats" do
       @_category1.reload
       @_category1.up_votes_count.should == 0
       @_category1.down_votes_count.should == 0
       @_category1.faceless_up_count.should == 0
       @_category1.faceless_down_count.should == 0
       @_category1.total_up_count.should == 0
       @_category1.total_down_count.should == 0
       @_category1.votes_count.should == 0
       @_category1.votes_point.should == 3
   
       @_category2.reload
       @_category2.up_votes_count.should == 0
       @_category2.down_votes_count.should == 0
       @_category2.faceless_up_count.should == 0
       @_category2.faceless_down_count.should == 0
       @_category2.total_up_count.should == 0
       @_category2.total_down_count.should == 0
       @_category2.votes_count.should == 0
       @_category2.votes_point.should == 3
     end
   end
   context "anonymous votes down post1 the first time" do
     before :all do
       Post.vote(:votee_id => @_post1.id, :value => :down)
       @_post1.reload
     end
     it 'post1 up_votes_count is the same' do
       @_post1.up_votes_count.should == 0
     end

     it 'post1 faceless_up_count is the same' do
       @_post1.faceless_up_count.should == 1
     end

     it 'down_votes_count, votes_count, and votes_point changed' do
       @_post1.down_votes_count.should == 0
       @_post1.faceless_down_count.should == 1
       @_post1.votes_count.should == 2
       @_post1.votes_point.should == 0
     end

     it 'post1 get voters' do
       @_post1.up_voters(User).to_a.should be_empty
       @_post1.down_voters(User).to_a.should be_empty
       @_post1.voters(User).to_a.should be_empty
     end

     it 'categories votes' do
       @_category1.reload
       @_category1.up_votes_count.should == 0
       @_category1.down_votes_count.should == 0
       @_category1.faceless_up_count.should == 0
       @_category1.faceless_down_count.should == 0
       @_category1.votes_count.should == 0
       @_category1.votes_point.should == -2

       @_category2.reload
       @_category2.up_votes_count.should == 0
       @_category2.down_votes_count.should == 0
       @_category2.faceless_up_count.should == 0
       @_category2.faceless_down_count.should == 0
       @_category2.votes_count.should == 0
       @_category2.votes_point.should == -2
     end
   end
   context 'anonymous vote up post2 comment the first time' do
     before :all do
       @_comment.vote(:value => :up)
       @_comment.reload
       @_post2.reload
     end

     it 'validates' do
       @_post2.up_votes_count.should == 0
       @_post2.down_votes_count.should == 0
       @_post2.faceless_up_count.should == 1
       @_post2.faceless_down_count.should == 0
       @_post2.votes_count.should == 1
       @_post2.votes_point.should == 2

       @_comment.up_votes_count.should == 0
       @_comment.down_votes_count.should == 0
       @_comment.faceless_up_count.should == 1
       @_comment.faceless_down_count.should == 0
       @_comment.votes_count.should == 1
       @_comment.votes_point.should == 1
     end
   end
end