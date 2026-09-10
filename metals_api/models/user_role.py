from sqlalchemy import Column, ForeignKey, Integer, Table

from models.base import Base


user_roles = Table(
    "user_roles",
    Base.metadata,
    Column(
        "user_id",
        Integer,
        ForeignKey("users.user_id", name="fk_user_roles_user", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "role_id",
        Integer,
        ForeignKey("roles.role_id", name="fk_user_roles_role", ondelete="RESTRICT"),
        primary_key=True,
    ),
)
