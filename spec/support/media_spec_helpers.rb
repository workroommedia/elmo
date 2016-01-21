module MediaSpecHelpers
  module FileHandling
    def media_fixture(name)
      path = File.expand_path("../../fixtures/media/#{name}", __FILE__)
      File.open(path)
    end
  end

  shared_context 'media helpers' do
    def factory_name(described_class)
      described_class.name.underscore.gsub('/', '_').to_sym
    end

    def file_for_type(file_type)
      case file_type
      when 'audio'
        media_fixture('audio/powerup.mp3')
      when 'image'
        media_fixture('images/the_swing.jpg')
      when 'video'
        media_fixture('video/jupiter.mp4')
      end
    end
  end

  shared_examples 'accepts file extensions' do |extensions|
    include_context 'media helpers'

    extensions.each do |extension|
      context "with #{extension}" do
        let(:media_file) { build(factory_name(described_class), extension.to_sym) }

        it 'is valid' do
          expect(media_file).to be_valid
        end
      end
    end
  end

  shared_examples 'rejects file extensions' do |extensions|
    extensions.each do |extension|
      context "with #{extension}" do
        let(:media_file) { build(factory_name(described_class), extension.to_sym) }

        it 'is invalid' do
          expect(media_file).to have(1).error_on(:item_file_name)
        end
      end
    end
  end

  shared_examples 'rejects file types' do |file_types|
    file_types.each do |type|
      context "with #{type} file" do
        let(:media_file) { build(factory_name(described_class), item: file_for_type(type)) }

        it 'is invalid' do
          expect(media_file).to have(1).error_on(:item_content_type)
          expect(media_file).to have(1).error_on(:item_file_name)
          expect(media_file).to be_invalid
        end
      end
    end
  end
end
