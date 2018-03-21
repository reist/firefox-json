RSpec.describe FirefoxJson::JsFile do
  it 'decompresses what it compresses' do
    string = 'Demo String'
    compressed = FirefoxJson::JsFile.compress(string)
    expect(FirefoxJson::JsFile.decompress(compressed)).to eq(string)
  end

  it 'deals correctly with UTF' do
    string = 'デモー！'
    compressed = FirefoxJson::JsFile.compress(string)
    expect(FirefoxJson::JsFile.decompress(compressed)).to eq(string)
  end
end
