require 'spec_helper'

describe Mockingbird do
  it 'passes this acceptance spec' do
    module Mock
      class User

        # things sung inside the block are sungd to User's singleton class (ie User.find)
        Mockingbird.for self do

          # the block is used as a default value unless overridden by the spec
          song :find do |id|
            new id
          end

        end

        # things sung outside the block are sung at User (ie user.id)

        song :initialize do |id|
          @id = id # can set the @id ivar to give the #id method a default
          @phone_numbers = []
        end

        song :id
        song(:name) { 'Josh' }
        song :address

        song :phone_numbers

        song :add_phone_number do |area_code, number|
          @phone_numbers << [area_code, number]
        end
      end
    end


    # don't affect the real user class
    user_class = Mock::User.reprise


    # =====  set a default  =====
    user_class.will_find :user1
    user_class.find(1).should == :user1
    user_class.find(2).should == :user1

    # set a queue of default values
    user_class.will_find_queue :user1, :user2, :user3    # set three overrides
    user_class.find(11).should == :user1                 # first override
    user_class.find(22).should == :user2                 # second override
    user_class.find(33).should == :user3                 # third override
    user_class.find(44).should be_a_kind_of Mock::User   # back to default block
    # might also be nice to provide a way to raise an error

    # tracking invocations
    user_class = Mock::User.reprise
    user_class.should_not have_been_told_to :find
    user_class.find 12
    user_class.find 12
    user_class.find 23
    user_class.should have_been_told_to(:find).times(3)
    user_class.should have_been_told_to(:find).with(12)
    user_class.should have_been_told_to(:find).with(12).times(2)
    # user_class.should have_been_told_to(:find).with(22).and_with(33)  # not sure if we really care about this (i.e. probably this will come in a later release if we like the lib)
    # user_class.should have_been_told_to(:find).with(11).before(22)    # not sure if we really care about this

    expect { user_class.should have_been_told_to(:find).with(123123123) }.to raise_error RSpec::Expectations::ExpectationNotMetError


    # =====  on the instances  =====
    user = user_class.find 123

    # tracking initialization args
    user.should have_been_initialized_with 123

    # tracking invocations (these are just synonyms to try and fit the language you would want to use in a spec)
    # user.should_not have_been_asked_for :id
    user.should_not have_been_asked_for_its :id
    # user.should_not have_invoked :id
    user.id.should == 123
    # user.should have_been_asked_for :id
    user.should have_been_asked_for_its :id
    # user.should have_invoked :id
    # maybe someday also support assertions about order of method invocation

    # set a default
    user.will_have_name 'Bill'
    user.name.should == 'Bill'
    user.should have_been_asked_for_its :name

    # defaults are used if provided
    Mock::User.new(1).name.should == 'Josh'

    # error is raised if you try to access an attribute that hasn't been set and has no default
    expect { Mock::User.new(1).address }.to raise_error Mockingbird::UnpreparedMethodError
    Mock::User.new(1).will_have_address('123 Fake St.').address.should == '123 Fake St.'

    # methods with multiple args
    user.phone_numbers.should be_empty
    user.add_phone_number '123', '456-7890'
    user.should have_been_told_to(:add_phone_number).with('123', '456-7890')
    # user.phone_numbers.should == [['123', '456-7890']] # <-- should we use a hook, or default block to make this happen?


    # =====  Substitutability  =====

    # real user is not a suitable substitute if missing methods that mock user has
    user_class.should_not be_substitutable_for Class.new

    # real user must have all of mock user's methods to be substitutable
    substitutable_real_user_class = Class.new do
      def self.find() end
      def initialize(id) end
      def id() end
      def name() end
      def address() end
      def phone_numbers() end
      def add_phone_number(area_code, number) end
    end
    user_class.should be_substitutable_for substitutable_real_user_class

    # real user is not a suitable substitutable if has extra methods
    real_user_class = substitutable_real_user_class.reprise
    def real_user.some_class_meth() end
    user_class.should_not be_substitutable_for real_user_class

    real_user_class = substitutable_real_user_class.reprise
    real_user_class.send(:define_method, :some_instance_method) {}
    user_class.should_not be_substitutable_for real_user

    # real user is not a suitable substitutable_real_user_class unless arities match
    real_user_class = substitutable_real_user_class.reprise
    def real_user_class.find(arg1, arg2) end
    user_class.should_not be_substitutable_for real_user_class

    real_user_class = substitutable_real_user_class.reprise
    real_user_class.send(:define_method, :id) { |arg1, arg2, arg3| }
    user_class.should_not be_substitutable_for real_user_class
  end
end
