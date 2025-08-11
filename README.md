
# 📸 Instagram Clone Database (MySQL)

A **pure SQL** implementation of Instagram-like features, built entirely with **MySQL** — no backend frameworks, no ORMs.  
This project demonstrates how to design, implement, and query a relational database for a social media platform **using only SQL**.

---

## 🚀 Features

- **User Accounts** (signup, profile data)
- **Posts & Media** (images, captions, timestamps)
- **Followers System** (follow/unfollow)
- **Likes & Comments**
- **Stories**
- **Hashtags & Search**
- **Notifications via Triggers**
- **Views** for feed summaries
- **Stored Procedures** for core actions:
  - Create users, posts, comments
  - Like posts
  - Get user feed
  - Explore popular posts

---

## 🗂️ Database Schema Overview

Below is the **ER Diagram** for the project:

```

\[ USERS ]───< \[ POSTS ] >───\[ MEDIA ]
│            │ │
│            │ └──< \[ COMMENTS ]
│            └──< \[ LIKES ]
│
└──< \[ FOLLOWERS ]

\[ HASHTAGS ]───< \[ POST\_HASHTAGS ]
\[ STORIES ]
\[ NOTIFICATIONS ]

````

---

## 📊 ER Diagram (Visual)

<img width="1008" height="816" alt="er_dig_insta_clone" src="https://github.com/user-attachments/assets/94cad824-3c35-4740-9818-a9daf53de6ca" />


---

## 🛠️ Setup Instructions

### 1️⃣ Install MySQL
Make sure you have **MySQL 8+** installed.  
[Download MySQL](https://dev.mysql.com/downloads/)

### 2️⃣ Run the SQL Script
```bash
mysql -u root -p < instagram_clone_mysql.sql
````

### 3️⃣ Select the Database

```sql
USE instagram_clone;
```

### 4️⃣ Try the Stored Procedures

```sql
CALL get_user_feed(1, 10, 0);
CALL like_post(1, 3);
CALL create_comment(2, 3, 'Nice shot!');
```

---

## 📁 Project Structure

```
📦 Instagram Clone Database
 ┣ 📜 instagram_clone_mysql.sql   # Main SQL script
 ┣ 📜 README.md                   # Documentation
 ┗ 🖼️ er_diagram.png               # ER diagram image
```

---

## 🧠 How It Works

1. **Schema Design**

   * All tables are normalized and indexed for scalability.
   * Many-to-many relationships (hashtags, likes) handled via join tables.

2. **Business Logic in SQL**

   * Core app logic is implemented via **stored procedures** and **triggers**.
   * No ORM or server-side scripting — just SQL.

3. **Performance Considerations**

   * Indexes on foreign keys & frequently searched columns.
   * Views for quick feed summaries.
   * Option to precompute feed (fan-out-on-write) or compute on demand (fan-out-on-read).

---

## 📚 Example Queries

Get the **latest feed for a user**:

```sql
CALL get_user_feed(1, 10, 0);
```

Find **popular posts**:

```sql
CALL explore_popular_posts(10);
```

---

## 💡 Future Improvements

* Private accounts & follow requests
* Pagination cursors (instead of OFFSET)
* Advanced search with FULLTEXT indexes
* Archiving old data for performance

---
## 📌 Author

**Shreya Tripathy**
[GitHub Profile](https://github.com/Shreya7tripathy)

