"""lifestyles에 주당 흡연일수(smoking_days_per_week) 추가

Revision ID: 202603260002
Revises: 202603260001
Create Date: 2026-03-26
"""

from alembic import op
import sqlalchemy as sa

revision = "202603260002"
down_revision = "202603260001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "lifestyles",
        sa.Column("smoking_days_per_week", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("lifestyles", "smoking_days_per_week")
