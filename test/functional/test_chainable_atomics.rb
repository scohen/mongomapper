require 'test_helper'

class ChainableAtomicsTest < Test::Unit::TestCase
  def setup
    @page_class = Doc do
      key :title, String
      key :day_count, Integer, :default => 0
      key :week_count, Integer, :default => 0
      key :month_count, Integer, :default => 0
      key :tags, Array
    end
  end

  def assert_page_counts(page, day_count, week_count, month_count)
    page.reload
    page.day_count.should == day_count
    page.week_count.should == week_count
    page.month_count.should == month_count
  end

  def assert_keys_removed(page, *keys)
    keys.each do |key|
      doc = @page_class.collection.find_one({ :_id => page.id })
      doc.keys.should_not include(key)
    end
  end

  context "used alone" do

    context "unset" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar))
        @page2 = @page_class.create(:title => 'Home')
      end

      should "unset the keys" do
        @page_class.atomic.where(:title => 'Home').unset(:title, :tags).execute
        assert_keys_removed @page, :title, :tags
        assert_keys_removed @page2, :title, :tags
      end
    end

    context "increment" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar))
        @page2 = @page_class.create(:title => 'Home')
      end

      should "be able to increment a field" do
        @page_class.atomic.where(:tags => "foo").increment(:day_count => 1, :week_count => 2, :month_count => 3).execute
        assert_page_counts @page, 1, 2, 3
        assert_page_counts @page2, 0, 0, 0
      end
    end

    context "decrement" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar), :day_count => 10, :week_count => 5, :month_count => 3)
        @page2 = @page_class.create(:title => 'Home')
      end

      should "be able to decrement a field" do
        @page_class.atomic.where(:tags => "foo").decrement(:day_count => 3, :week_count => 2, :month_count => 1).execute
        assert_page_counts @page, 7, 3, 2
        assert_page_counts @page2, 0, 0, 0
      end
    end


    context "set" do
      setup do
        @page  = @page_class.create(:title => 'Home')
        @page2 = @page_class.create(:title => 'Home')
      end

      should "work with criteria and modifier hashes" do
        @page_class.atomic.where(:title => 'Home').set(:title => 'Home Revised').execute

        @page.reload
        @page.title.should == 'Home Revised'

        @page2.reload
        @page2.title.should == 'Home Revised'
      end

      should "typecast values before querying" do
        @page_class.key :tags, Set

        assert_nothing_raised do
          @page_class.atomic.where(@page.id).set(:tags => ['foo', 'bar'].to_set).execute
          @page.reload
          @page.tags.should == Set.new(['foo', 'bar'])
        end
      end

      should "not typecast keys that are not defined in document" do
        assert_raises(BSON::InvalidDocument) do
          @page_class.atomic.where(@page.id).set(:colors => ['red', 'green'].to_set).execute
        end
      end

      should "set keys that are not defined in document" do
        @page_class.atomic.where(@page.id).set(:colors => %w[red green]).execute
        @page.reload
        @page[:colors].should == %w[red green]
      end
    end

    context "push" do
      setup do
        @page  = @page_class.create(:title => 'Home')
        @page2 = @page_class.create(:title => 'Home')
        @page3 = @page_class.create(:title => 'Profile')
      end

      should "be able to update" do
        @page_class.atomic.where(:title => 'Home').push(:tags => 'foo').execute

        @page.reload
        @page.tags.should == %w(foo)

        @page2.reload
        @page2.tags.should == %w(foo)

        @page3.reload
        @page3.tags.should be_empty
      end


    end

    context "push_all" do
      setup do
        @page  = @page_class.create(:title => 'Home')
        @page2 = @page_class.create(:title => 'Home')
        @page3 = @page_class.create(:title => 'Profile')
        @tags  = %w(foo bar)
      end

      should "add tags" do
        @page_class.atomic.where(:title => 'Home').push_all(:tags => @tags).execute

        @page.reload
        @page.tags.should == @tags

        @page2.reload
        @page2.tags.should == @tags

        @page3.reload
        @page3.tags.should be_empty
      end


    end

    context "pull" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar))
        @page2 = @page_class.create(:title => 'Home', :tags => %w(foo bar))
        @page3 = @page_class.create(:title => 'Profile', :tags => %w(foo bar))
      end

      should "remove tags" do
        @page_class.atomic.where(:title => 'Home').pull(:tags => 'foo').execute

        @page.reload
        @page.tags.should == %w(bar)

        @page2.reload
        @page2.tags.should == %w(bar)

        @page3.reload
        @page3.tags.should == %w(foo bar)
      end
    end


    context "pull_all" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar baz))
        @page2 = @page_class.create(:title => 'Home', :tags => %w(foo bar baz))
        @page3 = @page_class.create(:title => 'Profile', :tags => %w(foo bar baz))
      end

      should "work with criteria and modifier hashes" do
        @page_class.atomic.where(:title => 'Home').pull_all(:tags => %w(foo bar)).execute

        @page.reload
        @page.tags.should == %w(baz)

        @page2.reload
        @page2.tags.should == %w(baz)

        @page3.reload
        @page3.tags.should == %w(foo bar baz)
      end
    end


    context "add_to_set" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => 'foo')
        @page2 = @page_class.create(:title => 'Home')
      end

      should "be able to add to set with criteria and modifier hash" do
        @page_class.atomic.where(:title => 'Home').add_to_set(:tags => 'foo').execute

        @page.reload
        @page.tags.should == %w(foo)

        @page2.reload
        @page2.tags.should == %w(foo)
      end
    end

    context "push_uniq" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => 'foo')
        @page2 = @page_class.create(:title => 'Home')
      end

      should "be able to push uniq with criteria and modifier hash" do
        @page_class.atomic.where(:title => 'Home').push_uniq(:tags => 'foo').execute

        @page.reload
        @page.tags.should == %w(foo)

        @page2.reload
        @page2.tags.should == %w(foo)
      end

    end

    context "pop" do
      setup do
        @page  = @page_class.create(:title => 'Home', :tags => %w(foo bar))
        @page2 = @page_class.create(:title => 'Home', :tags => %w(foo bar))
      end

      should "be able to remove the last element the array" do
        @page_class.atomic.where(@page.id).pop(:tags => 1).execute
        @page.reload
        @page.tags.should == %w(foo)

        @page2.reload
        @page2.tags.should == %w(foo bar)
      end

      should "be able to remove the first element of the array" do
        @page_class.atomic.where(@page.id).pop(:tags => -1).execute
        @page.reload
        @page.tags.should == %w(bar)
        @page2.tags.should == %w(foo bar)
      end
    end
  end


  context "block dsl" do
    def setup
      @page_class = Doc do
        key :title, String
        key :day_count, Integer, :default => 0
        key :week_count, Integer, :default => 0
        key :month_count, Integer, :default => 0
        key :tags, Array
      end
    end

    # TODO: test the block DSL
  end

  context "chaining updates" do
    def setup
      @page_class = Doc do
        key :title, String
        key :day_count, Integer, :default => 0
        key :week_count, Integer, :default => 0
        key :month_count, Integer, :default => 0
        key :tags, Array
      end
    end

    context "ensuring the kicker works" do
      setup do
        @page  = @page_class.create(:title => "Home")
        @page2 = @page_class.create(:title => "Home")
        @page3 = @page_class.create(:title => "Profile")
      end

      should "not fire any updates until the kicker is called" do
        query = @page_class.atomic.where(:title => "Home").increment(:day_count => 1).add_to_set(:tags => "foo")
        @page.reload
        @page.tags.should be_empty
        @page.day_count.should be_zero

        query.execute
        @page.reload

        @page.tags.should == ["foo"]
        @page.day_count.should == 1
      end
    end

    context "the block dsl" do
      setup do
        @page = @page_class.create(:title => "Home")
      end

      should "support a block dsl" do

        @page_class.atomic.where(:title => "Home") do
          increment(:month_count => 1)
          increment(:day_count => 5)
          add_to_set(:tags => "foo")
        end

        @page.reload
        @page.month_count.should == 1
        @page.day_count.should == 5
        @page.tags.should == ["foo"]
      end

    end

    context "chaining several operations" do
      setup do
        @page  = @page_class.create(:title => "Home")
        @page2 = @page_class.create(:title => "Home")
        @page3 = @page_class.create(:title => "Profile")
      end

      should "be able to increment and push tags" do
        @page_class.atomic.where(:title => "Home").increment(:month_count => 2).push_all(:tags => %w(foo bar baz)).execute

        [@page, @page2].each do |page|
          page.reload
          page.tags.should == %w(foo bar baz)
          page.month_count.should == 2
        end

        @page3.tags.should be_empty
        @page3.month_count.should == 0
      end

      should "be able to set and push tags" do
        @page_class.atomic.where(:title => "Home").set(:title => "New title").push(:tags => "friendly").execute

        [@page, @page2].each do |page|
          page.reload
          page.tags.should == ["friendly"]
          page.title.should == "New title"
        end

        @page3.tags.should be_empty
        @page3.title.should == "Profile"
      end
    end

    context "when chaining increment and decrement" do
      setup do
        @page = @page_class.create(:title => "Home", :week_count => 5, :day_count => 3, :month_count => 1)
      end

      should "chain increment and then  decrement on a single field correctly" do
        @page_class.atomic.where(:title => "Home").increment(:week_count => 3, :month_count => 2).decrement(:week_count => 2).execute
        @page.reload
        @page.week_count.should == 6
        @page.month_count.should == 3
      end

      should "chain decrement and then increment on a single field correctly" do
        @page_class.atomic.where(:title => "Home").decrement(:week_count => 5).increment(:week_count => 2).execute
        @page.reload
        @page.week_count.should == 2
      end

    end

  end
end
