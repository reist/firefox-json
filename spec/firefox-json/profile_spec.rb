RSpec.describe FirefoxJson::Profiles do
  context 'an initialized object' do
    before(:each) do
      @profiles = FirefoxJson::Profiles.new('spec/fixtures')
    end

    it "reads profiles.ini" do
      expect(@profiles).to be_a(FirefoxJson::Profiles)
    end

    it "sees profiles" do
      expect(@profiles.list).to eq(['default', 'testing', 'temporary'])
    end

    it "can return a profile" do
      expect(@profiles['default']).to be_a(FirefoxJson::Profiles::Profile)
    end

    it "doesn't return non-existing profiles" do
      expect(@profiles['random']).to be_nil
    end
  end
end
