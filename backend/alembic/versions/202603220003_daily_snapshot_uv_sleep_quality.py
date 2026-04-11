"""daily_lifestyle_snapshot에 UV, 수면의질 필드 추가

Revision ID: 202603220003
Revises: 202603220002
Create Date: 2026-03-22

"""
from alembic import op
import sqlalchemy as sa


revision = '202603220003'
down_revision = '202603220002'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("daily_lifestyle_snapshot", sa.Column("uv_outdoor_10to16", sa.String(20), nullable=True))
    op.add_column("daily_lifestyle_snapshot", sa.Column("sunscreen_applied", sa.Boolean(), nullable=True))
    op.add_column("daily_lifestyle_snapshot", sa.Column("sleep_quality_score", sa.Float(), nullable=True))


def downgrade() -> None:
    op.drop_column("daily_lifestyle_snapshot", "sleep_quality_score")
    op.drop_column("daily_lifestyle_snapshot", "sunscreen_applied")
    op.drop_column("daily_lifestyle_snapshot", "uv_outdoor_10to16")
