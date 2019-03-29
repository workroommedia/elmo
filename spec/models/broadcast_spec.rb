# frozen_string_literal: true

require "rails_helper"

describe Broadcast do
  let!(:user1) { create(:user, phone: "+17345550001", email: "a@b.com", role_name: "enumerator") }

  describe "#deliver" do
    let(:broadcast) do
      create(:broadcast, medium: "both", subject: "Foo", body: "Bar",
                         which_phone: "main_only", recipient_users: [user1])
    end

    context "happy path" do
      before do
        Settings.broadcast_tag = "NEMO"
      end

      it "should call appropriate methods" do
        expect(BroadcastMailer).to receive(:broadcast).with(["a@b.com"], "Foo", "Bar")
          .and_return(double(deliver_now: nil))
        expect(Sms::Broadcaster).to receive(:deliver).with(broadcast, "main_only", "[NEMO] Bar")
        broadcast.deliver
      end
    end

    context "with email error" do
      it "should save and re-raise" do
        expect(BroadcastMailer).to receive(:broadcast)
          .and_raise(Net::SMTPAuthenticationError.new("Auth failed"))
        expect(Sms::Broadcaster).to receive(:deliver)
        expect { broadcast.deliver }.to raise_error(Net::SMTPAuthenticationError)
        expect(broadcast.send_errors).to eq("Email Error: Auth failed")
      end
    end

    context "with sms errors" do
      it "should save and re-raise" do
        expect(BroadcastMailer).to receive(:broadcast).and_return(double(deliver_now: nil))
        expect(Sms::Broadcaster).to receive(:deliver).and_raise(Sms::Error.new("Failure 1\nFailure 2"))
        expect { broadcast.deliver }.to raise_error(Sms::Error)
        expect(broadcast.send_errors).to eq("SMS Error: Failure 1\nSMS Error: Failure 2")
      end
    end

    context "with email and sms errors" do
      it "should save all errors and re-raise first one" do
        expect(BroadcastMailer).to receive(:broadcast)
          .and_raise(Net::SMTPAuthenticationError.new("Auth failed"))
        expect(Sms::Broadcaster).to receive(:deliver).and_raise(Sms::Error.new("Failure 1\nFailure 2"))
        expect { broadcast.deliver }.to raise_error(Net::SMTPAuthenticationError)
        expect(broadcast.send_errors).to eq("Email Error: Auth failed\n"\
          "SMS Error: Failure 1\nSMS Error: Failure 2")
      end
    end
  end

  describe "recipient_numbers" do
    let!(:user2) { create(:user, phone: "+17345550002", role_name: "enumerator") }
    let!(:user3) { create(:user, phone: "+17345550003", role_name: "staffer") }
    let!(:user4) { create(:user, phone: "+17345550004", role_name: "coordinator") }
    let!(:user5) { create(:user, phone: "+17345550005", role_name: "coordinator") }
    let!(:group1) { create(:user_group, users: [user1, user4]) }
    let!(:group2) { create(:user_group, users: [user2]) }
    let!(:userX) { create(:user, phone: "+17345550006", mission: create(:mission)) }

    context "with specific users" do
      let(:broadcast) do
        create(:broadcast,
          recipient_selection: "specific",
          recipient_users: [user1, user3])
      end

      it "returns correct numbers" do
        expect(broadcast.recipient_numbers).to contain_exactly("+17345550001", "+17345550003")
      end
    end

    context "with specific users and groups" do
      let(:broadcast) do
        create(:broadcast,
          recipient_selection: "specific",
          recipient_users: [user5, user4],
          recipient_groups: [group1, group2])
      end

      it "returns correct numbers without duplication" do
        expect(broadcast.recipient_numbers).to contain_exactly(
          "+17345550005", "+17345550004", "+17345550001", "+17345550002"
        )
      end
    end

    context "with all_users" do
      let(:broadcast) { create(:broadcast, recipient_selection: "all_users") }

      it "returns correct numbers" do
        expect(broadcast.recipient_numbers).to contain_exactly(
          "+17345550001", "+17345550002", "+17345550003", "+17345550004", "+17345550005"
        )
      end
    end

    context "with all_users" do
      let(:broadcast) { create(:broadcast, recipient_selection: "all_enumerators") }

      it "returns correct numbers" do
        expect(broadcast.recipient_numbers).to contain_exactly("+17345550001", "+17345550002")
      end
    end

    context "with both_numbers" do
      let!(:user1) { create(:user, phone: "+17345550011", phone2: "+17345550021", role_name: "enumerator") }
      let!(:user2) { create(:user, phone: nil, phone2: "+17345550022", role_name: "enumerator") }
      let!(:user3) { create(:user, phone: "+17345550013", phone2: nil, role_name: "staffer") }
      let(:broadcast) do
        create(:broadcast,
          recipient_selection: "specific",
          recipient_users: [user1, user2, user3],
          which_phone: "both")
      end

      it "uses both available numbers for all users and eliminates nulls" do
        expect(broadcast.recipient_numbers).to contain_exactly(
          "+17345550011", "+17345550021", "+17345550022", "+17345550013"
        )
      end
    end
  end
end
