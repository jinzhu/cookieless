module DummyActions
  def index
    render text: "<a href='/'></a>"
  end

  def internal_redirect
    redirect_to action: 'index'
  end

  def external_redirect
    redirect_to 'http://www.external.com'
  end
end
