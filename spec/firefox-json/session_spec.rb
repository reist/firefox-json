RSpec.describe FirefoxJson::Session do
  before(:each) do
    struct = {
      windows: [],
      _closedWindows: [],
      selectedWindow: 0
    }
    @struct = Oj.dump(struct, mode: :strict)
  end

  it 'loads a session JSON' do
    expect(FirefoxJson::Session.load(@struct)).to be_a(FirefoxJson::Session::Session)
  end

  it 'returns windows' do
    session = FirefoxJson::Session.load(@struct)
    expect(session.windows).to be_empty
  end
end

