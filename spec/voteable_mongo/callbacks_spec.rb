require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Mongo::Voteable, "Callbacks" do
  before(:all) do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    @post1 = Post.create!(:title => 'post11')
  end
  
  context 'post1 receives a vote' do

    it "runs callbacks before voting" do
      @post1.should_receive(:before_post_vote)
      @post1.set_vote(:value => :up, :ip => "200")
    end
    it "runs callbacks after voting" do
      @post1.should_receive(:after_post_vote)
      @post1.set_vote(:value => :up, :ip => "300")
    end
  end
end