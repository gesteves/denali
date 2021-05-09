require 'test_helper'

class BlurhashTest < ActiveSupport::TestCase

  test 'validates blurhashes' do
    blurhash = nil
    assert_not Blurhash.valid_blurhash?(blurhash)

    blurhash = ''
    assert_not Blurhash.valid_blurhash?(blurhash)

    blurhash = 'abcd1234'
    assert_not Blurhash.valid_blurhash?(blurhash)

    blurhash = 'eYNwA:O??^={.8=}kq%MnNNG.mR5IAkCRk%gn%aLS4j[xDt7RkNcjZ'
    assert Blurhash.valid_blurhash?(blurhash)
  end

  test 'generates data uris from blurhashes' do
    blurhash = 'abcd1234'
    assert_nil Blurhash.to_data_uri(blurhash: blurhash, w: 32, h: 32)

    blurhash = 'eYNwA:O??^={.8=}kq%MnNNG.mR5IAkCRk%gn%aLS4j[xDt7RkNcjZ'
    data_uri = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICQkKDA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/2wBDAQMDAwQDBAgEBAgQCwkLEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBD/wAARCAAgACADAREAAhEBAxEB/8QAGQAAAgMBAAAAAAAAAAAAAAAABgcDBQgJ/8QAJxAAAQMDBAEDBQAAAAAAAAAAAgEDBQAEEQYHEjEhE0FhFRZRUpH/xAAaAQADAQADAAAAAAAAAAAAAAADBAUGAAIH/8QAHREAAgICAwEAAAAAAAAAAAAAAQIAAwQRBRIhE//aAAwDAQACEQMRAD8A6e6kl2IiON90kTxRal2YK1teRRpuvFhfkyr4ZRcd04aT13BK3dtCEDG4sc+I4eDz81KuIUzQYmG7LvULoHU1neNYRxP7Rq1+i+RLOU0n2Be9shcMwrvpEqYBcV2rbqYqtX0Opha7np77jd4OHxQ19/mmrs5VTUvcfw6sQzS+PcCajFbEycx4rMZGUXfyeh4HG0/PUe+1OtbyRtgIjLyidrVPEu0Ji+ewV7kCNDe5Q+kO5/VacCbmMqyAh3MlwsIzITbi+miryX2pe/GLS7jcwFGhCab24buGxNGfwvVTjiey/jc4yjwxh7WaXSPbEOOMU/TToSLyPK/Rtkw13fuyuY0wz2NO76+zEkkxNaBgkOUJwk7KuNcDGKK2B3G3IRDTdoORTqln0TKiuVEk02QW54RMUao+SZlOWM//2Q=="
    assert_equal data_uri, Blurhash.to_data_uri(blurhash: blurhash, w: 32, h: 32)
  end
end
