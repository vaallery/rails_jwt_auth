require 'rails_helper'

describe RailsJwtAuth::Recoverable do
  before :all do
    class Mock
      def deliver
      end

      def deliver_later
      end
    end
  end

  %w(ActiveRecord Mongoid).each do |orm|
    context "when use #{orm}" do
      before(:all) { RailsJwtAuth.model_name = "#{orm}User" }

      let(:user) { FactoryBot.create("#{orm.underscore}_user") }

      describe '#attributes' do
        it { expect(user).to respond_to(:reset_password_token) }
        it { expect(user).to respond_to(:reset_password_sent_at) }
      end

      describe '#send_reset_password_instructions' do
        it 'fills reset password fields' do
          mock = Mock.new
          allow(RailsJwtAuth::Mailer).to receive(:reset_password_instructions).and_return(mock)
          user.send_reset_password_instructions
          user.reload
          expect(user.reset_password_token).not_to be_nil
          expect(user.reset_password_sent_at).not_to be_nil
        end

        it 'sends reset password email' do
          mock = Mock.new
          allow(RailsJwtAuth::Mailer).to receive(:reset_password_instructions).and_return(mock)
          expect(mock).to receive(:deliver)
          user.send_reset_password_instructions
        end

        context 'when use deliver_later option' do
          before { RailsJwtAuth.deliver_later = true }
          after  { RailsJwtAuth.deliver_later = false }

          it 'uses deliver_later method to send email' do
            mock = Mock.new
            allow(RailsJwtAuth::Mailer).to receive(:reset_password_instructions).and_return(mock)
            expect(mock).to receive(:deliver_later)
            user.send_reset_password_instructions
          end
        end

        context 'when user is unconfirmed' do
          let(:user) { FactoryBot.create("#{orm.underscore}_unconfirmed_user") }

          it 'returns false' do
            expect(user.send_reset_password_instructions).to be_falsey
          end

          it 'does not fill reset password fields' do
            user.send_reset_password_instructions
            user.reload
            expect(user.reset_password_token).to be_nil
            expect(user.reset_password_sent_at).to be_nil
          end

          it 'doe not send reset password email' do
            expect(RailsJwtAuth::Mailer).not_to receive(:reset_password_instructions)
            user.send_reset_password_instructions
          end
        end

        context 'when user is locked' do
          let(:user) { FactoryBot.create("#{orm.underscore}_user", locked_at: 2.minutes.ago) }

          it 'returns false' do
            expect(user.send_reset_password_instructions).to be_falsey
          end

          it 'does not fill reset password fields' do
            user.send_reset_password_instructions
            user.reload
            expect(user.reset_password_token).to be_nil
            expect(user.reset_password_sent_at).to be_nil
          end

          it 'doe not send reset password email' do
            expect(RailsJwtAuth::Mailer).not_to receive(:reset_password_instructions)
            user.send_reset_password_instructions
          end
        end

        context 'when email field config is invalid' do
          it 'throws InvalidEmailField exception' do
            allow(RailsJwtAuth).to receive(:email_field_name).and_return(:invalid)

            expect {
              user.send_reset_password_instructions
            }.to raise_error(RailsJwtAuth::InvalidEmailField)
          end
        end
      end

      describe '#set_reset_password' do
        it 'validates password presence' do
          expect(user.set_reset_password({})).to be_falsey
          expect(get_record_error(user, :password)).to eq(:blank)
        end

        it 'validates reset_password_token' do
          allow(user).to receive(:expired_reset_password_token?).and_return(true)

          expect(user.set_reset_password({})).to be_falsey
          expect(get_record_error(user, :reset_password_token)).to eq(:expired)
        end

        it 'cleans reset password token and sessions' do
          user.reset_password_token = 'abcd'
          user.reset_password_sent_at = Time.current
          user.auth_tokens = ['test']
          user.save

          user.set_reset_password(password: 'newpassword')
          user.reload

          expect(user.reset_password_token).to be_nil
          expect(user.auth_tokens).to be_empty
        end
      end

      describe '#expired_reset_password_token?' do
        context 'when reset password token has expired' do
          before do
            RailsJwtAuth.reset_password_expiration_time = 1.second
          end

          after do
            RailsJwtAuth.reset_password_expiration_time = 1.day
          end

          it 'returns true' do
            user.reset_password_token = 'abcd'
            user.reset_password_sent_at = Time.current
            user.save
            sleep 1

            expect(user.expired_reset_password_token?).to be_truthy
          end
        end
      end
    end
  end
end
