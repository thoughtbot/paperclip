require 'fake_web'

FakeWeb.allow_net_connect = false

module FakeWeb
  class StubSocket
    def read_timeout=(ignored)
    end
  end
end
