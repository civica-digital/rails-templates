unless Rails.env.production?
  Bullet.enable = true
  Bullet.bullet_logger = true
  Bullet.raise = true # Raise errors if N+1 queries occurs
end
