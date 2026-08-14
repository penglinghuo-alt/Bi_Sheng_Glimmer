import datetime
from sqlalchemy import Column, String, Integer, DateTime, Text, JSON, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(String(64), primary_key=True)
    username = Column(String(64), unique=True, nullable=False, index=True)
    email = Column(String(128), unique=True, nullable=False)
    password_hash = Column(String(256), nullable=False)
    avatar = Column(String(512), nullable=True)
    bio = Column(String(256), nullable=True, default="毕昇微光用户")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    records = relationship("BrailleRecord", back_populates="user", cascade="all, delete-orphan")
    logs = relationship("DeviceLog", back_populates="user", cascade="all, delete-orphan")


class BrailleRecord(Base):
    __tablename__ = "braille_records"

    id = Column(String(64), primary_key=True)
    user_id = Column(String(64), ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String(256), nullable=False)
    source_type = Column(String(32), nullable=False)  # "现场扫描" | "本地文件"
    dot_matrix_width = Column(Integer, default=0)
    dot_matrix_height = Column(Integer, default=0)
    dot_matrix_data = Column(JSON, default=[])
    text_content = Column(Text, nullable=True)
    page_count = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    user = relationship("User", back_populates="records")


class DeviceLog(Base):
    __tablename__ = "device_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(64), ForeignKey("users.id"), nullable=False, index=True)
    device_id = Column(String(64), nullable=True)
    log_content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="logs")


class ShowcasePost(Base):
    __tablename__ = "showcase_posts"
    __table_args__ = (UniqueConstraint("record_id", "user_id", name="uq_showcase_record_user"),)

    id = Column(String(64), primary_key=True)
    user_id = Column(String(64), ForeignKey("users.id"), nullable=False, index=True)
    record_id = Column(String(64), ForeignKey("braille_records.id"), nullable=False, index=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", backref="showcase_posts")
    record = relationship("BrailleRecord", backref="showcase_posts")

    likes = relationship("PostLike", back_populates="post", cascade="all, delete-orphan")
    favorites = relationship("PostFavorite", back_populates="post", cascade="all, delete-orphan")
    comments = relationship("PostComment", back_populates="post", cascade="all, delete-orphan")


class PostLike(Base):
    __tablename__ = "showcase_post_likes"
    __table_args__ = (UniqueConstraint("post_id", "user_id", name="uq_postlike_post_user"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    post_id = Column(String(64), ForeignKey("showcase_posts.id"), nullable=False, index=True)
    user_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    post = relationship("ShowcasePost", back_populates="likes")


class PostFavorite(Base):
    __tablename__ = "showcase_post_favorites"
    __table_args__ = (UniqueConstraint("post_id", "user_id", name="uq_postfav_post_user"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    post_id = Column(String(64), ForeignKey("showcase_posts.id"), nullable=False, index=True)
    user_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    post = relationship("ShowcasePost", back_populates="favorites")


class PostComment(Base):
    __tablename__ = "showcase_post_comments"

    id = Column(Integer, primary_key=True, autoincrement=True)
    post_id = Column(String(64), ForeignKey("showcase_posts.id"), nullable=False, index=True)
    user_id = Column(String(64), ForeignKey("users.id"), nullable=False)
    content = Column(String(500), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    post = relationship("ShowcasePost", back_populates="comments")
    user = relationship("User", backref="showcase_comments")
