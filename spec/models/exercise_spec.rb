require 'spec_helper'

describe Exercise do
  include GitTestActions

  let(:user) { Factory.create(:user) }
  let(:course) { Factory.create(:course) }

  describe "gdocs_sheet" do
    it "should deduce gdocs_sheet from exercise name" do
      ex1 = Factory.create(:exercise, :name => "ex")
      ex1.options = {}
      ex1.gdocs_sheet.should == "root"

      ex2 = Factory.create(:exercise, :name => "wtf-ex")
      ex2.options = {}
      ex2.gdocs_sheet.should == "wtf"

      ex3 = Factory.create(:exercise, :name => "omg-wtf-ex")
      ex3.options = {}
      ex3.gdocs_sheet.should == "omg-wtf"

      ex4 = Factory.create(:exercise, :name => "omg-wtf-ex")
      ex4.options = { "points_visible" => false }
      ex4.gdocs_sheet.should == nil
    end
  end

  describe "course_gdocs_sheet_exercises scope" do
    it "should find all the exercises that belong to the gdocs_sheet" do
      sheetname = "lolwat"
      course = Factory.create(:course)
      ex1 = Factory.create(:exercise, :course => course,
                           :gdocs_sheet => sheetname)
      ex2 = Factory.create(:exercise, :course => course,
                           :gdocs_sheet => sheetname)
      ex3 = Factory.create(:exercise, :course => course,
                           :gdocs_sheet => "not#{sheetname}")
      exercises = Exercise.course_gdocs_sheet_exercises(course, sheetname)

      exercises.size.should == 2
      exercises.should include(ex1)
      exercises.should include(ex2)
      exercises.should_not include(ex3)
    end
  end


  describe "associated submissions" do
    before :each do
      @exercise = Factory.create(:exercise, :course => course, :name => 'MyExercise')
      @submission_attrs = {
        :course => course,
        :exercise_name => 'MyExercise',
        :user => user
      }
      Submission.create!(@submission_attrs)
      Submission.create!(@submission_attrs)
      @submissions = Submission.all
    end

    it "should be associated by exercise name" do
      @exercise.submissions.size.should == 2
      @submissions[0].exercise.should == @exercise
      @submissions[0].exercise_name = 'AnotherExercise'
      @submissions[0].save!
      @exercise.submissions.size.should == 1
    end
  end

  it "knows which exercise groups it belongs to" do
    ex = Factory.create(:exercise, :course => course, :name => 'foo-bar-baz')

    ex.exercise_group_name.should == 'foo-bar'
    ex.exercise_group.name.should == 'foo-bar'
    ex.exercise_group.parent.name.should == 'foo'
    ex.belongs_to_exercise_group?(ex.exercise_group).should == true
    ex.belongs_to_exercise_group?(ex.exercise_group.parent).should == true

    ex2 = Factory.create(:exercise, :course => course, :name => 'xoo-bar-baz')
    course.reload
    another_course = Factory.create(:course)
    ex3 = Factory.create(:exercise, :course => another_course, :name => 'foo-bar-baz')

    ex.belongs_to_exercise_group?(ex2.exercise_group).should == false
    ex.belongs_to_exercise_group?(ex3.exercise_group).should == false
  end

  it "can be hidden with a boolean 'hidden' option" do
    ex = Factory.create(:exercise, :course => course)
    ex.options = {"hidden" => true}
    ex.should be_hidden
  end

  def set_deadline(ex, t)
    if t.is_a? Array
      ex.deadline_spec = t.to_json
    else
      ex.deadline_spec = [t.to_s].to_json
    end
  end

  it "should treat date deadlines as being at 23:59:59 local time" do
    ex = Factory.create(:exercise, :course => course)
    set_deadline(ex, Date.today)
    ex.deadline_for(user).should == Date.today.end_of_day
  end

  it "should accept deadlines in either SQLish or Finnish date format" do
    ex = Factory.create(:exercise, :course => course)

    set_deadline(ex, '2011-04-19 13:55')
    dl = ex.deadline_for(user)
    dl.year.should == 2011
    dl.month.should == 04
    dl.day.should == 19
    dl.hour.should == 13
    dl.min.should == 55

    set_deadline(ex, '25.05.2012 14:56')
    dl = ex.deadline_for(user)
    dl.day.should == 25
    dl.month.should == 5
    dl.year.should == 2012
    dl.hour.should == 14
    dl.min.should == 56
  end

  it "should accept a blank deadline" do
    ex = Factory.create(:exercise, :course => course)
    set_deadline(ex, nil)
    ex.deadline_for(user).should be_nil
    set_deadline(ex, "")
    ex.deadline_for(user).should be_nil
  end

  it "should not accept certain hardcoded values for gdocs_sheet" do
    ex = Factory.create(:exercise, :course => course)
    ex.valid?.should be_true
    ex.gdocs_sheet = 'MASTER'
    ex.valid?.should be_false
    ex.gdocs_sheet = 'PUBLIC'
    ex.valid?.should be_false
    ex.gdocs_sheet = 'nonPUBLIC'
    ex.valid?.should be_true
    ex.gdocs_sheet = 'nonMASTER'
    ex.valid?.should be_true
  end

  it "should raise an exception if trying to set a deadline in invalid format" do
    ex = Factory.create(:exercise)
    expect { set_deadline(ex, "xooxers") }.to raise_error
    expect { set_deadline(ex, "2011-07-13 12:34:56:78") }.to raise_error
  end

  it "should always be submittable by administrators as long as it's returnable" do
    admin = Factory.create(:admin)
    ex = Factory.create(:returnable_exercise, :course => course)

    ex.deadline_for(user).should be_nil
    ex.should be_submittable_by(admin)

    set_deadline(ex, Date.today - 1.day)
    ex.should be_submittable_by(admin)

    ex.hidden = true
    ex.should be_submittable_by(admin)

    ex.options = { 'returnable' => false }
    ex.should_not be_submittable_by(admin)
  end

  it "should be submittable by non-administrators only if the deadline has not passed and the exercise is not hidden and is published" do
    #TODO: publish_time too!
    user = Factory.create(:user)
    ex = Factory.create(:returnable_exercise, :course => course)

    ex.deadline_for(user).should be_nil
    ex.publish_time.should be_nil
    ex.should be_submittable_by(user)
    
    ex.publish_time = Date.today + 1.day
    ex.should_not be_submittable_by(user)
    
    ex.publish_time = Date.today - 1.day
    ex.should be_submittable_by(user)

    set_deadline(ex, Date.today + 1.day)
    ex.should be_submittable_by(user)

    set_deadline(ex, Date.today - 1.day)
    ex.should_not be_submittable_by(user)

    set_deadline(ex, nil)
    ex.hidden = true
    ex.should_not be_submittable_by(user)
  end
  
  it "should never be submittable by guests" do
    ex = Factory.create(:returnable_exercise, :course => course)
    
    ex.should_not be_submittable_by(Guest.new)
  end
  
  it "should be visible to regular users by default" do
    user = Factory.create(:user)
    ex = Factory.create(:exercise, :course => course)
    
    ex.should be_visible_to(user)
  end
  
  it "should not be visible to regular users if explicitly hidden" do
    user = Factory.create(:user)
    ex = Factory.create(:exercise, :course => course, :hidden => true)
    
    ex.should_not be_visible_to(user)
  end
  
  it "should not be visible to regular users if the publish time has not passed" do
    user = Factory.create(:user)
    ex = Factory.create(:exercise, :course => course, :publish_time => Time.now + 10.hours)
    
    ex.should_not be_visible_to(user)
  end
  
  it "should be visible to administrators even if publish time is in the future" do
    admin = Factory.create(:admin)
    ex = Factory.create(:exercise, :course => course, :publish_time => Time.now + 10.hours, :hidden => false)
    
    ex.should be_visible_to(admin)
  end
  
  it "should be visible to administrators even if hidden" do
    admin = Factory.create(:admin)
    ex = Factory.create(:exercise, :course => course, :publish_time => Time.now - 10.hours, :hidden => true)
    
    ex.should be_visible_to(admin)
  end

  it "can tell whether a user has ever attempted an exercise" do
    exercise = Factory.create(:exercise, :course => course)
    exercise.should_not be_attempted_by(user)

    Submission.create!(:user => user, :course => course, :exercise_name => exercise.name, :processed => false)
    exercise.should_not be_attempted_by(user)

    Submission.create!(:user => user, :course => course, :exercise_name => exercise.name, :processed => true)
    exercise.reload
    exercise.should be_attempted_by(user)
  end

  it "can tell whether a user has completed an exercise" do
    exercise = Factory.create(:exercise, :course => course)
    exercise.should_not be_completed_by(user)

    other_user = Factory.create(:user)
    other_user_sub = Submission.create!(:user => other_user, :course => course, :exercise_name => exercise.name, :all_tests_passed => true)
    exercise.should_not be_completed_by(user)

    Submission.create!(:user => user, :course => course, :exercise_name => exercise.name, :pretest_error => 'oops', :all_tests_passed => true) # in reality all_tests_passed should always be false if pretest_error is not null
    exercise.should_not be_completed_by(user)

    sub = Submission.create!(:user => user, :course => course, :exercise_name => exercise.name, :all_tests_passed => false)
    exercise.should_not be_completed_by(user)
  end

  it "can tell its available review points" do
    exercise = Factory.create(:exercise, :course => course)
    pt1 = Factory.create(:available_point, :exercise => exercise, :requires_review => false)
    pt2 = Factory.create(:available_point, :exercise => exercise, :requires_review => true)
    pt3 = Factory.create(:available_point, :exercise => exercise, :requires_review => true)

    exercise.available_review_points.sort.should == [pt2, pt3].map(&:name).sort
  end

  it "can tell if it's been reviewed for a user" do
    exercise = Factory.create(:exercise, :course => course)

    exercise.should_not be_reviewed_for(user)
    submission = Factory.create(:submission, :exercise => exercise, :course => course, :user => user, :reviewed => true)
    Factory.create(:review, :submission => submission)
    exercise.reload
    exercise.should be_reviewed_for(user)
  end

  it "can tell if all review points have been given to a user" do
    exercise = Factory.create(:exercise, :course => course)
    pt1 = Factory.create(:available_point, :exercise => exercise, :requires_review => false)
    pt2 = Factory.create(:available_point, :exercise => exercise, :requires_review => true)
    pt3 = Factory.create(:available_point, :exercise => exercise, :requires_review => true)

    Factory.create(:awarded_point, :course => course, :user => user, :name => pt2.name)
    exercise.should_not be_all_review_points_given_for(user)
    Factory.create(:awarded_point, :course => course, :user => user, :name => pt3.name)
    exercise.should be_all_review_points_given_for(user)
  end

  it "can tell which review point are missing for a user" do
    exercise = Factory.create(:exercise, :course => course)
    pt1 = Factory.create(:available_point, :exercise => exercise, :requires_review => false)
    pt2 = Factory.create(:available_point, :exercise => exercise, :requires_review => true)
    pt3 = Factory.create(:available_point, :exercise => exercise, :requires_review => true)

    Factory.create(:awarded_point, :course => course, :user => user, :name => pt2.name)
    exercise.missing_review_points_for(user).should == [pt3.name]
  end
end

