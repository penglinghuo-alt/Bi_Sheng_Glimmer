import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from database import get_db
from models import User, BrailleRecord, ShowcasePost, PostLike, PostFavorite, PostComment
from schemas import (
    ShowcasePostCreate, CommentCreate, ShowcasePostResponse, ShowcasePostListResponse,
    ShowcaseCommentResponse, ShowcaseUserResponse, UnpublishedRecordResponse,
    ShowcaseAuthor,
)
from auth_utils import get_current_user

router = APIRouter(prefix="/api/showcase", tags=["首页"])


def _build_author(user: User) -> ShowcaseAuthor:
    return ShowcaseAuthor(
        id=user.id,
        username=user.username,
        avatar=user.avatar,
        bio=user.bio,
    )


def _build_post(post: ShowcasePost, db: Session, current_user_id: str) -> ShowcasePostResponse:
    like_count = (
        db.query(func.count(PostLike.id)).filter(PostLike.post_id == post.id).scalar() or 0
    )
    comment_count = (
        db.query(func.count(PostComment.id)).filter(PostComment.post_id == post.id).scalar() or 0
    )
    liked = (
        db.query(PostLike.id)
        .filter(PostLike.post_id == post.id, PostLike.user_id == current_user_id)
        .first() is not None
    )
    favorited = (
        db.query(PostFavorite.id)
        .filter(PostFavorite.post_id == post.id, PostFavorite.user_id == current_user_id)
        .first() is not None
    )
    return ShowcasePostResponse(
        id=post.id,
        title=post.record.title if post.record else "未命名记录",
        source_type=post.record.source_type if post.record else "未知",
        page_count=post.record.page_count if post.record else 1,
        text_content=post.record.text_content if post.record else None,
        description=post.description,
        created_at=post.created_at,
        author=_build_author(post.user),
        like_count=like_count,
        comment_count=comment_count,
        liked=liked,
        favorited=favorited,
    )


def _build_comment(comment: PostComment, current_user_id: str) -> ShowcaseCommentResponse:
    return ShowcaseCommentResponse(
        id=comment.id,
        post_id=comment.post_id,
        content=comment.content,
        created_at=comment.created_at,
        author=_build_author(comment.user),
        is_mine=comment.user_id == current_user_id,
    )


def _query_visible_posts(db: Session, user_id: str = None):
    q = db.query(ShowcasePost).join(BrailleRecord, ShowcasePost.record_id == BrailleRecord.id)
    if user_id is not None:
        q = q.filter(ShowcasePost.user_id == user_id)
    return q


# ─── 帖子 ─────────────────────────────────────────────

@router.get("/posts", response_model=ShowcasePostListResponse, summary="首页帖子列表")
def list_posts(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    base = _query_visible_posts(db)
    total = base.count()
    posts = (
        base.order_by(ShowcasePost.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return ShowcasePostListResponse(
        total=total,
        posts=[_build_post(p, db, current_user.id) for p in posts],
    )


@router.get("/posts/{post_id}", response_model=ShowcasePostResponse, summary="帖子详情")
def get_post(post_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    post = _query_visible_posts(db).filter(ShowcasePost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="帖子不存在")
    return _build_post(post, db, current_user.id)


@router.post("/posts", response_model=ShowcasePostResponse, status_code=status.HTTP_201_CREATED, summary="发布帖子")
def create_post(
    req: ShowcasePostCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.description is not None and len(req.description) > 500:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="描述不能超过 500 字")

    if req.record_id:
        record = (
            db.query(BrailleRecord)
            .filter(BrailleRecord.id == req.record_id, BrailleRecord.user_id == current_user.id)
            .first()
        )
        if not record:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="记录不存在")
        duplicated = (
            db.query(ShowcasePost.id)
            .filter(ShowcasePost.record_id == req.record_id, ShowcasePost.user_id == current_user.id)
            .first()
        )
        if duplicated:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="该记录已发布")
        record_id = record.id
    else:
        title = (req.title or "").strip() or "未命名记录"
        record = BrailleRecord(
            id=uuid.uuid4().hex[:16],
            user_id=current_user.id,
            title=title,
            source_type="本地文件",
            dot_matrix_width=0,
            dot_matrix_height=0,
            dot_matrix_data=[],
            text_content=req.text_content,
            page_count=req.page_count,
        )
        db.add(record)
        db.flush()
        record_id = record.id

    post = ShowcasePost(
        id=uuid.uuid4().hex[:16],
        user_id=current_user.id,
        record_id=record_id,
        description=req.description,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return _build_post(post, db, current_user.id)


@router.delete("/posts/{post_id}", summary="删除帖子")
def delete_post(post_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    post = db.query(ShowcasePost).filter(ShowcasePost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="帖子不存在")
    if post.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权操作")
    db.delete(post)
    db.commit()
    return {"success": True, "message": "帖子已删除"}


@router.get("/posts/me/unpublished", response_model=List[UnpublishedRecordResponse], summary="未发布的存储库记录")
def list_unpublished_records(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    published_ids = [
        row[0]
        for row in db.query(ShowcasePost.record_id).filter(ShowcasePost.user_id == current_user.id).all()
    ]
    q = db.query(BrailleRecord).filter(BrailleRecord.user_id == current_user.id)
    if published_ids:
        q = q.filter(BrailleRecord.id.notin_(published_ids))
    records = q.order_by(BrailleRecord.created_at.desc()).all()
    return [
        UnpublishedRecordResponse(
            id=r.id, title=r.title, source_type=r.source_type,
            page_count=r.page_count, text_content=r.text_content,
        ) for r in records
    ]


# ─── 点赞 ─────────────────────────────────────────────

@router.post("/posts/{post_id}/like", summary="点赞")
def like_post(post_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    post = db.query(ShowcasePost).filter(ShowcasePost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="帖子不存在")
    existing = (
        db.query(PostLike)
        .filter(PostLike.post_id == post_id, PostLike.user_id == current_user.id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="已点赞")
    db.add(PostLike(post_id=post_id, user_id=current_user.id))
    db.commit()
    return {"success": True, "liked": True}


@router.delete("/posts/{post_id}/like", summary="取消点赞")
def unlike_post(post_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    existing = (
        db.query(PostLike)
        .filter(PostLike.post_id == post_id, PostLike.user_id == current_user.id)
        .first()
    )
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="未点赞")
    db.delete(existing)
    db.commit()
    return {"success": True, "liked": False}


# ─── 收藏 ─────────────────────────────────────────────

@router.post("/posts/{post_id}/favorite", summary="收藏")
def favorite_post(post_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    post = db.query(ShowcasePost).filter(ShowcasePost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="帖子不存在")
    existing = (
        db.query(PostFavorite)
        .filter(PostFavorite.post_id == post_id, PostFavorite.user_id == current_user.id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="已收藏")
    db.add(PostFavorite(post_id=post_id, user_id=current_user.id))
    db.commit()
    return {"success": True, "favorited": True}


@router.delete("/posts/{post_id}/favorite", summary="取消收藏")
def unfavorite_post(post_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    existing = (
        db.query(PostFavorite)
        .filter(PostFavorite.post_id == post_id, PostFavorite.user_id == current_user.id)
        .first()
    )
    if not existing:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="未收藏")
    db.delete(existing)
    db.commit()
    return {"success": True, "favorited": False}


@router.get("/favorites", response_model=ShowcasePostListResponse, summary="我的收藏列表")
def list_favorites(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    base = (
        db.query(ShowcasePost)
        .join(BrailleRecord, ShowcasePost.record_id == BrailleRecord.id)
        .join(PostFavorite, PostFavorite.post_id == ShowcasePost.id)
        .filter(PostFavorite.user_id == current_user.id)
    )
    total = base.count()
    posts = (
        base.order_by(PostFavorite.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return ShowcasePostListResponse(
        total=total,
        posts=[_build_post(p, db, current_user.id) for p in posts],
    )


# ─── 评论 ─────────────────────────────────────────────

@router.get("/posts/{post_id}/comments", response_model=List[ShowcaseCommentResponse], summary="评论列表")
def list_comments(
    post_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    post = db.query(ShowcasePost).filter(ShowcasePost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="帖子不存在")
    comments = (
        db.query(PostComment)
        .filter(PostComment.post_id == post_id)
        .order_by(PostComment.created_at.asc())
        .all()
    )
    return [_build_comment(c, current_user.id) for c in comments]


@router.post("/posts/{post_id}/comments", response_model=ShowcaseCommentResponse, status_code=status.HTTP_201_CREATED, summary="发表评论")
def create_comment(
    post_id: str,
    req: CommentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    content = req.content.strip()
    if not content:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="评论不能为空")
    if len(content) > 200:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="评论不能超过 200 字")
    post = db.query(ShowcasePost).filter(ShowcasePost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="帖子不存在")
    comment = PostComment(post_id=post_id, user_id=current_user.id, content=content)
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return _build_comment(comment, current_user.id)


@router.delete("/comments/{comment_id}", summary="删除评论")
def delete_comment(
    comment_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    comment = db.query(PostComment).filter(PostComment.id == comment_id).first()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="评论不存在")
    if comment.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权操作")
    db.delete(comment)
    db.commit()
    return {"success": True, "message": "评论已删除"}


# ─── 用户主页 ─────────────────────────────────────────

@router.get("/users/{user_id}", response_model=ShowcaseUserResponse, summary="用户详情")
def get_user(user_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="用户不存在")
    post_count = (
        db.query(func.count(ShowcasePost.id))
        .join(BrailleRecord, ShowcasePost.record_id == BrailleRecord.id)
        .filter(ShowcasePost.user_id == user.id)
        .scalar()
        or 0
    )
    return ShowcaseUserResponse(
        id=user.id,
        username=user.username,
        avatar=user.avatar,
        bio=user.bio,
        created_at=user.created_at,
        post_count=post_count,
    )


@router.get("/users/{user_id}/posts", response_model=ShowcasePostListResponse, summary="用户发布的帖子列表")
def list_user_posts(
    user_id: str,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="用户不存在")
    base = _query_visible_posts(db, user_id=user_id)
    total = base.count()
    posts = (
        base.order_by(ShowcasePost.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return ShowcasePostListResponse(
        total=total,
        posts=[_build_post(p, db, current_user.id) for p in posts],
    )
