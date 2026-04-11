"""daily_lifestyle_snapshot 테이블 추가 - 오늘의 나의 생활 일별 스냅샷

Revision ID: 202603220002
Revises: 202603220001
Create Date: 2026-03-22

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '202603220002'
down_revision = '202603220001'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "daily_lifestyle_snapshot",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("snapshot_date", sa.Date(), nullable=False, index=True),
        sa.Column("weight_kg", sa.Float(), nullable=True),
        sa.Column("height_cm", sa.Float(), nullable=True),
        sa.Column("drinking_days_per_week", sa.String(20), nullable=True),
        sa.Column("smoking_status", sa.String(50), nullable=True),
        sa.Column("stress_score", sa.Float(), nullable=True),
        sa.Column("sleep_minutes", sa.Integer(), nullable=True),
        sa.Column("aerobic_sessions_30min", sa.Integer(), nullable=True),
        sa.Column("resistance_sessions_30min", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), onupdate=sa.func.now()),
    )
    op.create_unique_constraint(
        "uq_daily_lifestyle_snapshot_user_date",
        "daily_lifestyle_snapshot",
        ["user_id", "snapshot_date"],
    )


def downgrade() -> None:
    op.drop_constraint("uq_daily_lifestyle_snapshot_user_date", "daily_lifestyle_snapshot", type_="unique")
    op.drop_table("daily_lifestyle_snapshot")
