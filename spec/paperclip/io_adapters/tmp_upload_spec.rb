# encoding: utf-8
require 'spec_helper'

describe 'Temporary Upload Processing' do
  describe '_tmp_id accessor' do
    it 'defaults to nil' do
      expect(Dummy.new.avatar_tmp_id).to be_nil
    end

    it 'can be set and retrieved' do
      dummy = Dummy.new(avatar_tmp_id: 'xyz')
      expect(dummy.avatar_tmp_id).to eq 'xyz'
    end

    it 'is not persisted' do
      dummy = Dummy.new(avatar_tmp_id: 'xyz')
      dummy.save
      expect(Dummy.find(dummy.id).avatar_tmp_id).to be_nil
    end
  end
end
