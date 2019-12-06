require 'spec_helper'

describe Paperclip::HasAttachedFile do
  let(:a_class) { spy("Class") }

  context '#define_on' do
    it 'defines a setter on the class object' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received(:define_method).with('avatar=')
    end

    it 'defines a getter on the class object' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received(:define_method).with('avatar')
    end

    it 'defines a query on the class object' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received(:define_method).with('avatar?')
    end

    it 'defines a method on the class to get all of its attachments' do
      allow(a_class).to receive(:extend)
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received(:extend).with(Paperclip::HasAttachedFile::ClassMethods)
    end

    it 'flushes errors as part of validations' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received(:validates_each).with('avatar')
    end

    it 'registers the attachment with Paperclip::AttachmentRegistry' do
      allow(Paperclip::AttachmentRegistry).to receive(:register)
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', size: 1)
      expect(Paperclip::AttachmentRegistry).to have_received(:register).with(a_class, 'avatar', size: 1)
    end

    it 'defines an after_save callback' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received('after_save')
    end

    it 'defines a before_destroy callback' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received('before_destroy')
    end

    it 'defines an after_commit callback' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
      expect(a_class).to have_received('after_commit')
    end

    context 'when the class does not allow after_commit callbacks' do
      it 'defines an after_destroy callback' do
        a_class = double('class', after_destroy: nil, validates_each: nil, define_method: nil, after_save: nil, before_destroy: nil, define_paperclip_callbacks: nil, validates_media_type_spoof_detection: nil)
        Paperclip::HasAttachedFile.define_on(a_class, 'avatar', {})
        expect(a_class).to have_received('after_destroy')
      end
    end

    it 'defines the Paperclip-specific callbacks' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', validate_media_type: false)
      expect(a_class).to_not have_received(:validates_media_type_spoof_detection)
      expect(a_class).to have_received('define_paperclip_callbacks')

    end

    it 'does not define a media_type check if told not to' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', validate_media_type: false)
      expect(a_class).to_not have_received(:validates_media_type_spoof_detection)
    end

    it 'does define a media_type check if told to' do
      Paperclip::HasAttachedFile.define_on(a_class, 'avatar', validate_media_type: true)
      expect(a_class).to have_received(:validates_media_type_spoof_detection)
    end
  end
end
