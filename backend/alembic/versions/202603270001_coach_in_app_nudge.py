"""coach_in_app_nudge — 스냅샷 최초 저장 시 비동기 코치 메시지 큐

Revision ID: 202603270001
Revises: 202603260002
Create Date: 2026-03-27
"""

from alembic import op
import sqlalchemy as sa

revision = "202603270001"
down_revision = "202603260002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "coach_in_app_nudge",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("body", sa.String(), nullable=False),
        sa.Column("consumed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_coach_in_app_nudge_user_id", "coach_in_app_nudge", ["user_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_coach_in_app_nudge_user_id", table_name="coach_in_app_nudge")
    op.drop_table("coach_in_app_nudge")
