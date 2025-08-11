-- Instagram Clone Database

/*Notes:
- This is a single-server SQL-first implementation intended for learning, prototyping, or as the backend data-layer for a frontend.
- For production: add caching (Redis), search engine (Elasticsearch) for heavy text-search, async workers for push-notifs, and sharding/replication for scale.
*/

-- ==================================================
-- 1) Create database
-- ==================================================
DROP DATABASE IF EXISTS instagram_clone;
CREATE DATABASE instagram_clone CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE instagram_clone;

-- ==================================================
-- 2) Core tables
-- ==================================================

-- users
CREATE TABLE users (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  display_name VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  bio VARCHAR(500) DEFAULT NULL,
  profile_pic_url VARCHAR(1000) DEFAULT NULL,
  is_private BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_username_username (username),
  FULLTEXT KEY ft_display_username (display_name, username)
) ENGINE=InnoDB;

-- posts
CREATE TABLE posts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  caption TEXT DEFAULT NULL,
  location VARCHAR(255) DEFAULT NULL,
  is_archived BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_posts_user_created (user_id, created_at),
  FULLTEXT KEY ft_caption (caption)
) ENGINE=InnoDB;

-- media (images/videos for posts)
CREATE TABLE media (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,
  media_url VARCHAR(2000) NOT NULL,
  media_type ENUM('image','video') DEFAULT 'image',
  position INT DEFAULT 1,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  INDEX idx_media_post_pos (post_id, position)
) ENGINE=InnoDB;

-- follows (follower -> followee)
CREATE TABLE follows (
  follower_id BIGINT NOT NULL,
  followee_id BIGINT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (follower_id, followee_id),
  FOREIGN KEY (follower_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (followee_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_followee (followee_id)
) ENGINE=InnoDB;

-- likes
CREATE TABLE likes (
  user_id BIGINT NOT NULL,
  post_id BIGINT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, post_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  INDEX idx_post_likes (post_id, created_at)
) ENGINE=InnoDB;

-- comments
CREATE TABLE comments (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  parent_comment_id BIGINT DEFAULT NULL,
  text VARCHAR(1000) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_comment_id) REFERENCES comments(id) ON DELETE CASCADE,
  INDEX idx_comments_post_created (post_id, created_at)
) ENGINE=InnoDB;

-- saved_posts
CREATE TABLE saved_posts (
  user_id BIGINT NOT NULL,
  post_id BIGINT NOT NULL,
  saved_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, post_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- stories
CREATE TABLE stories (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  media_url VARCHAR(2000) NOT NULL,
  media_type ENUM('image','video') DEFAULT 'image',
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- hashtags and post_hashtags
CREATE TABLE hashtags (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  tag VARCHAR(100) NOT NULL UNIQUE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE post_hashtags (
  post_id BIGINT NOT NULL,
  hashtag_id BIGINT NOT NULL,
  PRIMARY KEY (post_id, hashtag_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (hashtag_id) REFERENCES hashtags(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- notifications
CREATE TABLE notifications (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL, -- who receives
  actor_id BIGINT NOT NULL, -- who triggered
  type ENUM('follow','like','comment','mention','follow_request') NOT NULL,
  object_id BIGINT DEFAULT NULL, -- post_id, comment_id, or follow request id
  is_read BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_unread (user_id, is_read)
) ENGINE=InnoDB;

-- ==================================================
-- 3) Useful views
-- ==================================================

-- A compact post summary view for feed building
CREATE OR REPLACE VIEW post_summary AS
SELECT p.id AS post_id,
       p.user_id,
       u.username,
       u.display_name,
       p.caption,
       p.location,
       p.created_at,
       (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) AS like_count,
       (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) AS comment_count,
       (SELECT media_url FROM media m WHERE m.post_id = p.id ORDER BY position LIMIT 1) AS thumbnail_url
FROM posts p
JOIN users u ON u.id = p.user_id;

-- ==================================================
-- 4) Stored procedures / functions for common actions
-- ==================================================

DELIMITER $$

-- create_user
CREATE PROCEDURE create_user (
  IN p_username VARCHAR(50),
  IN p_display_name VARCHAR(100),
  IN p_email VARCHAR(255),
  IN p_password_hash VARCHAR(255)
)
BEGIN
  INSERT INTO users (username, display_name, email, password_hash)
  VALUES (p_username, p_display_name, p_email, p_password_hash);
  SELECT LAST_INSERT_ID() AS user_id;
END$$

-- follow_user (no checks for private follow requests for simplicity)
CREATE PROCEDURE follow_user (
  IN p_follower BIGINT,
  IN p_followee BIGINT
)
BEGIN
  INSERT IGNORE INTO follows (follower_id, followee_id)
  VALUES (p_follower, p_followee);
  -- create notification
  INSERT INTO notifications (user_id, actor_id, type, object_id)
  VALUES (p_followee, p_follower, 'follow', NULL);
END$$

-- unfollow_user
CREATE PROCEDURE unfollow_user (
  IN p_follower BIGINT,
  IN p_followee BIGINT
)
BEGIN
  DELETE FROM follows WHERE follower_id = p_follower AND followee_id = p_followee;
END$$

-- create_post (caption + media array handled via subsequent inserts; returns post id)
CREATE PROCEDURE create_post (
  IN p_user_id BIGINT,
  IN p_caption TEXT,
  IN p_location VARCHAR(255)
)
BEGIN
  INSERT INTO posts (user_id, caption, location) VALUES (p_user_id, p_caption, p_location);
  SELECT LAST_INSERT_ID() AS post_id;
END$$

-- add_media_to_post
CREATE PROCEDURE add_media_to_post (
  IN p_post_id BIGINT,
  IN p_media_url VARCHAR(2000),
  IN p_media_type ENUM('image','video'),
  IN p_position INT
)
BEGIN
  INSERT INTO media (post_id, media_url, media_type, position) VALUES (p_post_id, p_media_url, p_media_type, p_position);
END$$

-- like_post
CREATE PROCEDURE like_post (
  IN p_user_id BIGINT,
  IN p_post_id BIGINT
)
BEGIN
  INSERT IGNORE INTO likes (user_id, post_id) VALUES (p_user_id, p_post_id);
  -- notify post owner
  DECLARE post_owner_id BIGINT;
  SELECT user_id INTO post_owner_id FROM posts WHERE id = p_post_id;
  IF post_owner_id IS NOT NULL AND post_owner_id <> p_user_id THEN
    INSERT INTO notifications (user_id, actor_id, type, object_id) VALUES (post_owner_id, p_user_id, 'like', p_post_id);
  END IF;
END$$

-- unlike_post
CREATE PROCEDURE unlike_post (
  IN p_user_id BIGINT,
  IN p_post_id BIGINT
)
BEGIN
  DELETE FROM likes WHERE user_id = p_user_id AND post_id = p_post_id;
END$$

-- add_comment
CREATE PROCEDURE add_comment (
  IN p_user_id BIGINT,
  IN p_post_id BIGINT,
  IN p_text VARCHAR(1000),
  IN p_parent_comment_id BIGINT
)
BEGIN
  INSERT INTO comments (post_id, user_id, text, parent_comment_id) VALUES (p_post_id, p_user_id, p_text, p_parent_comment_id);
  DECLARE post_owner_id BIGINT;
  SELECT user_id INTO post_owner_id FROM posts WHERE id = p_post_id;
  IF post_owner_id IS NOT NULL AND post_owner_id <> p_user_id THEN
    INSERT INTO notifications (user_id, actor_id, type, object_id) VALUES (post_owner_id, p_user_id, 'comment', LAST_INSERT_ID());
  END IF;
END$$

-- get_user_feed (paginated): input viewer_id, page_size, offset
CREATE PROCEDURE get_user_feed (
  IN p_viewer_id BIGINT,
  IN p_limit INT,
  IN p_offset INT
)
BEGIN
  -- Return posts by people viewer follows OR their own posts.
  SELECT ps.post_id, ps.user_id, ps.username, ps.display_name, ps.caption, ps.location, ps.created_at,
         ps.like_count, ps.comment_count, ps.thumbnail_url,
         EXISTS(SELECT 1 FROM likes l WHERE l.post_id = ps.post_id AND l.user_id = p_viewer_id) AS viewer_liked
  FROM post_summary ps
  WHERE ps.user_id IN (SELECT followee_id FROM follows WHERE follower_id = p_viewer_id)
     OR ps.user_id = p_viewer_id
  ORDER BY ps.created_at DESC
  LIMIT p_offset, p_limit;
END$$

-- explore_popular_posts (popular by likes in last N days)
CREATE PROCEDURE explore_popular_posts (IN p_days INT, IN p_limit INT)
BEGIN
  SELECT ps.post_id, ps.user_id, ps.username, ps.display_name, ps.caption, ps.created_at, ps.like_count, ps.comment_count, ps.thumbnail_url
  FROM post_summary ps
  WHERE ps.created_at >= DATE_SUB(NOW(), INTERVAL p_days DAY)
  ORDER BY ps.like_count DESC, ps.comment_count DESC
  LIMIT p_limit;
END$$

DELIMITER ;

-- ==================================================
-- 5) Triggers (for notifications on comment/like/follow are handled in procedures above,
-- but include an example trigger that creates notifications if likes inserted directly)
-- ==================================================

DELIMITER $$
CREATE TRIGGER trg_like_insert AFTER INSERT ON likes
FOR EACH ROW
BEGIN
  DECLARE owner BIGINT;
  SELECT user_id INTO owner FROM posts WHERE id = NEW.post_id;
  IF owner IS NOT NULL AND owner <> NEW.user_id THEN
    INSERT INTO notifications (user_id, actor_id, type, object_id) VALUES (owner, NEW.user_id, 'like', NEW.post_id);
  END IF;
END$$

CREATE TRIGGER trg_comment_insert AFTER INSERT ON comments
FOR EACH ROW
BEGIN
  DECLARE owner BIGINT;
  SELECT user_id INTO owner FROM posts WHERE id = NEW.post_id;
  IF owner IS NOT NULL AND owner <> NEW.user_id THEN
    INSERT INTO notifications (user_id, actor_id, type, object_id) VALUES (owner, NEW.user_id, 'comment', NEW.id);
  END IF;
END$$

DELIMITER ;

-- ==================================================
-- 6) Sample data (small) and example calls
-- ==================================================

-- sample users
INSERT INTO users (username, display_name, email, password_hash, bio)
VALUES
('alice','Alice Wonder','alice@example.com','hash1','Photographer'),
('bob','Bob Rock','bob@example.com','hash2','Traveler'),
('carol','Carol Sun','carol@example.com','hash3','Foodie');

-- follow relations
INSERT INTO follows (follower_id, followee_id) VALUES (1,2),(1,3),(2,3);

-- posts
INSERT INTO posts (user_id, caption, location) VALUES
(2,'Sunset at the beach','#Goa'),
(3,'Best pasta ever!','#Rome'),
(1,'Early morning hike','#Hills');

-- media
INSERT INTO media (post_id, media_url, media_type, position) VALUES
(1,'https://cdn.example.com/1.jpg','image',1),
(2,'https://cdn.example.com/2.jpg','image',1),
(3,'https://cdn.example.com/3.jpg','image',1);

-- likes
INSERT INTO likes (user_id, post_id) VALUES (1,1),(3,1),(1,2);

-- comments
INSERT INTO comments (post_id, user_id, text) VALUES (1,1,'Amazing!'),(1,3,'Lovely shot'),(2,1,'Recipe please');

-- Give some hashtags
INSERT INTO hashtags (tag) VALUES ('sunset'),('food'),('hike');
INSERT INTO post_hashtags (post_id, hashtag_id) VALUES (1,1),(2,2),(3,3);


-- End of file
