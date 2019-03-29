def get_user
  u = FactoryGirl.create(:user)

  # set the mission to get_mission so that ability stuff will work
  u.save(:validate => false)

  return u
end

def test_password
  "Password1"
end

FactoryGirl.define do
  factory :user do
    transient do
      role_name :coordinator
      mission { get_mission }
    end

    login { Random.letters(8) }
    sequence(:name) { |n| "A User #{n}" }
    email { Random.letters(8) + '@example.com' }
    reset_password_method "email"
    password { test_password }
    password_confirmation { test_password }

    # Need to be careful with this as random strings of digits get normalized
    # in funny ways by PhoneNormalizer/Phony
    phone { "+1709#{rand(1_000_000..9_999_999)}" }
    pref_lang "en"
    login_count 1

    persistence_token { Authlogic::Random.hex_token }
    perishable_token { Authlogic::Random.friendly_token }

    after(:build) do |user, evaluator|
      user.assignments.build(mission: evaluator.mission, role: evaluator.role_name.to_s)
    end

    trait :no_email do
      email nil
      reset_password_method "print"
      role_name :enumerator # Needed to allow print password resetting
    end

    factory :admin do
      admin true
    end
  end
end
