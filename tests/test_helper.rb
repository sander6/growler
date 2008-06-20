module TestHelper
  
  def assert_changes(value)
    original_value = value
    new_value = yield
    assert_not_equal original_value, new_value
  end
  
end