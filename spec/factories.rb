require 'fileutils'
require 'system_commands'

FactoryGirl.define do
  factory :user do
    sequence(:login) {|n| "user#{n}" }
    sequence(:password) {|n| "userpass#{n}" }
    sequence(:email) {|n| "user#{n}@example.com" }
    administrator false
  end

  factory :admin, :class => User do
    sequence(:login) {|n| "admin#{n}" }
    sequence(:password) {|n| "adminpass#{n}" }
    sequence(:email) {|n| "admin#{n}@example.com" }
    administrator true
  end

  factory :course, :class => Course do
    sequence(:name) {|n| "course#{n}" }
    source_url 'git@example.com'
  end

  factory :exercise do
    course
    sequence(:name) {|n| "exercise#{n}" }
    sequence(:gdocs_sheet) {|n| "exercise#{n}" }
  end
  
  factory :returnable_exercise, :parent => :exercise do
    returnable_forced true
  end

  factory :submission do
    course
    user
    exercise
    processed true
    after_build { |sub| sub.exercise.course = sub.course  if sub.course}
  end

  factory :submission_data do
    submission
    return_file do |n|
      begin
        base_name = "fake_submission#{n}"
        zip_name = "#{base_name}.zip"
        FileUtils.mkdir_p "#{base_name}/src"
        File.open("#{base_name}/src/Foo.java", 'wb') do |f|
          f.write('public class Foo { public static void main(String[] args) {} }')
        end
        SystemCommands.sh!(['zip', '-q', '-r', zip_name, base_name])
        File.read(zip_name)
      ensure
        FileUtils.rm_rf base_name
        FileUtils.rm_rf zip_name
      end
    end
  end

  factory :awarded_point do
    course
    sequence(:name) {|n| "point#{n}" }
    submission
    user
    after_build { |pt| pt.submission.course = pt.course }
  end

  factory :available_point do
    sequence(:name) {|n| "point#{n}" }
    exercise
  end

  factory :review do
    submission
    reviewer :factory => :user
    review_body "This is a review"
  end

  factory :test_case_run do
    sequence(:test_case_name) {|n| "test case #{n}" }
    submission
    successful false
  end
  
  factory :feedback_question do
    course
    sequence(:question) {|n| "feedback question #{n}" }
    kind 'text'
  end
  
  factory :feedback_answer do
    feedback_question
    course
    exercise
    submission
    sequence(:answer) {|n| "feedback answer #{n}" }
  end

  factory :student_event do
    user
    course
    exercise
    event_type "test_event"
    sequence(:data) {|n| "testdata#{n}" }
    happened_at {|| Time.now }
    after_build {|ev| ev.exercise.course = ev.course }
  end

  factory :test_scanner_cache_entry do
    course
  end

end
