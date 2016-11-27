# encoding: utf-8
require 'spec_helper'

describe 'Temporary Upload Processing' do
  let(:file) { file = File.new(fixture_file("50x50.png"), 'rb') }
  let(:dummy_root) { "#{Rails.root}/public/system/dummies" }

  before do
    rebuild_class styles: { small: "100x>", large: "500x>" }
  end

  describe '_tmp_id accessor' do
    it 'defaults to nil' do
      expect(Dummy.new.avatar_tmp_id).to be_nil
    end

    it 'can be set and retrieved' do
      dummy = Dummy.new(avatar_tmp_id: '3ac91f')
      expect(dummy.avatar_tmp_id).to eq '3ac91f'
    end

    it 'is not persisted' do
      dummy = Dummy.new(avatar_tmp_id: '3ac91f')
      dummy.save
      expect(Dummy.find(dummy.id).avatar_tmp_id).to be_nil
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
      let(:dummy) { Dummy.new(avatar: file) }
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
      let(:dummy) { Dummy.new(avatar: file) }
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
    let(:dummy) { Dummy.new(avatar_tmp_id: '3ac91f', avatar: file) }

    context 'filesystem' do
      before do
        dummy.avatar.save_tmp
      end

      it 'saves files in right place' do
        expect(dummy.avatar.tmp_path).to exist
        expect(dummy.avatar.tmp_path(:small)).to exist
      end
    end
  end
end
