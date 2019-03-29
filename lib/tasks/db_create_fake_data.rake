require File.expand_path("../../../spec/support/contexts/option_node_support", __FILE__)

namespace :db do
  desc "Create fake data for manual testing purposes."
  task :create_fake_data, [:mission_name] => [:environment] do |t, args|
    mission_name = args[:mission_name] || "Fake Mission #{rand(10000)}"

    mission = Mission.create(name: mission_name)

    puts "Creating forms"
    sample_form = FactoryGirl.create(:form, mission: mission, question_types: [
      "text",
      "long_text",
      "integer",
      "counter",
      "decimal",
      "location",
      [
        "integer",
        "long_text"
      ],
      "select_one",
      "multilevel_select_one",
      "select_multiple",
      "datetime",
      "date",
      "time",
      "image",
      "annotated_image",
      "signature",
      "sketch",
      "audio",
      "video"
    ])
    sample_form.publish!

    smsable_form = FactoryGirl.create(:form,
      name: "SMS Form",
      smsable: true,
      mission: mission,
      question_types: QuestionType.with_property(:smsable).map(&:name)
    )

    puts "Creating users"
    # Create users and groups
    25.times do
      FactoryGirl.create(:user, mission: mission, role_name: User::ROLES.sample)
    end

    FactoryGirl.create_list(:user_group, 5, mission: mission)

    50.times do
      uga = UserGroupAssignment.new(user_group: UserGroup.all.sample, user: User.all.sample);
      uga.save if uga.valid?
    end

    # Define media paths
    image_path = Rails.root.join("spec", "fixtures", "media", "images", "the_swing.png").to_s
    audio_path = Rails.root.join("spec", "fixtures", "media", "audio", "powerup.mp3").to_s
    video_path = Rails.root.join("spec", "fixtures", "media", "video", "jupiter.mp4").to_s

    print "Creating responses"

    mission.users.find_each do |user|
      3.times do
        print "."
        answer_values = [
          Faker::Pokemon.name, # text
          Faker::Hipster.paragraphs(3).join("\n\n"), #long_text
          rand(1000..5000), # integer
          rand(1..100), # counter
          Faker::Number.decimal(rand(1..3), rand(1..5)), # decimal
          "#{Faker::Address.latitude} #{Faker::Address.longitude}", # location
          [rand(1..100), Faker::Hacker.say_something_smart], # integer/long text
          "Cat", # select_one
          %w(Plant Oak), # multilevel_select_one
          %w(Cat Dog), # select_multiple
          Faker::Time.backward(365), # datetime
          Faker::Date.birthday, # date
          Faker::Time.between(1.year.ago, Date.today, :evening), # time
          Media::Image.create(item: File.open(image_path)), # image
          FactoryGirl.build(:media_image, item: File.open(image_path)), # annotated image
          FactoryGirl.build(:media_image, item: File.open(image_path)), # signature
          FactoryGirl.build(:media_image, item: File.open(image_path)), # sketch
          FactoryGirl.build(:media_audio, item: File.open(audio_path)), # audio
          FactoryGirl.build(:media_video, item: File.open(video_path)), # video
        ]

        FactoryGirl.create(:response,
          form: sample_form,
          user: user,
          mission: mission,
          answer_values: answer_values,
          created_at: Faker::Time.backward(365)
        )
      end
    end
    print "\n"

    puts "Created #{mission_name}"
  end
end
