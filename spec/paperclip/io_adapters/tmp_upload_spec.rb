# encoding: utf-8
require 'spec_helper'

describe 'Temporary Upload Processing' do
  let(:file) { file = File.new(fixture_file("50x50.png"), 'rb') }
  let(:file2) { file = File.new(fixture_file("5k.png"), 'rb') }
  let(:dummy_root) { "#{Rails.root}/public/system/dummies" }

  before do
    rebuild_class styles: { small: "100x>", large: "500x>" }
    FileUtils.rm_rf("#{Rails.root}/tmp/attachments")
    FileUtils.rm_rf("#{Rails.root}/public/system")
  end

  describe 'tmp_id generation' do
    let(:dummy) { Dummy.new }

    it 'gets generated on new' do
      expect(dummy.avatar.tmp_id).to match /\A[0-9a-f]+\z/
    end

    it 'gets re-generated on find' do
      first = dummy.avatar.tmp_id
      dummy.save!
      dummy2 = Dummy.find(dummy.id)
      expect(dummy2.avatar.tmp_id).to match /\A[0-9a-f]+\z/
      expect(dummy2.avatar.tmp_id).not_to eq first
    end

    context 'with explicit nil' do
      let(:dummy) { Dummy.new(avatar_tmp_id: nil) }

      it 'doesnt replace nil' do
        expect(dummy.avatar.tmp_id).to be nil
      end
    end

    context 'with existing' do
      let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f') }

      it 'doesnt replace existing' do
        expect(dummy.avatar.tmp_id).to eq '3ac91f'
      end
    end
  end

  describe '_tmp_id accessor' do
    it 'can be set and retrieved' do
      dummy = Dummy.new(avatar_tmp_id: '3ac91f')
      expect(dummy.avatar_tmp_id).to eq '3ac91f'
    end

    it 'is not persisted' do
      dummy = Dummy.new(avatar_tmp_id: '3ac91f')
      dummy.save
      expect(Dummy.find(dummy.id).avatar_tmp_id).not_to eq '3ac91f'
    end
  end

  describe 'tmp_url' do
    shared_examples_for 'should be nil' do
      it 'should be nil' do
        expect(dummy.avatar.tmp_url).to be_nil
      end

      it 'should work with style_name' do
        expect(dummy.avatar.tmp_url(:small)).to be_nil
      end
    end

    context 'with attachment but no tmp_id' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: nil) }
      it_behaves_like 'should be nil'
    end

    context 'with tmp_id but no attachment' do
      let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f') }
      it_behaves_like 'should be nil'
    end

    context 'with attachment and tmp_id' do
      let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f', avatar: file) }

      context 'with default tmp_url format' do
        it 'should return correct url' do
          expect(dummy.avatar.tmp_url).to match %r{\A/system/tmp/3ac91f/original/50x50.png\?\d+\z}
        end

        it 'should work with style_name' do
          expect(dummy.avatar.tmp_url(:small)).to match %r{\A/system/tmp/3ac91f/small/50x50.png\?\d+\z}
        end
      end

      context 'with alternative tmp_url format' do
        before do
          rebuild_class tmp_url: '/system/tmp/:tmp_id/:style.:extension'
        end

        it 'should return correct url' do
          expect(dummy.avatar.tmp_url).to match %r{\A/system/tmp/3ac91f/original.png\?\d+\z}
        end

        it 'should work with style_name' do
          expect(dummy.avatar.tmp_url(:small)).to match %r{\A/system/tmp/3ac91f/small.png\?\d+\z}
        end
      end

      context 'with tmp_url in tmp_url format' do
        before do
          rebuild_class tmp_url: '/system/tmp/:tmp_url'
        end

        it 'should raise error' do
          expect { dummy.avatar.tmp_url }.to raise_error(Paperclip::Errors::InfiniteInterpolationError)
        end
      end
    end
  end

  describe 'tmp_path' do
    shared_examples_for 'should be nil' do
      it 'should be nil' do
        expect(dummy.avatar.tmp_path).to be_nil
      end

      it 'should work with style_name' do
        expect(dummy.avatar.tmp_path(:small)).to be_nil
      end
    end

    context 'with attachment but no tmp_id' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: nil) }
      it_behaves_like 'should be nil'
    end

    context 'with tmp_id but no attachment' do
      let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f') }
      it_behaves_like 'should be nil'
    end

    context 'with attachment and tmp_id' do
      let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f', avatar: file) }

      context 'with default tmp_path format' do
        it 'should return correct path' do
          expect(dummy.avatar.tmp_path).to match %r{/public/system/tmp/3ac91f/original/50x50.png\z}
        end

        it 'should work with style_name' do
          expect(dummy.avatar.tmp_path(:small)).to match %r{/public/system/tmp/3ac91f/small/50x50.png\z}
        end
      end

      context 'with alternative tmp_path format' do
        before do
          rebuild_class tmp_path: ':rails_root/public/system/tmp/:tmp_id/:style.:extension'
        end

        it 'should return correct path' do
          expect(dummy.avatar.tmp_path).to match %r{/public/system/tmp/3ac91f/original.png\z}
        end

        it 'should work with style_name' do
          expect(dummy.avatar.tmp_path(:small)).to match %r{/public/system/tmp/3ac91f/small.png\z}
        end
      end
    end
  end

  describe 'save_tmp' do
    before do
      dummy.avatar.save_tmp
    end

    shared_examples_for 'does nothing' do
      it 'does nothing' do
        expect("#{Rails.root}/tmp/attachments/3ac91f.yml").not_to exist
      end
    end

    context 'with no tmp_id' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: nil) }
      it_behaves_like 'does nothing'
    end

    context 'with no file' do
      let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f') }
      it_behaves_like 'does nothing'
    end

    context 'with tmp_id and file' do
      let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f', avatar: file) }

      it 'serializes the Attachment object to the right place' do
        expect("#{Rails.root}/tmp/attachments/3ac91f.yml").to exist
      end

      context 'with filesystem storage' do
        it 'saves files in right place' do
          expect(dummy.avatar.tmp_path).to exist
          expect(dummy.avatar.tmp_path(:small)).to exist
        end
      end
    end
  end

  describe 'url with allow_tmp' do
    shared_examples_for 'normal behavior' do
      it 'returns the main url' do
        expect(dummy.avatar.url(:original, allow_tmp: true)).to(
          match %r{\A/system/dummies/avatars//original/50x50.png\?\d+\z})
      end
    end

    context 'with no tmp_id' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: nil) }
      it_behaves_like 'normal behavior'
    end

    context 'with tmp_id but no matching serialized attachment' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: '3ac91f') }
      it_behaves_like 'normal behavior'
    end

    context 'with existing main file and matching serialized attachment' do
      let(:dummy) { Dummy.create(avatar: file) }

      before do
        # Call save_tmp on a separate model.
        dummy2 = Dummy.new(avatar_tmp_id: '3ac91f', avatar: file2).avatar.save_tmp
        dummy.avatar_tmp_id = '3ac91f'
      end

      it 'returns the tmp url' do
        expect(dummy.avatar.url(:original, allow_tmp: true)).to(
          match %r{\A/system/tmp/3ac91f/original/5k.png\?\d+\z})
      end
    end
  end

  describe 'path with allow_tmp' do
    shared_examples_for 'normal behavior' do
      it 'returns the main path' do
        expect(dummy.avatar.path(:original, allow_tmp: true)).to(
          match %r{/system/dummies/avatars//original/50x50.png\z})
      end
    end

    context 'with no tmp_id' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: nil) }
      it_behaves_like 'normal behavior'
    end

    context 'with tmp_id but no matching serialized attachment' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: '3ac91f') }
      it_behaves_like 'normal behavior'
    end

    context 'with existing main file and matching serialized attachment' do
      let(:dummy) { Dummy.create(avatar: file) }

      before do
        # Call save_tmp on a separate model.
        dummy2 = Dummy.new(avatar_tmp_id: '3ac91f', avatar: file2).avatar.save_tmp
        dummy.avatar_tmp_id = '3ac91f'
      end

      it 'returns the tmp path' do
        expect(dummy.avatar.path(:original, allow_tmp: true)).to(
          match %r{/system/tmp/3ac91f/original/5k.png\z})
      end
    end
  end

  describe 'saving tmp file as main on model save' do
    shared_examples_for 'normal behavior' do
      it 'saves normally' do
        dummy.save
        expect(dummy.avatar.path(:original)).to exist
      end
    end

    shared_examples_for 'copies tmp file' do
      before do
        # Call save_tmp on a separate model.
        dummy2 = Dummy.new(avatar_tmp_id: '3ac91f', avatar: file2).avatar.save_tmp
        dummy.avatar_tmp_id = '3ac91f'
        dummy.save
      end

      it 'saves tmp file as main' do
        expect(dummy.avatar.url).to match /5k\.png/
        expect(dummy.avatar.path).to exist
      end

      it 'removes tmp files and serialized model' do
        expect("#{Rails.root}/tmp/attachments/3ac91f.yml").not_to exist
        expect("#{Rails.root}/public/system/tmp/3ac91f").not_to exist
      end
    end

    context 'with no tmp_id' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: nil) }
      it_behaves_like 'normal behavior'
    end

    context 'with tmp_id but no matching serialized attachment' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: '3ac91f') }
      it_behaves_like 'normal behavior'
    end

    context 'with no file but matching serialized attachment' do
      let(:dummy) { Dummy.new }
      it_behaves_like 'copies tmp file'
    end

    context 'with existing file and matching serialized attachment' do
      let(:dummy) { Dummy.create(avatar: file, avatar_tmp_id: '3ac91f') }
      it_behaves_like 'copies tmp file'
    end

    context 'with freshly added regular file and matching serialized attachment' do
      let(:dummy) { Dummy.new(avatar: file, avatar_tmp_id: '3ac91f') }

      before do
        # Call save_tmp on a separate model.
        dummy2 = Dummy.new(avatar_tmp_id: '3ac91f', avatar: file2).avatar.save_tmp
        dummy.save
      end

      it 'prefers newly added regular file and leaves tmp file alone' do
        expect(dummy.avatar.url).to match /50x50\.png/
        expect("#{Rails.root}/tmp/attachments/3ac91f.yml").to exist
      end
    end
  end

  describe 'on destroy' do
    let(:dummy) { Dummy.create(avatar: file) }

    before do
      # Call save_tmp on a separate model.
      dummy2 = Dummy.new(avatar_tmp_id: '3ac91f', avatar: file2).avatar.save_tmp

      # Set tmp ID on dummy but then call destroy
      dummy.avatar_tmp_id = '3ac91f'
      dummy.avatar.destroy
    end

    it 'nullifies file' do
      expect(dummy.avatar.file?).to be false
    end

    it 'removes tmp files' do
      expect("#{Rails.root}/tmp/attachments/3ac91f.yml").not_to exist
      expect("#{Rails.root}/public/system/tmp/3ac91f").not_to exist
    end
  end
end
